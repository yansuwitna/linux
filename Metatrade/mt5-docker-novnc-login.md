masuk user root 
buat file 

nano ./konfig.sh

#!/bin/bash
# ============================================
# Install MetaTrader 5 via Docker on Ubuntu
# (Dengan akses browser lewat VNC / noVNC)
# ============================================

set -e

echo "=== Update dan install dependensi ==="
apt update -y
apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

echo "=== Install Docker (jika belum) ==="
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
else
  echo "Docker sudah terpasang."
fi

echo "=== Pull image MT5 ready dengan VNC/noVNC ==="
# Contoh image dari github (gmag11/metatrader5_vnc) yang sudah siap pakai  
docker pull gmag11/metatrader5_vnc

echo "=== Menyiapkan konfigurasi NGINX container ==="
mkdir -p ~/mt5-nginx

cat > ~/mt5-nginx/default.conf <<'EOF'
server {
    listen 3000;

    location / {
        root /usr/share/novnc;
        index vnc.html;

        auth_basic "MT5 noVNC";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }

    location /websockify {
        proxy_pass http://127.0.0.1:5900;
        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
EOF

echo "=== Jalankan container ==="
docker rm -f mt5-docker >/dev/null 2>&1 || true

docker run -d \
  --name mt5-docker \
  -p 3000:3000 \
  -p 3001:3001 \
  -p 8001:8001 \
  -e VNC_PASSWORD=123456 \
  -e NOVNC_PASSWORD=123456 \
  -v ~/mt5-data:/config \
  -v ~/mt5-nginx/default:/etc/nginx/sites-enable/default \
  --restart unless-stopped \
  gmag11/metatrader5_vnc

echo "=== Menunggu container startup ==="
sleep 15

IP=$(hostname -I | awk '{print $1}')
echo ""
echo "✅ Selesai! Akses MT5 lewat browser:"
echo "👉 http://$IP:3000"
echo ""
echo "Volume data MT5: ~/mt5-data"
echo "Container name : mt5-docker"
echo "============================================"


Jalankan 

hmod +x konfig.sh
./konfig.sh

=======>>> 

Untuk Membut Password No VNC

docker exec -it mt5-docker bash
apt update & apt install -y apache2-utils
htpasswd -c /etc/nginx/.htpasswd admin

nano /etc/nginx/sites-enabled/default
Hilangkan Tanda # paling atas di 

nginx -s reload
exit

Uji Coba Di Client


