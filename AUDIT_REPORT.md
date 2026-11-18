# Laporan Audit dan Penyempurnaan UNeed Malang

Tanggal audit dan pengerjaan: 2 November 2026  
Basis: arsip `UNeed-Project (2).zip` yang diberikan pada percakapan ini.

## 1. Ringkasan eksekutif

Struktur utama proyek dipertahankan. Aplikasi pengguna dan panel developer tetap menggunakan Flask terpisah, komponen bersama tetap berada di `shared/`, SQLite tetap menjadi penyimpanan aplikasi, dan enam CSV sumber tetap berada di `website_user/uploads_excel/`.

Pekerjaan berfokus pada konsistensi DSS, koneksi SQLite bersama, validasi data, pembatasan login developer, cache pembacaan CSV, kesesuaian rute pencarian, dan akurasi test serta dokumentasi. Tidak dilakukan migrasi framework, penambahan payment gateway, penggantian dataset, atau reset database.

**Hasil pengujian akhir:** 73 test lulus, 0 gagal. Kompilasi Python, parsing 39 template Jinja, dan pemeriksaan sintaks JavaScript juga lulus. HTTP smoke test untuk halaman pengguna dan developer berhasil melalui server lokal. Pengujian visual interaktif pada beberapa viewport belum dapat diselesaikan karena Chromium diblokir oleh kebijakan lingkungan (`net::ERR_BLOCKED_BY_ADMINISTRATOR`).

## 2. Kondisi awal dan baseline

Proyek sudah mempunyai dua aplikasi Flask, enam file kategori, modul komunitas, membership, lokasi, serta tampilan pengguna dan developer. Namun, audit menemukan beberapa area penting:

1. `shared/dss.py` belum menjadi mesin perhitungan utama yang dipakai aplikasi. Perhitungan katalog masih berada di `app_user.py`, sehingga ada risiko logika dan hasil berbeda.
2. Bentuk konfigurasi DSS lama memuat enam kriteria, sedangkan katalog yang aktif menggunakan tiga kriteria: harga, jarak, dan rating. Konfigurasi lama tidak cocok untuk dipakai apa adanya. Satu file konfigurasi aktif kini berada di `instance/dss_config.json`; salinan duplikat lama `shared/dss_config.json` dihapus setelah dipastikan identik byte-for-byte dengan file konfigurasi root dan tidak direferensikan oleh kode aktif. Loader membaca struktur lama dengan aman sebagai default sampai developer menyimpan konfigurasi tiga kriteria yang baru.
3. Parser jumlah ulasan belum konsisten menangani angka desimal berskala seperti `1.2K` dan `1,2 ribu`.
4. Parser koordinat dan rating perlu memisahkan format desimal dari pemisah ribuan agar angka seperti `112.615` dan `4.8` tidak berubah skala.
5. Kolom fasilitas deskriptif tidak boleh dianggap sebagai skor kualitas hanya berdasarkan jumlah item fasilitas.
6. Alur persetujuan listing perlu menangani kategori pusat perbelanjaan (`mal`) dengan pemetaan kolom yang tepat.
7. Koneksi database di kedua aplikasi memerlukan kebijakan pembukaan, foreign key, busy timeout, transaksi, dan penutupan yang seragam.
8. Pembatasan login developer yang hanya berada pada sesi browser tidak cukup untuk bertahan terhadap penggantian sesi.
9. Template pencarian lama tidak tersambung ke route aktif dan masih mengacu pada endpoint/filter yang sudah tidak tersedia.
10. Beberapa test warisan menggunakan asumsi penyimpanan JSON atau mengharapkan listing dan koordinat sintetis yang tidak ada di CSV aktual.

Baseline awal suite warisan: **36 lulus dan 38 gagal**. Kegagalan terutama berasal dari antarmuka modul DSS yang belum lengkap dan test yang mengasumsikan model penyimpanan/data lama. Test diperbarui agar menguji perilaku SQLite dan isi dataset yang benar-benar tersedia. Tidak ada data fiktif yang ditambahkan untuk membuat test lulus.

## 3. Prioritas risiko dan perubahan

