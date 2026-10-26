====== Mesin Baru =============


  Tab Template
  Pilih storage template dan file debian-12-standard.
  
  Tab Disks
- Storage: pilih tempat penyimpanan LXC.
- Disk size: 16 GiB.
  
  Tab CPU
- Cores: 2.
  
  Tab Memory
- Memory: 2048 MiB.
- Swap: 512 MiB.
  
  Tab Network
- Name: eth0.
- Bridge: vmbr0.
- IPv4: DHCP jika router menyediakan DHCP, atau isi IP statis.
- IPv6: sesuai kebutuhan jaringan.
  
  Tab DNS
  Gunakan DNS bawaan host atau DNS yang berlaku di jaringan.
  
  Confirm
  Periksa konfigurasi, kemudian klik Finish. Setelah selesai, pilih CT 120 dan klik Start.


====== Instalasi Awal =============

apt update
apt upgrade -y

====== Install lxde =============

apt install -y lxde-core lxterminal dbus-x11 x11-xserver-utils

====== Instalasi TigerVNC Server =============
apt install -y tigervnc-standalone-server tigervnc-common dbus-x11 xfonts-base

adduser vncuser
mkdir -p /home/vncuser/.vnc
chown -R vncuser:vncuser /home/vncuser/.vnc

su - vncuser
vncpasswd
exit

nano /home/vncuser/.vnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startlxde

chown vncuser:vncuser /home/vncuser/.vnc/xstartup
chmod 755 /home/vncuser/.vnc/xstartup

====== Pengujian TigerVNC Server =============
su - vncuser
tigervncserver :1 -localhost no -geometry 1280x800 -depth 24
tigervncserver -list
exit

====== Membuat VNC otomatis berjalan saat LXC dinyalakan =============
nano /etc/systemd/system/vncserver.service
[Unit]
Description=TigerVNC Server LXDE
After=network.target

[Service]
Type=simple
User=vncuser
WorkingDirectory=/home/vncuser
Environment=HOME=/home/vncuser
ExecStartPre=-/usr/bin/tigervncserver -kill :1
ExecStart=/usr/bin/tigervncserver :1 -fg -localhost no -geometry 1280x800 -depth 24
ExecStop=/usr/bin/tigervncserver -kill :1
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target


====== Refresh =============
systemctl daemon-reload
systemctl enable vncserver
systemctl start vncserver
systemctl status vncserver --no-pager

systemctl is-enabled vncserver
ip -br addr
ss -lntp | grep 5901

====== Instal noVNC =============
apt install -y novnc websockify python3-websockify

====== Membuat noVNC berjalan otomatis =============
nano /etc/systemd/system/novnc.service
[Unit]
Description=noVNC Web Desktop
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ 6080 localhost:5901
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target

====== Menjalankan Dan Pengecekan =============
systemctl daemon-reload
systemctl enable --now novnc
systemctl status novnc --no-pager

ss -tulnp
reboot


=========== Play On Linux ============

dpkg --add-architecture i386
apt update
apt install -y playonlinux wine wine32:i386 wine64 winbind cabextract p7zip-full

su - vncuser
playonlinux




