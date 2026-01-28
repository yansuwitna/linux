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

echo "=== Jalankan container ==="
docker run -d \
  --name mt5-docker \
  -p 3000:3000 \
  -p 8001:8001 \
  -e VNC_PASSWORD=mt5pass123 \
  -e NOVNC_PASSWORD=mt5web123 \
  -v ~/mt5-data:/config \
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

#Jika Error Lakukan Ini 
# docker stop mt5-docker
# docker rm mt5-docker