| Prioritas | Area | Temuan | Penanganan |
|---|---|---|---|
| Kritis | Konsistensi DSS | Formula aplikasi belum menggunakan satu mesin bersama | Perhitungan dipusatkan ke `shared/dss.py` dan dipakai katalog user serta panel developer |
| Tinggi | Keamanan developer | Pembatasan percobaan login hanya berbasis sesi | Counter dipindahkan ke SQLite dengan kunci HMAC dari alamat klien, bukan menyimpan IP mentah |
| Tinggi | Database | Kebijakan koneksi berbeda dan koneksi berumur panjang berisiko | Helper SQLite bersama dengan FK, busy timeout, dan koneksi tertutup setelah blok transaksi |
| Tinggi | Integritas data | Parser review, rating, koordinat, dan fasilitas berisiko salah tafsir | Validasi format dan status missing diperketat tanpa mengisi nilai sumber |
| Sedang | Kinerja | CSV dibaca ulang pada request kategori | Cache DataFrame berdasarkan path, mtime, dan ukuran dengan salinan per pemanggil |
| Sedang | Fungsionalitas | Route pencarian lama/templat orphan tidak selaras | `/search` dipertahankan sebagai redirect kompatibilitas menuju pencarian dashboard; template orphan dihapus |
| Sedang | Kesesuaian tes | Tes memuat data contoh fiktif dan struktur simpan lama | Ekspektasi tes diselaraskan dengan SQLite serta enam CSV yang tersedia |
| Sedang | Dokumentasi | Laporan lama memuat angka, formula, dan jumlah kategori yang kedaluwarsa | Laporan audit ini ditetapkan sebagai dokumentasi status terkini; dokumen lama diberi penanda historis |

## 4. Perubahan implementasi

### 4.1 Backend dan database

- Menambahkan `shared/database.py` sebagai helper koneksi yang dipakai kedua aplikasi.
- Koneksi mengaktifkan `PRAGMA foreign_keys = ON`, `busy_timeout`, dan `sqlite3.Row`.
- Context manager koneksi melakukan commit/rollback sesuai perilaku SQLite dan menutup koneksi setelah blok selesai.
- Kedua aplikasi memakai database yang sama melalui `UNEED_DATABASE_PATH`.
- Inisialisasi tabel developer menggunakan `CREATE TABLE IF NOT EXISTS` sehingga tidak menghapus tabel lama.
- Menambahkan tabel `dev_login_attempts`. Kunci pembatasan berupa HMAC dari alamat klien, sehingga alamat IP mentah tidak dimasukkan ke tabel percobaan login.
- Konfigurasi DSS developer dan pengguna diarahkan ke loader/validator/writer yang sama.
- Penyimpanan konfigurasi DSS dilakukan secara atomik melalui file sementara dan `os.replace`.
- Pembacaan DataFrame kategori memakai cache metadata file. Pemanggil memperoleh `copy(deep=True)` agar mutasi filter/sort lokal tidak mengubah cache bersama.
- Kategori `mal` ditambahkan pada alur listing yang disetujui dan metrik developer.
- URL `/search` tetap tersedia sebagai jalur kompatibilitas dan mengalihkan query ke dashboard.

### 4.2 DSS: model matematis yang diterapkan

Kriteria aktif tetap tiga, sesuai katalog saat ini:

| Kriteria | Jenis | Normalisasi |
|---|---|---|
| Harga | Cost | nilai minimum dibagi nilai alternatif; nilai nol diperlakukan sebagai cost terbaik bila muncul |
| Jarak | Cost | nilai minimum dibagi jarak alternatif; jarak nol mendapat skor 1 |
| Rating | Benefit | rating Bayesian dibagi skala maksimum 5 |

Untuk alternatif dengan data hilang, kriteria yang tidak tersedia dikeluarkan lalu bobot kriteria yang tersedia dinormalisasi ulang. Skor total ditahan (`insufficient_data`) bila sumber hanya memiliki kurang dari dua kriteria valid. Pengecualian berlaku saat developer sengaja memberi bobot 100% pada satu kriteria, tetapi alternatif tetap harus memiliki setidaknya dua kriteria sumber yang valid. Sistem juga mengembalikan kriteria yang digunakan dan cakupan bobot agar hasil dapat dijelaskan.

