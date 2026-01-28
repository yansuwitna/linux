#Langkah 2


docker stop mt5-docker
docker rm mt5-docker



docker run -d \
  --name mt5-docker \
  -p 3000:3000 \
  -p 8001:8001 \
  -e VNC_PASSWORD=mt5pass123 \
  -e NOVNC_PASSWORD=mt5web123 \
  -v ~/mt5-data:/config \
  gmag11/metatrader5_vnc