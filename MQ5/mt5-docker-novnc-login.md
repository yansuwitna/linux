masuk user root 
buat file 

nano ./konfig.sh

#!/bin/bash
# ============================================
# Install MetaTrader 5 via Docker on Ubuntu
# (Dengan akses browser lewat VNC / noVNC)
# ============================================

set -e

echo "1. Update dan Install"
apt update -y
apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release nginx apache2-utils

echo ""
echo "2. Install Docker"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
else
  echo "Docker sudah terpasang."
fi

echo ""
echo "3. Download Image Docker"
# Contoh image dari github (gmag11/metatrader5_vnc) yang sudah siap pakai  
docker pull gmag11/metatrader5_vnc

echo ""
echo "4. Menjalankan Docker"
docker rm -f mt5-docker >/dev/null 2>&1 || true

docker run -d \
  --name mt5-docker \
  -p 3000:3000 \
  -p 8001:8001 \
  -e VNC_PASSWORD=123456 \
  -e NOVNC_PASSWORD=123456 \
  -v ~/mt5-data:/config \
  -v ~/mt5-nginx/default:/etc/nginx/sites-enable/default \
  --restart unless-stopped \
  gmag11/metatrader5_vnc

echo ""
echo "5. Menunggu Proses Docker 15 Detik"
sleep 15

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
        proxy_pass http://127.0.0.1:3000/;
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
/sbin/nginx -t

echo "=== [6/6] Restart Nginx ==="
systemctl restart nginx
systemctl enable nginx

echo ""
echo "✅ Selesai! Akses MT5 lewat browser:"
echo "👉 http://$IP"
echo ""
echo "Volume data MT5: ~/mt5-data"
echo "Container name : mt5-docker"
echo "============================================"


Jalankan 

chmod +x konfig.sh
./konfig.sh

=======>>> 

Untuk Membut Password No VNC



Uji Coba Di Client