Formula SAW cost menggunakan `min(x)/x`. Implementasi sebelumnya di aplikasi menggunakan bentuk rentang `(max(x)-x)/(max(x)-min(x))`. Keduanya mengarah pada preferensi yang sama untuk cost terendah pada data positif, tetapi transformasinya tidak identik dan dapat menghasilkan perubahan skor relatif/ranking ketika digabung dengan kriteria lain. Bentuk `min(x)/x` dipilih karena merupakan normalisasi cost SAW yang umum dan stabil terhadap rentang kandidat. Ini merupakan perubahan formula yang disengaja, bukan klaim bahwa hasil lama identik. Bobot tetap divalidasi berjumlah 100%.

Rating menggunakan skala tetap `rating/5`, agar makna skor 4,0 tetap sama ketika kategori atau kumpulan kandidat berubah. Rating sumber harus berada dalam rentang 0 sampai 5 dan nilai nol dianggap tidak valid oleh parser rating.

Bayesian Average Rating:

\[
R_{Bayes}=\frac{vR+mC}{v+m}
\]

`v` hanya berasal dari jumlah ulasan yang benar-benar tersedia. Jika jumlah ulasan tidak tersedia atau tidak valid, rating sumber dipakai tanpa membuat jumlah ulasan sintetis. Jumlah ulasan teramati nol adalah nilai valid dan menghasilkan prior `C`. Parser menangani suffix `K`, `rb`, dan `ribu` tanpa mengubah nilai desimal menjadi bilangan yang salah.

Jarak dihitung dengan Haversine sebagai jarak garis lurus. Perhitungan jarak dalam rekomendasi katalog hanya aktif ketika pengguna memberikan koordinat perangkat melalui izin Geolocation. Tanpa origin, jarak tidak diisi dengan titik pusat kota/kampus dan kriteria jarak tidak dianggap tersedia. Jarak tidak mewakili rute jalan atau waktu tempuh. Endpoint lokasi menggunakan POST ber-CSRF dan `no-store`; koordinat tidak disimpan pada profil, session, URL, atau access log.

### 4.3 Integritas data dan parser

- Keenam CSV tetap menjadi sumber data listing utama.
- Parser koordinat dan rating memakai pembacaan desimal yang tidak membuang titik desimal.
- Fasilitas berupa daftar teks tidak diubah menjadi rating. Nilai fasilitas hanya dibaca jika memang terdapat kolom skor eksplisit yang berada pada skala 1–5.
- Parser jumlah ulasan menjaga nilai hilang sebagai `None`; tidak ada jumlah review sintetis.
- Nilai harga, rating, koordinat, nomor telepon, dan URL eksternal divalidasi sebelum digunakan.
- Persetujuan listing masyarakat diproses terpisah dari CSV. Penyetujuan tidak menulis atau memodifikasi CSV sumber.

Jumlah baris data yang dibaca dari masing-masing file pada audit ini adalah 5 per kategori, total 30 baris. Ini hanya jumlah record pada snapshot CSV, bukan verifikasi bahwa listing masih aktif atau akurat di lapangan.

| Kategori | File | Baris terbaca |
|---|---|---:|
| Kos dan kontrakan | `kos.csv` | 5 |
| Tempat makan dan warung | `warung.csv` | 5 |
| Café dan working space | `cafe.csv` | 5 |
| Klinik dan layanan kesehatan | `klinik.csv` | 5 |
| ATK dan percetakan | `atk.csv` | 5 |
| Pusat perbelanjaan dan mall | `mal.csv` | 5 |
| **Total** | **6 CSV** | **30** |

### 4.4 Keamanan

