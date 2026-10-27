# Panduan Setup Multi-User MT5 di Proxmox LXC Debian 12 (LXDE + VNC + Wine 11)

Panduan ini menjelaskan langkah demi langkah membuat lingkungan LXC Debian 12 multi-user di Proxmox VE menggunakan **LXDE Desktop**. Setiap pengguna (`akun1`, `akun2`, `akun3`) akan memiliki sesi desktop grafis lengkap, port VNC/noVNC, serta instalasi MetaTrader 5 (MT5) sendiri di dalam *Wine Prefix* masing-masing tanpa saling mengganggu.

## Pemetaan Port & Sesi Pengguna

| Nama User | VNC Display | Port VNC Internal | Port Web noVNC | URL Browser | 
| ----- | ----- | ----- | ----- | ----- | 
| **akun1** | `:1` | `5901` | `6081` | `http://<IP-LXC>:6081/` | 
| **akun2** | `:2` | `5902` | `6082` | `http://<IP-LXC>:6082/` | 
| **akun3** | `:3` | `5903` | `6083` | `http://<IP-LXC>:6083/` | 

## LANGKAH 1: Membuat Debian 12 LXC di Proxmox

1. Unduh template **Debian 12 (Bookworm)** via Web GUI Proxmox: `local` -> `CT Templates` -> `Templates`.

2. Klik tombol **Create CT** dan isi spesifikasi berikut:

   * **Hostname:** `mt5-multiuser`

   * **CPU:** Minimal 4 Core

   * **RAM:** Minimal 6144 MB (6 GB) atau 8192 MB (8 GB)

   * **Swap:** 4096 MB

   * **Disk:** Minimal 60 GB - 80 GB

   * **Network:** Bridge `vmbr0`, IPv4 DHCP atau IP Statis

3. Pada tab **Options / Features**, aktifkan:

   * `Nesting` (Centang)

   * `keyctl` (Centang)

4. Selesaikan pembuatan container dan jalankan container (Start CT).

## LANGKAH 2: Persiapan Sistem & Instalasi Dependensi (sebagai `root`)

Masuk ke console LXC sebagai `root` dan jalankan perintah berikut:

```bash
# 1. Perbarui sistem & aktifkan arsitektur i386
dpkg --add-architecture i386
apt update && apt full-upgrade -y

# 2. Pasang utilitas sistem, LXDE Desktop, VNC, noVNC, dan haveged (penghasil entropy)
apt install -y \
    sudo curl wget ca-certificates gnupg2 software-properties-common dbus-x11 xauth \
    lxde \
    tigervnc-standalone-server tigervnc-tools novnc websockify \
    haveged

# 3. Pastikan service haveged berjalan agar VNC tidak hang
systemctl enable --now haveged
```

## LANGKAH 3: Pemasangan WineHQ Stable (Wine 11)

```bash
# Tambahkan kunci repository WineHQ
install -d -m 0755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources

# Perbarui paket dan pasang WineHQ Stable
apt update
apt install -y --install-recommends winehq-stable

# Verifikasi versi Wine
wine --version
```

## LANGKAH 4: Menyiapkan Direct Access noVNC (Port Web)

```bash
# Buat symlink index.html agar browser langsung membuka layar VNC tanpa mengetik vnc.html
ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html
```

## LANGKAH 5: Konfigurasi Pengguna (`akun1`, `akun2`, `akun3`)

Berikut adalah langkah manual untuk setup salah satu user (contoh **`akun1`** dengan Display `:1`, Port VNC `5901`, & Web Port `6081`):

```bash
# 1. Buat user & set password
useradd -m -s /bin/bash akun1
echo "akun1:password123" | chpasswd
usermod -aG sudo akun1

# 2. Buat direktori & password VNC
mkdir -p /home/akun1/.vnc
chown -R akun1:akun1 /home/akun1/.vnc
chmod 700 /home/akun1/.vnc

su - akun1 -c "vncpasswd -f <<< 'password123' > '/home/akun1/.vnc/passwd'"
chmod 600 /home/akun1/.vnc/passwd

# 3. Buat berkas xstartup LXDE & Auto-launch MT5
cat << 'EOF' > /home/akun1/.vnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Auto-launch MT5 di latar belakang saat LXDE dimulai
(
    export WINEPREFIX="$HOME/.wine"
    MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

    if [ -f "$MT5_EXE" ]; then
        if ! pgrep -u "$(id -u)" -f "[t]erminal64.exe" >/dev/null; then
            wine "$MT5_EXE" >/dev/null 2>&1 &
        fi
    else
        INSTALLER="$HOME/Downloads/mt5setup.exe"
        if [ ! -f "$INSTALLER" ]; then
            wget -q -O "$INSTALLER" "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe" || true
        fi
        if [ -f "$INSTALLER" ]; then
            wine "$INSTALLER" >/dev/null 2>&1 &
        fi
    fi
) &

exec startlxde
EOF

chmod +x /home/akun1/.vnc/xstartup
chown akun1:akun1 /home/akun1/.vnc/xstartup
mkdir -p /home/akun1/Downloads
chown akun1:akun1 /home/akun1/Downloads
```

