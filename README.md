# UNeed Malang

Aplikasi katalog layanan lokal Malang untuk khalayak umum, dengan dua aplikasi Flask yang tetap terpisah: `website_user` untuk masyarakat/pengguna dan `website_dev` sebagai panel operasional website user.

Dokumentasi panel operasional developer: [`docs/OPERATIONS_PANEL_REPORT.md`](docs/OPERATIONS_PANEL_REPORT.md).

Status kesiapan rilis dan daftar pekerjaan tersisa: [`docs/RELEASE_READINESS_REVIEW.md`](docs/RELEASE_READINESS_REVIEW.md).

## Kebutuhan

- Python 3.10 atau lebih baru
- pip
- Akses SMTP yang valid jika ingin mengaktifkan pengiriman OTP pendaftaran dan tautan reset kata sandi

Dependensi utama adalah Flask, Flask-Mail, pandas, openpyxl, dan python-dotenv. Tailwind CSS sudah dikompilasi menjadi aset lokal. Alpine.js dan Font Awesome masih dimuat dari CDN, sehingga sebagian interaksi dan ikon memerlukan koneksi internet. Peta interaktif Leaflet/OSM bersifat opsional dan hanya dimuat ketika diaktifkan.

## Instalasi

Jalankan perintah dari folder akar proyek `UNeed-Project`.

```bash
python -m venv .venv
```

Aktifkan virtual environment:

- Windows PowerShell: `.venv\Scripts\Activate.ps1`
- macOS/Linux: `source .venv/bin/activate`

Pasang dependensi dan siapkan konfigurasi:

```bash
python -m pip install -r requirements.txt
```

Salin `.env.example` menjadi `.env`. Ganti `UNEED_SECRET_KEY`, `UNEED_DEV_SECRET_KEY`, dan `UNEED_DEV_KEY` dengan nilai acak yang tidak dipakai di tempat lain. Contoh pembangkit secret:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

Untuk mengaktifkan OTP dan reset kata sandi, isi `MAIL_USERNAME`, `MAIL_PASSWORD`, dan `MAIL_DEFAULT_SENDER`, serta pastikan konfigurasi server, port, TLS/SSL sesuai penyedia email. Pada Gmail, gunakan app password yang dibuat untuk akun pengirim, bukan kata sandi akun utama. Jangan commit file `.env`.

## Menjalankan aplikasi pengguna

Terminal pertama, di folder akar proyek:

```bash
python website_user/app_user.py
```

Buka `http://127.0.0.1:5000/`.

Akun baru dibuat melalui pendaftaran dan baru bisa digunakan setelah kode OTP email berhasil diverifikasi. Aplikasi tidak menyediakan akun atau kata sandi bawaan. Tanpa konfigurasi SMTP, pendaftaran baru akan menampilkan pesan bahwa OTP belum dapat dikirim. Login dan pengelolaan sesi tetap tersedia bagi akun yang sudah dibuat pada database lokal.

## Menjalankan konsol developer

Terminal kedua:

```bash
python website_dev/app_dev.py
```

Buka `http://127.0.0.1:5001/dev/login`. Kunci akses wajib disediakan lewat `UNEED_DEV_KEY`. Tidak ada kunci default yang ditanam di JavaScript atau repository. Aplikasi developer berjalan di `127.0.0.1` secara default dan sebaiknya tetap dibatasi ke mesin lokal kecuali tersedia autentikasi jaringan tambahan.

Konsol developer menggunakan identitas visual UNeed dan menjadi panel operasional website user. Dashboard menyediakan jumlah baris per kategori, status maintenance, jumlah akun, ringkasan page view 24 jam, serta antrean pengajuan masyarakat. Menu Aktivitas User menampilkan akun terdaftar dan riwayat page view; menu Pengajuan Data digunakan untuk menyetujui atau menolak data baru sebelum masuk katalog. Konfigurasi DSS tetap tersedia di menu terpisah. Jumlah baris merupakan hasil pembacaan file pada saat halaman dibuka, bukan jumlah entri yang pasti valid atau metrik kesehatan seluruh layanan. Di halaman konfigurasi, total bobot diperbarui secara langsung saat nilai diubah. Tombol `Pulihkan nilai awal` mengisi kembali nilai awal di form; tekan `Simpan konfigurasi` untuk benar-benar menyimpannya.

Pengaturan m, C, dan bobot SAW disimpan pada `instance/dss_config.json`. Kedua aplikasi membaca file konfigurasi yang sama. Mode maintenance disimpan pada `instance/site_config.json`; developer bisa mengaktifkan atau menonaktifkannya melalui Dashboard. Ketika aktif, website user menampilkan halaman pemeliharaan sementara, sedangkan website developer tetap dapat diakses. Total bobot harga, jarak, dan rating harus 100%.