- Hash kata sandi tetap ditangani Werkzeug, bukan plaintext.
- Endpoint sensitif di aplikasi user dan developer tetap berada di balik autentikasi/otorisasi sesuai route.
- Form perubahan data memeriksa CSRF token.
- Cookie sesi menggunakan HttpOnly dan SameSite Lax. Secure cookie aktif sesuai konfigurasi environment, terutama ketika production melalui HTTPS.
- Kunci sesi aplikasi pengguna dan developer dipisahkan melalui `UNEED_SECRET_KEY` dan `UNEED_DEV_SECRET_KEY`.
- Kunci developer berasal dari `UNEED_DEV_KEY`, tidak ditanam di JavaScript.
- Percobaan login developer dibatasi secara persisten di SQLite: ambang lima kegagalan dalam jendela 15 menit dan blokir lima menit. Identitas klien disimpan dalam bentuk HMAC, bukan IP mentah.
- Query database menggunakan parameter binding pada operasi yang diperiksa.
- Pesan error tidak dirancang untuk mengungkap detail rahasia konfigurasi.
- Isi `.env` tidak dibuka atau dimasukkan ke paket. Hanya `.env.example` disertakan.

Audit ini adalah pemeriksaan source code dan pengujian lokal, bukan penetration test independen. Sebelum deployment, tetap perlukan HTTPS, konfigurasi secret unik, SMTP yang sah, backup terjadwal, pemantauan, dan pembatasan akses jaringan untuk panel developer.

### 4.5 UI/UX dan fitur

Perubahan UI dijaga bertahap agar tidak mengganti identitas UNeed. Template orphan untuk pencarian lama dihapus karena tidak dipakai oleh route aktif dan mengandung referensi endpoint/filter yang tidak ada. Route `/search` tetap dipertahankan untuk kompatibilitas. Navigasi utama yang aktif tetap menggunakan dashboard, kategori, detail, profil, pengaturan, komunitas, membership, saved places, dan halaman operasional developer.

Smoke test HTTP autentikasi berhasil untuk halaman:

- Pengguna: dashboard, enam halaman kategori, detail kos, profil, pengaturan, komunitas, membership, saved places, submit listing, dan my submissions.
- Developer: dashboard, konfigurasi DSS, moderasi listing, aktivitas, komunitas, membership, dan reward.

Halaman `/dev/users` bukan route aktif. Manajemen pengguna membership berada pada `/dev/membership/users`.

## 5. Daftar file utama yang berubah

| File | Perubahan |
|---|---|
| `shared/database.py` | Helper koneksi SQLite bersama, FK, busy timeout, penutupan koneksi |
| `shared/dss.py` | Mesin tunggal SAW/Bayesian, validasi bobot, konfigurasi bersama, cache config, penjelasan skor |
| `shared/dss_config.json` | Dihapus karena merupakan salinan identik dan tidak direferensikan; konfigurasi tunggal berada di root `instance/` |
| `shared/catalog.py` | Parser jumlah ulasan dan cache katalog dengan invalidasi file |
| `shared/data_parser.py` | Parsing rating/koordinat desimal dan penolakan skor fasilitas sintetis |
| `shared/membership.py` | Teks manfaat default diselaraskan menjadi enam kategori |
| `website_user/app_user.py` | Integrasi DSS bersama, SQLite bersama, cache CSV, kategori mal, route kompatibilitas, security headers |
| `website_dev/app_dev.py` | Integrasi DSS/database bersama, lockout developer persisten, kategori mal, security headers |
| `tests/` | Pengujian aktual CSV, parser, DSS, SQLite, route, CSRF, otorisasi, dan lockout |
| `README.md` | Instruksi instalasi, konfigurasi, operasi, DSS, privasi, dan pengujian |
| `AUDIT_REPORT.md` | Laporan status hasil audit saat ini |
| Dokumen laporan lama | Diberi penanda historis agar tidak dianggap sebagai status implementasi terkini |
| `website_user/templates/search.html`, `website_user/templates/components/macros.html` | Dihapus karena orphan dan tidak digunakan route aktif |

Tidak ada file database atau CSV yang sengaja diubah oleh perubahan source code. Database di paket dikembalikan ke byte asli dari arsip sumber setelah pemeriksaan sementara menemukan perubahan akibat inisialisasi lokal. CSV dan database akhir diverifikasi dengan hash terhadap ZIP awal.

## 6. Hasil pengujian aktual

