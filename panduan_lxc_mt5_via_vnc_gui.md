# Panduan Instalasi MetaTrader 5 di Debian 12 LXC Proxmox (Metode GUI & VNC)

Panduan ini berisi langkah-langkah pembuatan Debian 12 LXC di Proxmox, konfigurasi desktop VNC/noVNC, serta pemasangan Wine dan MetaTrader 5 (MT5) yang berfokus pada eksekusi berbasis antarmuka grafis (GUI).

---

## 📋 Ringkasan Spesifikasi & Prerequisites

- **Container Host:** Proxmox VE (LXC)
- **OS Container:** Debian 12 (Bookworm)
- **Desktop Environment:** XFCE4 + TigerVNC + noVNC
- **User Desktop:** `vncuser` (non-root)
- **Target Wine:** WineHQ 11.0 (Arsitektur `i386` + `amd64`)
- **Fitur LXC Wajib:** `Nesting` dan `keyctl` diaktifkan

---

## 1. Membuat Debian 12 LXC di Proxmox

### Langkah di Antarmuka Proxmox (Web GUI)
1. Unduh template **Debian 12 (Bookworm)** via **local → CT Templates → Templates**.
2. Klik **Create CT** dan isi parameter berikut:
   - **Hostname:** `mt5-gui`
   - **Template:** Debian 12
   - **CPU:** 2 Core (atau disesuaikan)
   - **RAM / Swap:** 5120 MB / 5120 MB
   - **Disk:** 80 GB
   - **Network:** Bridge `vmbr0`, IP DHCP atau Statis
3. Pada tab **Options / Features**, aktifkan:
   - [x] `Nesting`
   - [x] `keyctl`
4. Centang **Start at boot** jika diperlukan, lalu jalankan container.

### Pembaruan Sistem Awal (Console Proxmox / SSH)
Jalankan perintah berikut sebagai `root` di console container:

```bash
apt update && apt full-upgrade -y
apt install -y sudo curl wget ca-certificates gnupg2 software-properties-common dbus-x11 xauth
dpkg --add-architecture i386 && apt update
```

---

## 2. Membuat Pengguna Desktop (`vncuser`)

Untuk alasan keamanan dan kesesuaian prefix Wine, jalankan desktop dan MT5 sebagai user non-root:

```bash
adduser vncuser
usermod -aG sudo vncuser
chown -R vncuser:vncuser /home/vncuser
```

---

## 3. Memasang Lingkungan Desktop & VNC/noVNC

### Pemasangan Paket
Pasang XFCE4, server VNC, dan noVNC:

```bash
apt install -y xfce4 xfce4-terminal dbus-x11 xauth tigervnc-standalone-server tigervnc-tools novnc websockify
```

### Konfigurasi VNC
Buat direktori konfigurasi dan skrip startup desktop XFCE:

```bash
install -d -o vncuser -g vncuser /home/vncuser/.vnc
printf '%s\n' '#!/bin/sh' 'unset SESSION_MANAGER' 'unset DBUS_SESSION_BUS_ADDRESS' 'exec startxfce4' > /home/vncuser/.vnc/xstartup
chown vncuser:vncuser /home/vncuser/.vnc/xstartup
chmod +x /home/vncuser/.vnc/xstartup
```

Setel password VNC untuk user `vncuser`:

```bash
su - vncuser -c 'vncpasswd'
```

### Jalankan Layanan VNC & noVNC
Jalankan VNC server pada display `:1` dan aktifkan jembatan noVNC untuk akses browser:

```bash
su - vncuser -c 'vncserver :1 -localhost yes -geometry 1366x768 -depth 24'
websockify --web=/usr/share/novnc/ 6080 localhost:5901 &
```

> **Akses Browser:** Buka alamat `http://<IP-LXC-Anda>:6080/vnc.html` dari komputer lokal Anda, lalu masukkan kata sandi VNC yang telah dibuat.

---

## 4. Instalasi WineHQ via Terminal GUI

Setelah berhasil masuk ke desktop XFCE melalui noVNC/VNC:

1. Buka **XFCE Terminal** dari menu aplikasi desktop (**Applications → Terminal Emulator**).
2. Tambahkan kunci GPG dan repositori resmi WineHQ:

```bash
sudo install -d -m 0755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources
sudo apt update
```

3. Pasang paket `winehq-stable`:

```bash
sudo apt install --install-recommends winehq-stable=11.0.0.0~bookworm-1 -y
```

4. Verifikasi pemasangan Wine:

```bash
wine --version
```
*(Memastikan output menampilkan versi `wine-11.0`)*

---

## 5. Mengunduh & Memasang MetaTrader 5 via GUI Setup Wizard

1. **Unduh Installer MT5:**
   - Buka web browser di dalam desktop XFCE (misalnya Web Browser bawaan) dan unduh `mt5setup.exe` dari situs resmi MetaTrader 5 atau broker Anda.
   - Secara bawaan, berkas akan tersimpan di direktori `/home/vncuser/Downloads`.

2. **Jalankan Installer dengan Wine GUI:**
   - Buka **Thunar File Manager** (**Applications → File Manager**).
   - Buka folder `Downloads`.
   - Klik kanan pada berkas `mt5setup.exe` dan pilih **Open With "Wine Program Loader"**.
   - *Alternatif dari XFCE Terminal:*
     ```bash
     cd ~/Downloads
     wine mt5setup.exe
     ```

3. **Proses Setup Wizard MT5:**
   - Jendela GUI penyiapan MetaTrader 5 akan muncul di layar desktop VNC Anda.
   - Klik **Next**, setujui perjanjian lisensi, dan biarkan proses pengunduhan serta pemasangan komponen MT5 berjalan hingga selesai.
   - Klik **Finish** setelah instalasi selesai.

---

## 6. Menjalankan MT5 dan Membuat Pintasan (Shortcut)

### Menjalankan MT5
MetaTrader 5 akan otomatis terbuka setelah instalasi selesai. Jika ditutup, Anda dapat membukanya kembali via terminal atau File Manager dari lokasi executable default:

```bash
WINEPREFIX="/home/vncuser/.wine" wine "/home/vncuser/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
```

### Membuat Desktop Autostart (Opsional)
Agar MT5 langsung berjalan otomatis begitu sesi VNC dibuka:

1. Buat direktori autostart XDG:
   ```bash
   mkdir -p /home/vncuser/.config/autostart
   ```
2. Buat berkas desktop launcher `/home/vncuser/.config/autostart/metatrader5.desktop`:
   ```ini
   [Desktop Entry]
   Type=Application
   Name=MetaTrader 5
   Comment=Jalankan MT5 Otomatis
   Exec=wine "/home/vncuser/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
   Terminal=false
   X-GNOME-Autostart-enabled=true
   ```
3. Atur hak akses:
   ```bash
   chown -R vncuser:vncuser /home/vncuser/.config/autostart
   ```

---

## 🛠️ Ringkasan Troubleshooting GUI

- **MT5 tidak mau berjalan / Debugger warning:**
  Pastikan perintah peluncuran dipanggil tanpa hak akses `root` (`sudo`). prefix `.wine` harus dimiliki sepenuhnya oleh `vncuser`.
- **Layar VNC Blank / Hitam:**
  Periksa status VNC server dengan `su - vncuser -c 'vncserver -list'` dan pastikan skrip `~/.vnc/xstartup` memiliki hak akses eksekusi (`chmod +x`).
