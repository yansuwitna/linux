#!/bin/bash
# ============================================================
#  Script Install Password Login untuk MetaTrader5 Web (noVNC)
#  Tested on Debian 12 / Ubuntu 22.04
#  Author: ChatGPT
# ============================================================

set -e

echo "=== [1/6] Update dan install paket yang dibutuhkan ==="
apt update -y
apt install -y nginx apache2-utils

echo "=== [2/6] Membuat user login untuk Basic Auth ==="
read -p "Masukkan username login web: " WEBUSER
read -s -p "Masukkan password login web: " WEBPASS
echo ""
mkdir -p /etc/nginx/auth
htpasswd -b -c /etc/nginx/auth/mt5_users "$WEBUSER" "$WEBPASS"

echo "=== [3/6] Membuat konfigurasi Nginx untuk MT5 Web ==="
cat >/etc/nginx/sites-available/mt5-web <<'EOF'
server {
    listen 80;
    server_name _;

    # Basic Authentication
    auth_basic "Restricted Area - MetaTrader5 Web";
    auth_basic_user_file /etc/nginx/auth/mt5_users;

    location / {
        proxy_pass http://127.0.0.1:6080/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

echo "=== [4/6] Mengaktifkan konfigurasi dan menonaktifkan default ==="
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/mt5-web /etc/nginx/sites-enabled/mt5-web

echo "=== [5/6] Mengecek konfigurasi Nginx ==="
nginx -t

echo "=== [6/6] Restart Nginx ==="
systemctl restart nginx
systemctl enable nginx

echo ""
echo "============================================================"
echo "✅ Instalasi selesai!"
echo "Sekarang akses MetaTrader5 Web di: http://<IP_SERVER>"
echo "Gunakan username & password yang sudah dibuat di langkah ini."
echo ""
echo "Jika container Docker noVNC MT5 berjalan di port berbeda,"
echo "edit file: /etc/nginx/sites-available/mt5-web"
echo "ganti bagian: proxy_pass http://127.0.0.1:6080/;"
echo "============================================================"