| Pemeriksaan | Hasil | Status |
|---|---:|---|
| `pytest` | 73 passed, 0 failed | Lulus |
| `compileall` Python (`website_user`, `website_dev`, `shared`, `tests`) | Tidak ada syntax error | Lulus |
| Parsing template Jinja | 39 template | Lulus |
| `node --check` seluruh berkas JavaScript | Tidak ada syntax error | Lulus |
| HTTP smoke test aplikasi pengguna | Route utama terautentikasi 200 | Lulus |
| HTTP smoke test developer | Halaman operasional utama 200 | Lulus |
| Hash enam CSV dibanding ZIP sumber | 6 dari 6 cocok | Lulus |
| Hash SQLite dibanding ZIP sumber | Cocok byte-for-byte | Lulus |
| File `.env` dalam paket | Tidak ada | Lulus |
| Browser viewport visual 360–390, 768, 1366, 1920 px | Chromium ditolak oleh kebijakan sandbox | Belum teruji |
| SMTP sungguhan | Tidak tersedia kredensial SMTP uji | Belum teruji |
| Penetration test eksternal | Tidak dijalankan | Belum teruji |

Test suite dijalankan menggunakan dependensi Python yang tersedia di lingkungan kerja dari arsip virtualenv sumber karena instalasi paket baru terhalang akses jaringan. Runtime bantuan tersebut tidak dimasukkan ke dalam paket final. Di komputer pengembang, buat virtualenv dan pasang dependensi dari `requirements.txt` sebelum menjalankan ulang test.

## 7. Kinerja

- Pembacaan CSV kategori memakai cache berdasarkan path, `mtime_ns`, dan ukuran file.
- Cache mengembalikan salinan DataFrame sehingga perubahan lokal pada hasil filter/sort tidak mencemari data cache.
- Cache DSS menggunakan signature konfigurasi dan invalidasi setelah penulisan atomik.
- Belum dilakukan benchmark beban serentak atau pengukuran p50/p95. Karena itu laporan ini tidak mengklaim persentase peningkatan waktu respons.

## 8. Kondisi yang belum diselesaikan dan risiko

1. Pemeriksaan visual dan interaksi browser pada empat ukuran layar belum dapat dikonfirmasi karena browser automation diblokir oleh kebijakan lingkungan. Test HTTP tidak membuktikan bahwa seluruh layout bebas overflow.
2. OTP dan reset password membutuhkan SMTP aktif. Jalur pengiriman email nyata belum diuji.
3. Dataset ringkas dan sejumlah kolom penting (misalnya harga, koordinat, atau jumlah ulasan pada kategori tertentu) mungkin kosong. Skor DSS akan ditahan atau bobot dinormalisasi ulang sesuai data yang tersedia. Pengelola perlu memperkaya data berdasarkan sumber terverifikasi.
4. Haversine merupakan jarak garis lurus. Untuk jarak rute dan waktu tempuh diperlukan layanan routing, yang tidak ditambahkan dalam audit ini.
5. Cache metadata mengandalkan waktu modifikasi dan ukuran file. Proses penggantian file dataset harus mempertahankan perubahan metadata file agar cache terinvalidasi.
6. Panel developer tetap sebaiknya hanya dapat diakses dari localhost atau jaringan administrasi yang dibatasi. Jangan mempublikasikannya langsung ke internet.
7. Tailwind CSS dan Alpine.js masih memakai CDN sesuai arsitektur saat ini. Untuk produksi, evaluasi build CSS lokal dan kebijakan CSP.
8. Tidak ada verifikasi deployment production, audit dependensi CVE, uji beban, atau penetration test independen.

## 9. Panduan menjalankan hasil revisi

Dari root `UNeed-Project`:

```bash
python -m venv .venv
```

Aktifkan virtualenv, kemudian:

```bash
python -m pip install -r requirements.txt
```

Salin `.env.example` menjadi `.env`. Ganti secret pengguna, secret developer, dan kunci developer dengan nilai acak yang berbeda. Jangan commit `.env`.

Jalankan di terminal pertama:

```bash
python website_user/app_user.py
```

Aplikasi pengguna menggunakan `http://127.0.0.1:5000/` secara default.

Jalankan di terminal kedua:

```bash
python website_dev/app_dev.py
```

Panel developer menggunakan `http://127.0.0.1:5001/dev/login` secara default.

Untuk menguji:

```bash
python -m pytest -q
```

Gunakan database salinan/terisolasi ketika melakukan pengujian migrasi dan jangan menghapus atau mereset database operasional.
