# UNeed Malang — Panel Operasional Developer

## Tujuan revisi

Website developer diposisikan sebagai panel pengelolaan `website_user`. Konfigurasi DSS tetap tersedia, tetapi panel sekarang juga mengelola maintenance, memantau aktivitas halaman, dan meninjau pengajuan konten dari masyarakat.

## Fitur yang diimplementasikan

### 1. Mode maintenance

- Status maintenance disimpan di `instance/site_config.json`.
- Developer dapat mengaktifkan dan menonaktifkan maintenance lewat Dashboard.
- Developer dapat mengubah pesan yang ditampilkan kepada pengunjung.
- Saat aktif, semua halaman website user diarahkan ke halaman maintenance dengan HTTP 503. Berkas statis dan halaman maintenance tetap dapat dibuka.
- Website developer berjalan pada aplikasi Flask terpisah sehingga dapat dipakai untuk mematikan maintenance.

### 2. Monitoring akses website user

- Website user mencatat page view untuk request GET yang berhasil dirutekan.
- Catatan memuat ID sesi browser acak, identitas akun jika pengguna sudah login, nama endpoint halaman, dan waktu.
- Panel menampilkan jumlah akun terdaftar, pengunjung berbasis sesi dan page view dalam 24 jam, daftar akun beserta aktivitas terakhir, serta maksimal 200 page view terbaru.
- Tabel page view tidak menyimpan alamat IP, kata sandi, isi formulir, atau query string URL. Tabel terpisah untuk rate limit login developer menyimpan HMAC alamat klien, bukan IP mentah. Riwayat page view yang lebih lama dari 180 hari dibersihkan secara berkala.
- Angka pengunjung unik adalah perkiraan berbasis sesi browser, bukan jumlah orang yang teridentifikasi secara pasti dan bukan indikator siapa yang sedang online saat ini.

### 3. Pengajuan tempat atau layanan dari masyarakat

- Pengguna yang login dapat mengajukan data melalui menu hamburger `Ajukan Tempat/Layanan` untuk enam kategori: kos, tempat makan/warung, café, kesehatan, ATK/percetakan, atau pusat perbelanjaan/mall.
- Form berisi kategori, nama, alamat, perkiraan harga/biaya, link Google Maps, kontak, jam operasional, dan deskripsi.
- Pengajuan disimpan di SQLite dengan status `pending`; pengajuan belum tampil di katalog publik.
- Developer dapat menyetujui atau menolak pengajuan di menu `Pengajuan Data`, dan bisa menambahkan catatan peninjauan.
- Data yang disetujui digabungkan ke tampilan kategori dan aliran rekomendasi aplikasi pengguna. CSV sumber asli tidak diubah.
- Data komunitas dapat mempunyai kriteria DSS yang tidak lengkap, misalnya belum mempunyai rating atau koordinat. Sistem tidak membuat angka rating/jarak palsu; skor DSS tetap kosong sampai kriteria yang diperlukan tersedia.
- Pengguna dapat melihat status dan catatan peninjauan pada menu `Pengajuan Saya`.
- Ini merupakan alur pengajuan listing berbentuk form, bukan unggah CSV/Excel mentah. Hal ini mencegah pengguna langsung mengganti dataset sumber.

### 4. Proteksi dan privasi

- Route dashboard, maintenance, aktivitas, daftar pengajuan, dan keputusan review memerlukan autentikasi developer.
- Perubahan memakai token CSRF, dan percobaan login kunci developer dibatasi secara persisten di SQLite. Kunci klien berasal dari HMAC alamat klien, bukan penyimpanan IP mentah.
- Form pengajuan memvalidasi kategori, panjang kolom, dan URL Maps.
- Ketika akun dihapus, riwayat akses yang terhubung dengan akun dihapus. Pengajuan yang masih pending turut dihapus; listing yang sudah disetujui tetap tersedia tetapi identitas pengajunya dianonimkan.
- Footer website user memberikan informasi tentang pencatatan page view. Pemberitahuan privasi dan masa retensi perlu ditinjau kembali sebelum website dipublikasikan.

## Halaman baru dan endpoint utama

| Aplikasi | Endpoint | Fungsi |
|---|---|---|
| User | `/submit-listing` | Mengajukan tempat/layanan |
| User | `/my-submissions` | Melihat status pengajuan milik sendiri |
| User | `/maintenance` | Halaman pemeliharaan publik, HTTP 503 saat aktif |
| Developer | `/dev/dashboard` | Ringkasan operasional dan kontrol maintenance |
| Developer | `/dev/activity` | Akun terdaftar dan riwayat akses |
| Developer | `/dev/submissions` | Filter pengajuan pending, approved, rejected, atau semua |
| Developer | `/dev/submissions/<id>/review` | Menyetujui/menolak pengajuan melalui POST ber-CSRF |
| Developer | `/dev/dss-config` | Pengaturan Bayesian dan SAW yang sudah ada |

## Penyimpanan

- Akun, access log, pengajuan, dan status moderasi menggunakan SQLite yang sama untuk kedua aplikasi.
- Status maintenance berada di `instance/site_config.json`.
- Konfigurasi DSS tetap di `instance/dss_config.json`.
- Enam CSV asli tetap dipertahankan apa adanya.

## Validasi yang dijalankan

- Suite `pytest`: 73 passed, 0 failed.
- `compileall` Python: lulus.
- Parsing 39 template Jinja: lulus.
- `node --check` seluruh file JavaScript: lulus.
- HTTP smoke test halaman utama user dan developer: lulus.
- Enam CSV dan database SQLite dibandingkan terhadap ZIP sumber: hash cocok byte-for-byte.
- Chromium visual viewport belum dapat dijalankan karena browser diblokir kebijakan lingkungan (`net::ERR_BLOCKED_BY_ADMINISTRATOR`).
- Pengiriman email SMTP nyata belum diuji karena kredensial layanan tidak tersedia.

Rincian temuan, formula DSS, perubahan source code, hasil pengujian, dan risiko sisa terdapat pada [`AUDIT_REPORT.md`](AUDIT_REPORT.md). Untuk menjalankan suite pada komputer pengembang, instal dependensi di `requirements.txt` kemudian jalankan `python -m pytest -q`.
