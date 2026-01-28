apt update && apt upgrade -y

apt install -y xfce4 xfce4-goodies xfce4-terminal dbus-x11

apt install -y tigervnc-standalone-server tigervnc-common xterm

adduser vncuser
usermod -aG sudo vncuser
su - vncuser

vncpasswd

mkdir -p ~/.vnc
nano ~/.vnc/xstartup

#!/bin/sh
export XDG_SESSION_TYPE=x11
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session startxfce4

chmod +x ~/.vnc/xstartup

vncserver -localhost yes :1

vncserver -list

exit

apt install -y novnc websockify

http://IP_LXC:6080/vnc.html

Cek Di Server
websockify --web /usr/share/novnc/ 6080 localhost:5901

=== Buat Service noVNC (AUTO START)==

nano /etc/systemd/system/novnc.service

[Unit]
Description=noVNC WebSocket Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/websockify --web /usr/share/novnc/ 6080 localhost:5901
Restart=always
User=root

[Install]
WantedBy=multi-user.target

systemctl daemon-reload
systemctl enable novnc --now
systemctl status novnc

crontab -e

@reboot /usr/bin/vncserver -localhost yes :1
