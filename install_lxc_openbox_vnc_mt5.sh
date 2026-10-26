#!/usr/bin/env bash
# ==============================================================================
# Skrip Otomatisasi Pemasangan LXC Debian 12: Openbox + VNC/noVNC + Wine 11 + MT5
# ==============================================================================

set -e

# Pastikan dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\e[31m[ERROR] Skrip ini harus dijalankan sebagai root!\e[0m"
    exit 1
fi

echo -e "\e[32m====================================================\e[0m"
echo -e "\e[32m   Installer MT5 Debian 12 LXC (Openbox + Wine 11)  \e[0m"
echo -e "\e[32m====================================================\e[0m"
echo ""

# ------------------------------------------------------------------------------
# 1. Menangani Input Username & Password VNC Dinamis
# ------------------------------------------------------------------------------
if [ -n "$1" ] && [ -n "$2" ]; then
    VNC_USER="$1"
    VNC_PASS="$2"
else
    read -p "Masukkan Username VNC [default: vncuser]: " INPUT_USER
    VNC_USER=${INPUT_USER:-vncuser}

    while true; do
        read -s -p "Masukkan Password VNC (min 6 karakter): " VNC_PASS
        echo ""
        read -s -p "Konfirmasi Password VNC: " VNC_PASS_CONFIRM
        echo ""

        if [ "$VNC_PASS" != "$VNC_PASS_CONFIRM" ]; then
            echo -e "\e[31m[!] Password tidak cocok. Silakan coba lagi.\e[0m"
        elif [ ${#VNC_PASS} -lt 6 ]; then
            echo -e "\e[31m[!] Password terlalu pendek (minimal 6 karakter).\e[0m"
        else
            break
        fi
    done
fi

VNC_HOME="/home/$VNC_USER"

echo -e "\n\e[34m[1/8] Membuat pengguna sistem '$VNC_USER'...\e[0m"
if ! id "$VNC_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$VNC_USER"
fi
echo "$VNC_USER:$VNC_PASS" | chpasswd
usermod -aG sudo "$VNC_USER"

# ------------------------------------------------------------------------------
# 2. Pembaruan Paket & Pemasangan Dependensi Desktop Ringan (Openbox)
# ------------------------------------------------------------------------------
echo -e "\n\e[34m[2/8] Mengomandani pembaruan paket & memasang Openbox + VNC...\e[0m"
export DEBIAN_FRONTEND=noninteractive
dpkg --add-architecture i386
apt update && apt full-upgrade -y
apt install -y \
    sudo curl wget ca-certificates gnupg2 software-properties-common dbus-x11 xauth \
    openbox tint2 feh lxterminal thunar \
    tigervnc-standalone-server tigervnc-tools novnc websockify

# ------------------------------------------------------------------------------
# 3. Pemasangan Repositori WineHQ & Wine 11
# ------------------------------------------------------------------------------
echo -e "\n\e[34m[3/8] Memasang WineHQ Stable (Wine 11)..."
install -d -m 0755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources
apt update
apt install -y --install-recommends winehq-stable=11.0.0.0~bookworm-1 || apt install -y --install-recommends winehq-stable

# ------------------------------------------------------------------------------
# 4. Konfigurasi VNC & Password (PERBAIKAN PERMISSION DENIED)
# ------------------------------------------------------------------------------
echo -e "\n\e[34m[4/8] Mengonfigurasi VNC Password & Direktori Sesi...\e[0m"
# Buat struktur folder dengan kepemilikan user terlebih dahulu
mkdir -p "$VNC_HOME/.vnc"
chown -R "$VNC_USER:$VNC_USER" "$VNC_HOME/.vnc"
chmod 700 "$VNC_HOME/.vnc"

# Buat file password VNC dengan hak akses aman (0600)
su - "$VNC_USER" -c "vncpasswd -f <<< '$VNC_PASS' > '$VNC_HOME/.vnc/passwd'"
chmod 600 "$VNC_HOME/.vnc/passwd"

# Buat berkas xstartup untuk Openbox
cat << 'EOF' > "$VNC_HOME/.vnc/xstartup"
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec openbox-session
EOF
chmod +x "$VNC_HOME/.vnc/xstartup"
chown "$VNC_USER:$VNC_USER" "$VNC_HOME/.vnc/xstartup"

# ------------------------------------------------------------------------------
# 5. Konfigurasi noVNC Direct Access (:6080 langsung tanpa /vnc.html)
# ------------------------------------------------------------------------------
echo -e "\n\e[34m[5/8] Mengonfigurasi Direct Access noVNC (Port 6080)...\e[0m"
ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# ------------------------------------------------------------------------------
# 6. Konfigurasi Autostart Openbox & Installer MT5
# ------------------------------------------------------------------------------
echo -e "\n\e[34m[6/8] Menyiapkan Autostart Openbox & MetaTrader 5...\e[0m"
mkdir -p "$VNC_HOME/.config/openbox"
mkdir -p "$VNC_HOME/Downloads"
mkdir -p "$VNC_HOME/bin"

cat << 'EOF' > "$VNC_HOME/.config/openbox/autostart"
# Jalankan panel & wallpaper jika ada
tint2 &

# Logika Startup MT5
(
    export WINEPREFIX="$HOME/.wine"
    MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

    if [ -f "$MT5_EXE" ]; then
        # Jika MT5 sudah terpasang, jalankan terminal64.exe
        if ! pgrep -f "[t]erminal64.exe" >/dev/null; then
            wine "$MT5_EXE" >/dev/null 2>&1 &
        fi
    else
        # Jika MT5 belum ada, unduh dan jalankan installer GUI
        INSTALLER="$HOME/Downloads/mt5setup.exe"
        if [ ! -f "$INSTALLER" ]; then
            wget -q -O "$INSTALLER" "https://www.metatrader5.com/en/download" || true
        fi
        if [ -f "$INSTALLER" ]; then
            wine "$INSTALLER" >/dev/null 2>&1 &
        fi
    fi
) &
EOF

chmod +x "$VNC_HOME/.config/openbox/autostart"
chown -R "$VNC_USER:$VNC_USER" "$VNC_HOME/.config" "$VNC_HOME/Downloads" "$VNC_HOME/bin"

# ------------------------------------------------------------------------------
# 7. Membuat Service Systemd untuk VNC & noVNC
# ------------------------------------------------------------------------------
echo -e "\n\e[34m[7/8] Membuat layanan otomatis (systemd service)...\e[0m"

cat << EOF > /etc/systemd/system/vncserver.service
[Unit]
Description=TigerVNC Server untuk $VNC_USER
After=syslog.target network.target

[Service]
Type=forking
User=$VNC_USER
Group=$VNC_USER
WorkingDirectory=$VNC_HOME
PIDFile=$VNC_HOME/.vnc/%H:1.pid
ExecStartPre=-/usr/bin/vncserver -kill :1 > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :1 -localhost yes -geometry 1366x768 -depth 24
ExecStop=/usr/bin/vncserver -kill :1

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /etc/systemd/system/novnc.service
[Unit]
Description=noVNC Websockify Service
After=vncserver.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ --default_path=index.html?autoconnect=true 6080 localhost:5901
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vncserver.service
systemctl enable --now novnc.service

# ------------------------------------------------------------------------------
# 8. Selesai
# ------------------------------------------------------------------------------
IP_ADDR=$(hostname -I | awk '{print $1}')

echo -e "\n\e[32m====================================================\e[0m"
echo -e "\e[32m               INSTALASI SELESAI!                   \e[0m"
echo -e "\e[32m====================================================\e[0m"
echo -e " Username System/VNC : \e[33m$VNC_USER\e[0m"
echo -e " Akses VNC Browser   : \e[36mhttp://$IP_ADDR:6080/\e[0m"
echo -e "\e[32m====================================================\e[0m"
echo -e "Cukup buka URL di atas pada browser. Layar Openbox dan"
echo -e "installer GUI MetaTrader 5 akan langsung terbuka secara otomatis!"
