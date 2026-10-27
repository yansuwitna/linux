//========================Kebutuhan Awal
Cek IP Terlebih Dahulu

dpkg --add-architecture i386
apt update && apt full-upgrade -y
apt install --no-install-recommends -y \
    sudo curl wget ca-certificates gnupg2 software-properties-common dbus-x11 xauth \
    lxde \
    tigervnc-standalone-server tigervnc-tools novnc websockify \
    haveged
ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html
systemctl enable --now haveged

//=======================Install Wine di akun root
install -d -m 0755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources

apt update
apt install -y --install-recommends winehq-stable
wine --version

//=======================Membuat Akun 
adduser akun1
adduser akun2
adduser akun3
usermod -aG sudo akun1
usermod -aG sudo akun2
usermod -aG sudo akun3

//=======================Masuk User Akun
su - akun1
vncpasswd
exit
su - akun2
vncpasswd
exit
su - akun3
vncpasswd
exit

//=======================Konfigurasi VNC Server Akun 1 di root
cat << 'EOF' > /etc/systemd/system/vncserver-akun1.service
[Unit]
Description=TigerVNC Server untuk akun1 (:1)
After=syslog.target network.target

[Service]
Type=simple
User=akun1
Group=akun1
WorkingDirectory=/home/akun1
ExecStartPre=-/usr/bin/vncserver -kill :1 > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :1 -fg -localhost yes -geometry 1366x768 -depth 24
ExecStop=/usr/bin/vncserver -kill :1
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/systemd/system/vncserver-akun2.service
[Unit]
Description=TigerVNC Server untuk akun1 (:2)
After=syslog.target network.target

[Service]
Type=simple
User=akun2
Group=akun2
WorkingDirectory=/home/akun2
ExecStartPre=-/usr/bin/vncserver -kill :2 > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :2 -fg -localhost yes -geometry 1366x768 -depth 24
ExecStop=/usr/bin/vncserver -kill :2
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/systemd/system/vncserver-akun3.service
[Unit]
Description=TigerVNC Server untuk akun1 (:3)
After=syslog.target network.target

[Service]
Type=simple
User=akun3
Group=akun3
WorkingDirectory=/home/akun3
ExecStartPre=-/usr/bin/vncserver -kill :3 > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :3 -fg -localhost yes -geometry 1366x768 -depth 24
ExecStop=/usr/bin/vncserver -kill :3
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vncserver-akun1.service
systemctl enable --now vncserver-akun2.service
systemctl enable --now vncserver-akun3.service

ss -tulnp

//=======================Konfigurasi VNC Client Akun 1 di root
cat << 'EOF' > /etc/systemd/system/novnc-akun1.service
[Unit]
Description=noVNC Service untuk akun1 (Port 6081)
After=vncserver-akun1.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ 6081 localhost:5901
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/systemd/system/novnc-akun2.service
[Unit]
Description=noVNC Service untuk akun2 (Port 6082)
After=vncserver-akun2.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ 6082 localhost:5902
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/systemd/system/novnc-akun3.service
[Unit]
Description=noVNC Service untuk akun3 (Port 6083)
After=vncserver-akun3.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ 6083 localhost:5903
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now novnc-akun1.service
systemctl enable --now novnc-akun2.service
systemctl enable --now novnc-akun3.service
ss -tulnp

//======================Matikan Pengacau IP Address
systemctl stop connman
systemctl disable connman
systemctl mask connman
ip addr flush dev eth0
systemctl restart networking
ip a

//=======================Download MT5 di Akun1, Akun2 dan Akun3
//Masuk Ke VNC Via Web 
wget https://download.terminal.free/cdn/web/metaquotes.ltd/mt5/mt5setup.exe

//=======================Install MT5
chmod +x mt5setup.exe
wine mt5setup.exe




/////=================== PENGUJIAN ======================

//=======================Uji Coba VNC Server Akun 1
vncserver :1 -fg -localhost yes -geometry 1366x768 -depth 24 &

//=======================Menutup Uji Coba
vncserver -kill :1

//=======================Uji Coba VNC Client Akun 1
websockify --web=/usr/share/novnc/ 6081 localhost:5901 &


