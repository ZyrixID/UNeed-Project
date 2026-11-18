#!/usr/bin/env bash
# Kompilasi ulang Tailwind CSS setelah mengubah template/kelas.
# Unduh tailwindcss standalone CLI dari https://github.com/tailwindlabs/tailwindcss/releases
# lalu letakkan di PATH atau ganti ./tailwindcss di bawah.
set -euo pipefail
cd "$(dirname "$0")"
printf '@tailwind base;\n@tailwind components;\n@tailwind utilities;\n' > /tmp/tailwind_input.css
./tailwindcss -i /tmp/tailwind_input.css -o website_user/static/css/tailwind.css --minify
cp website_user/static/css/tailwind.css website_dev/static/css/tailwind.css
echo "Tailwind CSS berhasil dikompilasi."
