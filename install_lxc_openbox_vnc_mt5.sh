#!/bin/bash

# ==============================================================================
# Skrip Instalasi Otomatis LXC Debian 12
# Features: Openbox + Dynamic User/Password + VNC/noVNC (Direct Port 6080) + WineHQ 11 + MT5
# ==============================================================================

set -e

# Warna Output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}  Skrip Instalasi Otomatis MetaTrader 5 + Openbox   ${NC}"
echo -e "${BLUE}====================================================${NC}"

# ------------------------------------------------------------------------------
# 0. INPUT USERNAME DAN PASSWORD VNC SECARA DINAMIS
# ------------------------------------------------------------------------------
if [ -n "$1" ] && [ -n "$2" ]; then
    VNC_USER="$1"
    VNC_PASS="$2"
    echo -e "${GREEN}[+] Menggunakan kredensial dari argumen baris perintah.${NC}"
else
    echo -e "${YELLOW}[?] Silakan masukkan kredensial untuk pengguna VNC:${NC}"
    
    # Input Username
    read -p "    Masukkan Username [default: vncuser]: " INPUT_USER
    VNC_USER=${INPUT_USER:-vncuser}

    # Input Password VNC
    while true; do
        read -sp "    Masukkan Password VNC (min. 6 karakter): " VNC_PASS
        echo ""
        if [ ${#VNC_PASS} -lt 6 ]; then
            echo -e "${RED}[!] Password terlalu pendek. Minimal 6 karakter.${NC}"
            continue
        fi
        
        read -sp "    Konfirmasi Password VNC: " VNC_PASS_CONFIRM
        echo ""
        if [ "$VNC_PASS" != "$VNC_PASS_CONFIRM" ]; then
            echo -e "${RED}[!] Password tidak cocok. Silakan coba lagi.${NC}"
        else
            break
        fi
    done
fi

USER_HOME="/home/$VNC_USER"

echo ""
echo -e "${GREEN}[INFO] Konfigurasi Pengguna:${NC}"
echo -e "       Username : ${YELLOW}$VNC_USER${NC}"
echo -e "       Home Dir : ${YELLOW}$USER_HOME${NC}"
echo -e "${BLUE}====================================================${NC}"
echo ""
sleep 2

# ------------------------------------------------------------------------------
# 1. UPDATE SISTEM & DEPENDENSI DASAR
# ------------------------------------------------------------------------------
echo -e "${GREEN}[1/8] Menginstal paket dasar dan mengaktifkan i386...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update && apt full-upgrade -y
apt install -y sudo curl wget ca-certificates gnupg2 software-properties-common dbus-x11 xauth build-essential

dpkg --add-architecture i386
apt update

# ------------------------------------------------------------------------------
# 2. MEMBUAT PENGGUNA DESKTOP
# ------------------------------------------------------------------------------
echo -e "${GREEN}[2/8] Membuat pengguna sistem '$VNC_USER'...${NC}"
if id "$VNC_USER" &>/dev/null; then
    echo -e "${YELLOW}[!] Pengguna '$VNC_USER' sudah ada.${NC}"
else
    useradd -m -s /bin/bash "$VNC_USER"
    echo "$VNC_USER:$VNC_PASS" | chpasswd
    usermod -aG sudo "$VNC_USER"
fi

mkdir -p "$USER_HOME"
chown -R "$VNC_USER:$VNC_USER" "$USER_HOME"

# ------------------------------------------------------------------------------
# 3. MEMASANG OPENBOX, TIGERVNC, DAN NOVNC
# ------------------------------------------------------------------------------
echo -e "${GREEN}[3/8] Memasang Openbox GUI dan VNC Server...${NC}"
apt install -y openbox tint2 feh lxterminal thunar tigervnc-standalone-server tigervnc-tools novnc websockify

# Buat Symlink index.html agar port 6080 langsung membuka vnc.html
ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# ------------------------------------------------------------------------------
# 4. KONFIGURASI VNC & OPENBOX USER
# ------------------------------------------------------------------------------
echo -e "${GREEN}[4/8] Mengonfigurasi sesi VNC & Openbox...${NC}"
mkdir -p "$USER_HOME/.vnc"
mkdir -p "$USER_HOME/.config/openbox"
mkdir -p "$USER_HOME/bin"
mkdir -p "$USER_HOME/Downloads"

# Atur Password VNC secara non-interaktif
su - "$VNC_USER" -c "echo '$VNC_PASS' | vncpasswd -f > '$USER_HOME/.vnc/passwd'"
chmod 600 "$USER_HOME/.vnc/passwd"

# Buat Skrip xstartup VNC
cat << 'EOF' > "$USER_HOME/.vnc/xstartup"
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec openbox-session
EOF
chmod +x "$USER_HOME/.vnc/xstartup"

# ------------------------------------------------------------------------------
# 5. MEMASANG WINEHQ 11 (DEBIAN 12 BOOKWORM)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[5/8] Memasang WineHQ 11...${NC}"
install -d -m 0755 /etc/apt/keyrings
wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources
apt update

apt install --install-recommends winehq-stable=11.0.0.0~bookworm-1 -y || apt install --install-recommends winehq-stable -y

# ------------------------------------------------------------------------------
# 6. PENYIAPAN MULTI-LOGIC AUTOSTART (MT5 INSTALLER & TERMINAL)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[6/8] Mengunduh Installer MT5 & Mengatur Autostart...${NC}"

# Unduh MT5 Installer
MT5_SETUP_PATH="$USER_HOME/Downloads/mt5setup.exe"
wget -O "$MT5_SETUP_PATH" "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe" || true
chown "$VNC_USER:$VNC_USER" "$MT5_SETUP_PATH"

# Skrip Peluncur MT5 Dinamis
cat << EOF > "$USER_HOME/bin/start-mt5.sh"
#!/bin/bash
export WINEPREFIX="$USER_HOME/.wine"
MT5_EXE="$USER_HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"

if [ -f "\$MT5_EXE" ]; then
    if ! pgrep -u "\$(id -u)" -f "[t]erminal64.exe" >/dev/null; then
        wine "\$MT5_EXE" > "$USER_HOME/mt5.log" 2>&1 &
    fi
else
    if [ -f "$MT5_SETUP_PATH" ]; then
        wine "$MT5_SETUP_PATH" > "$USER_HOME/mt5-install.log" 2>&1 &
    fi
fi
EOF
chmod +x "$USER_HOME/bin/start-mt5.sh"

# Konfigurasi Openbox Autostart
cat << EOF > "$USER_HOME/.config/openbox/autostart"
tint2 &
feh --bg-scale /usr/share/images/desktop-base/default || true &
$USER_HOME/bin/start-mt5.sh &
EOF

chown -R "$VNC_USER:$VNC_USER" "$USER_HOME"

# ------------------------------------------------------------------------------
# 7. MEMBUAT SYSTEMD SERVICES (AUTOMATIC VNC & NOVNC ON BOOT)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[7/8] Membuat layanan Systemd VNC dan noVNC...${NC}"

# Layanan VNC Server
cat << EOF > /etc/systemd/system/vncserver.service
[Unit]
Description=TigerVNC Server untuk $VNC_USER
After=syslog.target network.target

[Service]
Type=forking
User=$VNC_USER
Group=$VNC_USER
WorkingDirectory=$USER_HOME
PIDFile=$USER_HOME/.vnc/%H:1.pid
ExecStartPre=-/usr/bin/vncserver -kill :1 > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :1 -localhost yes -geometry 1366x768 -depth 24
ExecStop=/usr/bin/vncserver -kill :1

[Install]
WantedBy=multi-user.target
EOF

# Layanan noVNC (Port 6080 Direct Launch with Autoconnect)
cat << EOF > /etc/systemd/system/novnc.service
[Unit]
Description=noVNC Web Service Direct Access
After=vncserver.service
Requires=vncserver.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ --default_path=index.html?autoconnect=true 6080 localhost:5901
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vncserver
systemctl enable --now novnc

# ------------------------------------------------------------------------------
# 8. SELESAI
# ------------------------------------------------------------------------------
IP_ADDR=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  INSTALASI SELESAI & BERHASIL!                    ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e " Username VNC : ${YELLOW}$VNC_USER${NC}"
echo -e " Password VNC : ${YELLOW}(Sesuai input Anda)${NC}"
echo -e ""
echo -e " Akses VNC langsung melalui Browser:"
echo -e " ${BLUE}http://$IP_ADDR:6080/${NC}"
echo -e ""
echo -e " ${YELLOW}Catatan:${NC} Begitu URL di atas dibuka, Openbox akan langsung"
echo -e " memunculkan installer MetaTrader 5 secara otomatis!"
echo -e "${GREEN}====================================================${NC}"
