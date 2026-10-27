//Kebutuhan Awal

dpkg --add-architecture i386
apt update && apt full-upgrade -y

apt install -y \
    sudo curl wget ca-certificates gnupg2 software-properties-common dbus-x11 xauth \
    lxde \
    tigervnc-standalone-server tigervnc-tools novnc websockify \
    haveged
    

systemctl enable --now haveged


//Membuat Akun 
adduser akun1

usermod -aG sudo akun1

//Membuat Index untuk vnc
ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

//Masuk User Akun 1
su - akun1

//Membuat Password VNC Akun 1
vncpasswd

//Uji Coba VNC Server Akun 1
vncserver :1 -fg -localhost yes -geometry 1366x768 -depth 24 &

//Menutup Uji Coba
vncserver -kill :1


//Uji Coba VNC Client Akun 1
websockify --web=/usr/share/novnc/ 6081 localhost:5901 &


//Konfigurasi VNC Server Akun 1
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

systemctl daemon-reload
systemctl enable --now vncserver-akun1.service
systemctl enable --now novnc-akun1.service

//Konfigurasi VNC Client Akun 1
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



//Install Wine di akun root
install -d -m 0755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources

apt update
apt install -y --install-recommends winehq-stable
wine --version

harus versi 11 atau terbaru

//Mengaktifkan Wine di akun1
//WINEPREFIX=/home/akun1/.wine wineboot -u
//WINEPREFIX=/home/akun1/.wine winecfg


//Download MT5
wget https://download.terminal.free/cdn/web/metaquotes.ltd/mt5/mt5setup.exe

//Install MT5
//WINEPREFIX=/home/akun1/.wine-11 wine ./mt5setup.exe
chmod +x mt5setup.exe
wine mt5setup.exe