## Data dan autentikasi

- Dataset berada di `website_user/uploads_excel/`. Nilai listing tidak ditambah atau direkayasa. Baris kosong pada `klinik.csv` dibuang dan encoding `mal.csv` diseragamkan ke UTF-8 BOM, tanpa mengubah isi listing.
- Akun, preferensi tampilan, OTP sementara, dan token reset disimpan dalam SQLite lokal pada `website_user/instance/uneed_users.sqlite3` secara default. Folder dan skema database dibuat otomatis saat aplikasi diimpor.
- Kata sandi disimpan sebagai hash Werkzeug. OTP kedaluwarsa setelah 10 menit dan dibatasi maksimal lima percobaan. Token reset kedaluwarsa setelah satu jam dan disimpan dalam bentuk hash.
- Endpoint penggantian file dataset secara langsung melalui HTTP tetap dinonaktifkan. Masyarakat dapat mengajukan informasi tempat/layanan lewat menu `Ajukan Tempat/Layanan`; pengajuan berstatus menunggu sampai developer menyetujuinya. Setelah disetujui, data dimasukkan ke katalog dan pemeringkatan DSS tanpa mengubah CSV sumber asli. Pengguna dapat memantau status lewat `Pengajuan Saya`.
- `UNEED_ENV=production` membutuhkan `UNEED_SECRET_KEY`, `UNEED_DEV_SECRET_KEY`, dan `UNEED_DEV_KEY` yang berbeda, bukan placeholder, serta masing-masing minimal 32 karakter. Aplikasi user dan developer memvalidasi ketiganya. Cookie Secure dan HSTS dipaksakan aktif pada mode production. Karena itu, production wajib berada di balik HTTPS.
- Sistem menyimpan page view GET dari website user di tabel `access_logs`. Catatan berisi identitas akun jika pengguna login, endpoint halaman, ID sesi acak, dan waktu. Tabel page view tidak menyimpan alamat IP, password, isi formulir, atau query string. Pembatasan percobaan login developer menyimpan HMAC alamat klien di tabel terpisah, bukan IP mentah. Beri tahu pengguna tentang pencatatan aktivitas sebelum aplikasi dipublikasikan.

## SEO dan akses publik

Aplikasi saat ini bersifat account-gated. Dashboard, kategori, detail, komunitas, dan halaman anggota memerlukan login. Endpoint `/robots.txt` karena itu mengarahkan crawler untuk tidak mengindeks aplikasi. Sitemap belum disediakan karena belum ada halaman katalog yang dapat diakses tanpa akun. Untuk publikasi terbuka, buat landing page publik terlebih dahulu, tentukan konten yang memang boleh diindeks, lalu tambahkan sitemap. Aturan crawler bukan pengganti autentikasi atau kontrol akses.

## Navigasi dan preferensi tampilan

- Enam kategori layanan (kos, warung, café, klinik, ATK, dan pusat perbelanjaan/mall) dibuka melalui menu hamburger pada bilah navigasi. Dashboard menampilkan satu daftar rekomendasi lintas kategori, bukan enam kelompok rekomendasi yang memanjang ke bawah.
- Setiap halaman kategori menyediakan pencarian teks, filter rentang harga, pengurutan, dan pilihan tampilan kartu/tabel. Pencarian dan filter berjalan melalui parameter GET di backend dan dapat digabungkan.
- Halaman profil serta pengaturan menggunakan navigasi bersama dan logo UNeed yang sama.
- Pilihan tema dan ukuran teks dapat dipratinjau langsung, kemudian disimpan ke preferensi akun. Setelah disimpan, preferensi diterapkan kembali pada sesi/login berikutnya.

## Catatan metode DSS

