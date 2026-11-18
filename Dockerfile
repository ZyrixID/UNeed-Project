# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install dependencies first (layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY . .

# Non-root user for runtime
RUN useradd --create-home --uid 1000 uneed && chown -R uneed:uneed /app
USER uneed

EXPOSE 5000

# Default: jalankan aplikasi pengguna via gunicorn (WSGI production).
# Untuk konsol developer, override command menjadi:
#   gunicorn -w 1 -b 0.0.0.0:5001 website_dev.app_dev:app
CMD ["gunicorn", "-w", "2", "--threads", "4", "-b", "0.0.0.0:5000", "--timeout", "60", "website_user.app_user:app"]
