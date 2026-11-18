# Konfigurasi gunicorn untuk produksi UNeed Malang.
# Jalankan: gunicorn -c gunicorn.conf.py website_user.app_user:app
import multiprocessing

bind = "0.0.0.0:5000"
workers = min(4, multiprocessing.cpu_count() * 2 + 1)
threads = 4
timeout = 60
keepalive = 5
accesslog = "-"
errorlog = "-"
loglevel = "info"
# Rate limiter in-memory bersifat per-proses; pada multi-worker, setiap
# proses memiliki bucket sendiri. Jika perlu batas global, gunakan Redis.
