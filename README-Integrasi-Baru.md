# Catatan Integrasi UNeed Malang

Dokumen ini merupakan catatan integrasi versi sebelumnya. Detail implementasi DSS dan kategori di dalamnya sudah tidak dijadikan acuan operasional.

Untuk panduan yang sesuai dengan source code saat ini, gunakan:

- [`README.md`](README.md) untuk instalasi, konfigurasi, menjalankan aplikasi, dan fitur.
- [`AUDIT_REPORT.md`](AUDIT_REPORT.md) untuk temuan audit, keputusan formula DSS, perubahan source code, hasil test, dan keterbatasan.

Implementasi aktif menggunakan enam kategori dan tiga kriteria DSS: harga (cost), jarak (cost), serta rating (benefit). Mesin perhitungan tunggal berada pada `shared/dss.py`.