## LANGKAH 6: Membuat Service Systemd yang Stabil (Type=simple & -fg)

Gunakan konfigurasi `Type=simple` dengan argumen `-fg` untuk VNC dan format bersih untuk noVNC agar terhindar dari *timeout*:

```bash
# 1. Service VNC Display :1 (Type=simple + -fg)
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

# 2. Service noVNC Web Port 6081 (Format Bersih)
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

# Aktifkan dan jalankan service
systemctl daemon-reload
systemctl enable --now vncserver-akun1.service
systemctl enable --now novnc-akun1.service
```

## SKRIP AUTOMATISASI ALL-IN-ONE (`install-multiuser.sh`)

Skrip otomatisasi penuh untuk 3 akun sekaligus dengan LXDE dan konfigurasi service yang stabil:

```bash
#!/usr/bin/env bash
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Harus dijalankan sebagai root!"
    exit 1
fi

echo "=== Memulai Instalasi Multi-User LXDE & MT5 LXC ==="

# 1. Depedensi & System Tuning
dpkg --add-architecture i386
apt update && apt full-upgrade -y
apt install -y sudo curl wget ca-certificates gnupg2 software-properties-common dbus-x11 xauth \
    lxde tigervnc-standalone-server tigervnc-tools novnc websockify haveged

systemctl enable --now haveged

# 2. WineHQ
install -d -m 0755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources
apt update
apt install -y --install-recommends winehq-stable

ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 3. Fungsi Buat User & Service
setup_user() {
    USER_NAME="$1"
    USER_PASS="$2"
    DISPLAY_NUM="$3"
    VNC_PORT="$4"
    WEB_PORT="$5"
    USER_HOME="/home/$USER_NAME"

    echo "Konfigurasi $USER_NAME (Display :$DISPLAY_NUM, Web Port: $WEB_PORT)..."

    if ! id "$USER_NAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USER_NAME"
    fi
    echo "$USER_NAME:$USER_PASS" | chpasswd
    usermod -aG sudo "$USER_NAME"

    mkdir -p "$USER_HOME/.vnc" "$USER_HOME/Downloads"
    chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.vnc" "$USER_HOME/Downloads"
    chmod 700 "$USER_HOME/.vnc"

    su - "$USER_NAME" -c "vncpasswd -f <<< '$USER_PASS' > '$USER_HOME/.vnc/passwd'"
    chmod 600 "$USER_HOME/.vnc/passwd"

    cat << EOF > "$USER_HOME/.vnc/xstartup"
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

(
    export WINEPREFIX="\$HOME/.wine"
    MT5_EXE="\$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    if [ -f "\$MT5_EXE" ]; then
        if ! pgrep -u "\$(id -u)" -f "[t]erminal64.exe" >/dev/null; then
            wine "\$MT5_EXE" >/dev/null 2>&1 &
        fi
    else
        INSTALLER="\$HOME/Downloads/mt5setup.exe"
        if [ ! -f "\$INSTALLER" ]; then
            wget -q -O "\$INSTALLER" "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe" || true
        fi
        if [ -f "\$INSTALLER" ]; then
            wine "\$INSTALLER" >/dev/null 2>&1 &
        fi
    fi
) &

exec startlxde
EOF

    chmod +x "$USER_HOME/.vnc/xstartup"
    chown "$USER_NAME:$USER_NAME" "$USER_HOME/.vnc/xstartup"

    # Services (Type=simple + -fg)
    cat << EOF > /etc/systemd/system/vncserver-$USER_NAME.service
[Unit]
Description=TigerVNC Server untuk $USER_NAME (:$DISPLAY_NUM)
After=syslog.target network.target

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$USER_HOME
ExecStartPre=-/usr/bin/vncserver -kill :$DISPLAY_NUM > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :$DISPLAY_NUM -fg -localhost yes -geometry 1366x768 -depth 24
ExecStop=/usr/bin/vncserver -kill :$DISPLAY_NUM
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    cat << EOF > /etc/systemd/system/novnc-$USER_NAME.service
[Unit]
Description=noVNC Service untuk $USER_NAME (Port $WEB_PORT)
After=vncserver-$USER_NAME.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ $WEB_PORT localhost:$VNC_PORT
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now vncserver-$USER_NAME.service
    systemctl enable --now novnc-$USER_NAME.service
}

# Eksekusi 3 User
setup_user "akun1" "passAkun1_123" "1" "5901" "6081"
setup_user "akun2" "passAkun2_123" "2" "5902" "6082"
setup_user "akun3" "passAkun3_123" "3" "5903" "6083"

IP_ADDR=$(hostname -I | awk '{print $1}')
echo "===================================================="
echo " INSTALASI MULTI-USER LXDE SELESAI!"
echo "===================================================="
echo " akun1 -> http://$IP_ADDR:6081/vnc.html (Pass VNC: passAkun1_123)"
echo " akun2 -> http://$IP_ADDR:6082/vnc.html (Pass VNC: passAkun2_123)"
echo " akun3 -> http://$IP_ADDR:6083/vnc.html (Pass VNC: passAkun3_123)"
echo "===================================================="
```  