- Harga dan jarak diperlakukan sebagai kriteria cost. Rating diperlakukan sebagai kriteria benefit. Implementasi tunggal berada di `shared/dss.py` dan digunakan oleh website pengguna serta panel developer.
- Normalisasi SAW memakai rasio cost = nilai minimum / nilai alternatif. Rating benefit dibagi skala tetap 5 karena rating sumber berada pada rentang 1–5. Skala tetap membuat rating 4,0 bernilai 0,8 walaupun seluruh alternatif dalam satu dataset memiliki rating yang sama. Nilai pada kriteria konstan diberi skor 1. Nilai kosong/tidak valid dikeluarkan dari kriteria terkait. Bobot kriteria yang tersedia dinormalisasi ulang per alternatif. Skor keseluruhan tidak diterbitkan jika kurang dari dua kriteria sumber valid tersedia.
- Formula rating Bayesian memakai jumlah ulasan aktual jika jumlah tersebut tersedia dan valid: (v × R + m × C) / (v + m). Jika jumlah ulasan tidak tersedia atau tidak valid, rating sumber digunakan tanpa jumlah ulasan sintetis. Jumlah ulasan hanya diambil dari kolom sumber yang benar-benar tersedia. Parameter Bayesian tetap disimpan dan akan berpengaruh saat review count tersedia.
- Rumus cost ini berbeda dari normalisasi rentang min-max pada implementasi aplikasi sebelumnya. Pemilihan `min/x` mengikuti normalisasi cost SAW umum dan menjaga skor dalam rentang 0–1. Hasil numerik/ranking dapat berbeda karena transformasi tidak identik.
- Tanpa izin lokasi, sistem tidak menggunakan pusat kota atau kampus sebagai posisi pengguna. Ketika pengguna mengaktifkan GPS, jarak Haversine dan skor DSS dihitung ulang dari koordinat perangkat; angka ini merupakan jarak garis lurus, bukan jarak jalan atau estimasi waktu perjalanan.
- Skor DSS membantu menyusun urutan dan bukan klaim bahwa suatu tempat pasti terbaik.

**Kondisi data pada paket ini:** terdapat 30 listing bernama, masing-masing 5 per kategori. Setiap listing memiliki rating dan **koordinat terverifikasi** (diextract dari pin Google Maps resmi setiap listing, tanggal verifikasi 2026-11-18). Karena mesin DSS mensyaratkan minimal dua kriteria valid, **skor SAW multi-kriteria aktif ketika pengguna mengaktifkan Lokasi Saya** (kriteria jarak + rating = 30 dari 30 listing memperoleh skor). Harga dan jumlah ulasan belum diisi (tidak direkayasa) — kolom `Range Harga (Rp)`/`Harga per Bulan (Rp)` dan `Jumlah Ulasan` sudah tersedia di skema CSV dan siap diisi; setelah diisi, skor DSS juga muncul tanpa perlu lokasi aktif. Tanpa lokasi aktif dan tanpa harga, pengurutan memakai rating sumber sebagai fallback dan tidak diberi label sebagai hasil SAW. Setiap listing mencantumkan `Sumber Data` dan `Tanggal Verifikasi` untuk audit.

## Pengujian

Setelah dependensi terpasang:

```bash
python -m pytest -q
```

Audit historis pada 16 November 2026 melaporkan 73 test lulus. **Pada rilis ini (18 November 2026), full suite 109 test lulus 100%** setelah perbaikan isolasi test (autouse fixture membersihkan database & cache antar test, mencegah submission hasil persetujuan bocor ke test lain) dan penambahan 8 test validasi integritas dataset (skema CSV, koordinat dalam bounding box Malang, rating 0–5, kolom audit, dan 30/30 listing memperoleh skor DSS dengan lokasi aktif). SMTP nyata, browser lintas viewport, dan penetration test tetap belum diverifikasi dan sebaiknya dijalankan sebelum publikasi luas. Rincian dan status terkini ada di [`docs/RELEASE_READINESS_REVIEW.md`](docs/RELEASE_READINESS_REVIEW.md).

## Struktur utama

```text
UNeed-Project/
├── website_user/
│   ├── app_user.py
│   ├── templates/
│   ├── static/
│   ├── uploads_excel/
│   └── instance/                 # database SQLite yang dibuat saat runtime
├── website_dev/
│   ├── app_dev.py
│   ├── templates/
│   └── static/
├── shared/
│   ├── database.py              # helper koneksi SQLite bersama
│   ├── dss.py                   # mesin DSS tunggal
│   ├── catalog.py               # parser dan loader katalog
│   └── location.py              # Haversine dan koordinat
├── instance/dss_config.json     # konfigurasi DSS bersama
├── instance/site_config.json    # status maintenance (dibuat saat diubah developer)
├── tests/
├── requirements.txt
└── .env.example
```

## Fitur pencarian lokasi, komunitas, dan membership

