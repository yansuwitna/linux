# Panduan Menampilkan & Memperluas Layar Linux ke Tablet (x11vnc + VNC Viewer)

Panduan ini mencakup langkah lengkap untuk menampilkan (*mirroring*) maupun menjadikan tablet (Android atau iPad) sebagai layar kedua (*extended display*) pada sistem operasi Linux menggunakan **x11vnc** dan aplikasi **VNC Viewer**.

---

## Prasyarat Sistem
* **Sesi Desktop X11 (Xorg):** `x11vnc` berjalan secara native pada server tampilan X11. Cek sesi aktif dengan menjalankan perintah berikut di terminal:
  ```bash
  echo $XDG_SESSION_TYPE
  ```
  Jika hasilnya `wayland`, lakukan *log out* terlebih dahulu, lalu pilih opsi **Xorg / X11** pada layar login sebelum masuk kembali.
* **Jaringan Lokal yang Sama:** Pastikan komputer Linux dan tablet terhubung ke jaringan Wi-Fi atau hotspot yang sama.

---

## Bagian 1: Instalasi & Konfigurasi Dasar (Mirroring)

### 1. Instal x11vnc di Linux
Pilih perintah sesuai distribusi Linux yang digunakan:

* **Ubuntu / Debian / Linux Mint:**
  ```bash
  sudo apt update && sudo apt install x11vnc -y
  ```
* **Arch Linux / Manjaro:**
  ```bash
  sudo pacman -S x11vnc
  ```
* **Fedora:**
  ```bash
  sudo dnf install x11vnc -y
  ```

### 2. Buat Kata Sandi Akses VNC
Simpan kata sandi agar sesi VNC terlindungi:
```bash
x11vnc -storepasswd
```
Ketik kata sandi yang diinginkan, konfirmasi ulang, lalu tekan `y` untuk menyimpannya di `~/.vnc/passwd`.

### 3. Jalankan Server x11vnc & Cek IP Lokal
Jalankan server untuk membagikan seluruh layar aktif:
```bash
x11vnc -rfbauth ~/.vnc/passwd -forever -usepw -display :0
```
Buka tab terminal baru untuk melihat alamat IP lokal Linux:
```bash
hostname -I
```
Catat alamat IP yang muncul (contoh: `192.168.1.15`). Port standar yang digunakan adalah **`5900`**.

---

## Bagian 2: Menjadikan Tablet sebagai Layar Kedua (Extended Display)

Secara default, `x11vnc` hanya melakukan *mirroring* (menampilkan salinan layar utama). Untuk menjadikannya layar kedua yang terpisah (*extended monitor*), buat layar virtual menggunakan `xrandr` lalu arahkan `x11vnc` ke area layar virtual tersebut.

### 1. Cek Nama Output Layar yang Tersedia
Jalankan perintah berikut di terminal:
```bash
xrandr
```
Perhatikan nama layar utama yang berstatus `connected` (misalnya `eDP-1` atau `HDMI-1`), serta satu nama port yang berstatus `disconnected` (misalnya `HDMI-2`, `DP-1`, atau `VIRTUAL1`).

### 2. Buat & Aktifkan Resolusi Virtual
Gunakan `cvt` dan `xrandr` untuk membuat mode resolusi yang sesuai dengan layar tablet (contoh resolusi `1920x1080` pada `60Hz`):

```bash
# 1. Dapatkan parameter modeline
cvt 1920 1080 60

# 2. Tambahkan mode baru (sesuaikan nilai setelah --newmode dari output cvt di atas)
xrandr --newmode "1920x1080_60.00" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync

# 3. Pasang mode ke output yang disconnected (ganti HDMI-2 sesuai hasil xrandr Anda)
xrandr --addmode HDMI-2 1920x1080_60.00

# 4. Aktifkan layar virtual di sebelah kanan layar utama (ganti eDP-1 sesuai layar utama Anda)
xrandr --output HDMI-2 --mode 1920x1080_60.00 --right-of eDP-1
```

### 3. Jalankan x11vnc Khusus Area Layar Kedua
Gunakan opsi `-clip` agar `x11vnc` hanya mengirimkan tampilan dari layar virtual kedua ke tablet. Jika layar utama beresolusi `1920x1080` dan layar kedua berada di kanannya (`+1920+0`), jalankan:
```bash
x11vnc -rfbauth ~/.vnc/passwd -forever -usepw -display :0 -clip 1920x1080+1920+0
```

### 4. Menonaktifkan Layar Kedua Setelah Selesai
Jika tablet sudah tidak digunakan sebagai layar tambahan, matikan output virtual agar kursor tidak berpindah ke layar kosong:
```bash
xrandr --output HDMI-2 --off
```

---

## Bagian 3: Koneksi dari Aplikasi VNC Viewer di Tablet

1. Instal aplikasi klien VNC pada tablet Android atau iPad (seperti **RealVNC Viewer**, **bVNC**, atau **MultiVNC**).
2. Buat profil koneksi baru (`+`) dan isi detail berikut:
   * **Address / Host:** `<IP_LINUX>:5900` (contoh: `192.168.1.15:5900`)
   * **Name:** `Layar Kedua Linux`
3. Ketuk **Connect**, setujui peringatan koneksi lokal jika muncul, lalu masukkan kata sandi VNC yang telah dibuat.

---

## Pemecahan Masalah (Troubleshooting)

* **Koneksi Ditolak (*Connection Refused*):** Pastikan firewall tidak memblokir port `5900`. Untuk pengguna UFW (Ubuntu/Mint), jalankan:
  ```bash
  sudo ufw allow 5900/tcp
  ```
* **Tidak Ada Output `disconnected` pada `xrandr`:** Pada beberapa GPU (seperti NVIDIA atau Intel modern), Anda dapat menginstal driver dummy video (`xserver-xorg-video-dummy`) untuk membuat monitor virtual secara permanen.
* **Tampilan Patah-Patah (Lag):** Gunakan jaringan Wi-Fi 5 GHz, aktifkan hotspot langsung dari laptop/tablet, atau gunakan **USB Tethering** dari tablet ke PC Linux agar lalu lintas VNC berjalan melalui kabel USB dengan latensi minimal.