### Lokasi dinamis dan Google Maps
- Kontrol **Gunakan Lokasi Saya** meminta izin eksplisit melalui Geolocation API browser. Posisi perangkat berada dalam memori halaman; saat perlu memperbarui DSS, koordinat dikirim melalui POST yang dilindungi CSRF ke endpoint `/api/location-dss` tanpa cache, lalu tidak disimpan dalam profil, session, URL, atau access log.
- Pilihan radius 1/3/5/10 km dan semua hasil menghitung jarak garis lurus dengan Haversine serta mengurutkan kartu berdasarkan jarak. Kartu tanpa koordinat valid tidak memperoleh jarak rekaan. Ketika berada di luar cakupan dataset, gunakan pencarian manual atau perluas radius; hasil tetap dibatasi oleh data yang tersedia.
- Tautan Google Maps/petunjuk arah tersedia jika nama atau alamat valid, dan tujuan memakai koordinat hanya jika koordinat tercatat serta lolos validasi. Tidak ada klaim jarak jalan/waktu tempuh pada UNeed.
- Peta interaktif memakai Leaflet + OpenStreetMap hanya jika `UNEED_ENABLE_INTERACTIVE_MAP=true`. Ini bersifat opsional; tanpa konfigurasi tersebut tombol lokasi dan pengurutan tetap berjalan tanpa peta.
- Geolocation di deployment harus memakai HTTPS (localhost dapat menjadi secure context untuk pengembangan). Jangan mengisi koordinat, foto, harga, ulasan, atau rating yang tidak ada di sumber.

### Rekomendasi komunitas dan moderator
- Pengguna terdaftar mengirim rekomendasi melalui `/community/new`. Rekomendasi masuk status `pending` dan baru tampil di feed publik setelah pengelola menyetujui di konsol terpisah (`/dev/community`).
- Anggota dapat menandai rekomendasi yang membantu (sekali per rekomendasi) dan melaporkan informasi keliru, duplikat, spam, atau informasi menyesatkan. Admin dapat meninjau dan menutup laporan. Kode kontributor dipakai pada leaderboard publik untuk menghindari publikasi nama lengkap anggota.
- Daftar tempat pribadi berada di `/saved-places`. Koleksi menyimpan nama/alamat saat disimpan dan menandai jika ID record tidak ditemukan lagi pada dataset terkini.
- Skema baru ditambahkan saat kedua aplikasi mulai. Migrasi menambah kolom membership pengguna tanpa mengganti framework atau menghapus tabel lama.

### Membership dan penghargaan
- `/membership` menampilkan Basic/Premium sesuai konfigurasi, riwayat poin, badge dan peringkat kontribusi. Konsol pengelola memiliki `/dev/membership` untuk mengatur label/manfaat/harga informasi (boleh kosong), poin dan ambang badge, serta `/dev/membership/users` untuk mengatur tier dan status secara manual.
- Harga/manfaat Premium tidak ditentukan secara otomatis dan gateway pembayaran belum aktif. Status membership tidak memengaruhi skor/rekomendasi organik; model pendapatan yang direncanakan hanya membership.
- Konfigurasi tersimpan pada `instance/membership_config.json` (atau path yang diatur lewat `UNEED_MEMBERSHIP_CONFIG`). Jangan mengisi harga/manfaat sebelum keputusan tim disepakati.

### Pengujian
Jalankan `python -m pytest -q` setelah dependensi pada `requirements.txt` terpasang. Test menggunakan database sementara melalui `tests/conftest.py`. Jangan mengarahkan `UNEED_DATABASE_PATH` ke database operasional saat menguji migrasi atau melakukan eksperimen. Status hasil uji terkini dan bagian yang belum terverifikasi dicatat pada [`docs/AUDIT_REPORT.md`](docs/AUDIT_REPORT.md).

## Deployment produksi

Jangan gunakan `python website_user/app_user.py` (server development Werkzeug) untuk publik. Pakai WSGI + reverse proxy HTTPS:

**Docker (disarankan):**
```bash
cp .env.example .env   # isi secret & SMTP
docker compose up -d   # uneed-user di port 5000; uneed-dev hanya di 127.0.0.1:5001
```
Health check tersedia di `GET /healthz` (tidak tercatat di access log, tetap aktif saat maintenance).

**Gunicorn langsung:**
```bash
gunicorn -c gunicorn.conf.py website_user.app_user:app
```

**Reverse proxy:** contoh konfigurasi Nginx dengan HTTPS ada di `deploy/nginx.conf.example`. Wajib HTTPS karena mode production memaksa cookie Secure dan HSTS. Konsol developer (`/dev/*`, port 5001) **tidak boleh** diekspos ke internet — batasi ke localhost/VPN/jaringan administrasi.

**CI:** `.github/workflows/ci.yml` menjalankan pytest + validasi integritas dataset pada setiap push/PR.

**Backup:** database SQLite ada di `website_user/instance/` (atau `UNEED_DATABASE_PATH`). Jadwalkan `sqlite3 .backup` secara berkala dan uji prosedur restore sebelum go-live.

## Lisensi
Dirilis di bawah lisensi MIT (lihat `LICENSE`). Dataset listing (nama, alamat, jam buka, rating, koordinat) bersumber dari Google Maps dan listing publik; verifikasi ulang sebelum publikasi luas.
