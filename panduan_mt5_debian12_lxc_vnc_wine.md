# Panduan Instalasi MetaTrader 5 di Debian 12 LXC Proxmox dengan VNC dan Wine

Panduan ini merangkum pembuatan LXC, desktop jarak jauh melalui
VNC/noVNC, instalasi Wine, pemasangan MetaTrader 5 (MT5), pengujian,
serta pembuatan berkas startup otomatis.

> **Kondisi akhir yang berhasil diuji**
>
> -   Container: Debian 12 di Proxmox LXC.
> -   Pengguna desktop: `vncuser`, home `/home/vncuser`.
> -   Wine aktif: `wine-11.0`.
> -   MT5:
>     `/home/vncuser/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe`.
> -   MT5 berhasil terbuka saat dijalankan dengan prefix
>     `/home/vncuser/.wine`.
> -   Ada juga instalasi MT5 terpisah di prefix PlayOnLinux:
>     `/home/vncuser/.PlayOnLinux/wineprefix/WIN64/`. Jangan mencampur
>     kedua prefix.
> -   MT4 sebelumnya berjalan dengan Wine 8.0. Hindari menghapus prefix
>     atau mengubah instalasi MT4 saat mengikuti panduan ini.

**Catatan akurasi:** nilai spesifikasi LXC di bawah adalah konfigurasi
contoh yang pernah digunakan. Sesuaikan CT ID, alamat IP, storage,
bridge, serta detail jaringan dengan Proxmox Anda. Nama desktop dapat
berbeda tergantung desktop yang benar-benar dipasang; langkah startup di
bagian akhir menggunakan autostart desktop XDG yang umum dipakai
LXDE/XFCE.

------------------------------------------------------------------------

## 1. Membuat Debian 12 LXC di Proxmox

### Pilihan melalui antarmuka Proxmox

1.  Unduh template **Debian 12 (Bookworm)** melalui **local → CT
    Templates → Templates**.
2.  Klik **Create CT**.
3.  Isi hostname, misalnya `mt5`.
4.  Pilih template Debian 12.
5.  Contoh spesifikasi yang dapat digunakan:
    -   CPU: 2 core
    -   RAM: 5120 MB
    -   Swap: 5120 MB
    -   Disk: 80 GB
    -   Network: bridge `vmbr0`, IPv4 DHCP atau alamat statis yang
        sesuai jaringan
6.  Aktifkan fitur yang diperlukan untuk lingkungan desktop/Wine bila
    dibutuhkan:
    -   `Nesting`
    -   `keyctl`
7.  Aktifkan **Start at boot** bila container perlu hidup otomatis saat
    host Proxmox menyala.
8.  Selesaikan pembuatan container dan jalankan.

> Gunakan konfigurasi privileged hanya jika memang diperlukan oleh setup
> Anda dan pahami implikasi keamanannya. Jika memakai unprivileged LXC,
> beberapa kemampuan grafis/perangkat bisa memerlukan konfigurasi
> tambahan.

### Perbarui Debian

Masuk ke console container sebagai `root`, kemudian jalankan setiap
perintah satu baris:

``` bash
apt update && apt full-upgrade -y
```

Pasang utilitas dasar:

``` bash
apt install -y sudo curl wget ca-certificates gnupg2 software-properties-common dbus-x11 xauth
```

Aktifkan arsitektur i386 untuk aplikasi Windows 32-bit atau dependensi
Wine:

``` bash
dpkg --add-architecture i386 && apt update
```

## 2. Membuat pengguna desktop `vncuser`

Jika pengguna tersebut belum ada:

``` bash
adduser vncuser
```

Jika diperlukan hak `sudo`:

``` bash
usermod -aG sudo vncuser
```

Pastikan direktori home dan pemiliknya benar:

``` bash
chown -R vncuser:vncuser /home/vncuser
```

Jangan menjalankan MT5 dengan `sudo wine`. Jalankan aplikasi sebagai
`vncuser` agar prefix Wine berada di `/home/vncuser/.wine`, bukan di
home root.

## 3. Memasang desktop dan VNC/noVNC

Salah satu setup desktop yang pernah digunakan adalah XFCE + TigerVNC +
noVNC. Jika container Anda sudah menggunakan LXDE dan VNC/noVNC bekerja,
jangan memasang desktop lain tanpa kebutuhan karena dua desktop dapat
membuat konfigurasi sesi membingungkan.

Untuk setup XFCE baru:

``` bash
apt install -y xfce4 xfce4-terminal dbus-x11 xauth tigervnc-standalone-server tigervnc-tools novnc websockify
```

Buat direktori konfigurasi VNC untuk pengguna:

``` bash
install -d -o vncuser -g vncuser /home/vncuser/.vnc
```

Buat skrip sesi desktop XFCE:

``` bash
printf '%s\n' '#!/bin/sh' 'unset SESSION_MANAGER' 'unset DBUS_SESSION_BUS_ADDRESS' 'exec startxfce4' > /home/vncuser/.vnc/xstartup && chown vncuser:vncuser /home/vncuser/.vnc/xstartup && chmod +x /home/vncuser/.vnc/xstartup
```

Setel kata sandi VNC sebagai pengguna `vncuser`:

``` bash
su - vncuser -c 'vncpasswd'
```

Mulai server VNC pada display `:1`, resolusi 1366×768 dan kedalaman
warna 24 bit:

``` bash
su - vncuser -c 'vncserver :1 -localhost yes -geometry 1366x768 -depth 24'
```

Port VNC display `:1` biasanya `5901`. Untuk akses browser melalui
noVNC, port web yang umum dipakai adalah `6080`. Jangan membuka
VNC/noVNC langsung ke internet tanpa pengamanan; utamakan jaringan
privat atau reverse proxy dengan autentikasi.

Contoh menjalankan websockify/noVNC secara manual (pastikan jalur
`vnc.html` cocok dengan paket yang terpasang):

``` bash
websockify --web=/usr/share/novnc/ 6080 localhost:5901
```

Perintah manual ini berjalan di foreground; untuk layanan permanen
sebaiknya gunakan unit systemd yang sesuai dengan konfigurasi aktual.
Jika noVNC dan VNC sudah dapat digunakan, lanjutkan ke bagian Wine.

## 4. Memasang WineHQ untuk Debian 12

> **Peringatan:** mengganti Wine sistem dari Wine 8 ke Wine 11 dapat
> memengaruhi aplikasi yang memakai Wine sistem. MT4 Anda sebelumnya
> berjalan dengan Wine 8. Jangan hapus prefix MT4. Untuk percobaan
> paling aman, buat backup/snapshot LXC terlebih dahulu atau uji pada
> clone.

Tambahkan keyring WineHQ:

``` bash
install -d -m 0755 /etc/apt/keyrings && wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
```

Unduh sumber repositori untuk Debian 12 Bookworm:

``` bash
wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources
```

Perbarui indeks paket:

``` bash
apt update
```

Periksa kandidat versi Wine yang tersedia:

``` bash
apt-cache policy winehq-stable wine-stable wine-stable-amd64 wine-stable-i386
```

Simulasikan pemasangan sebelum melakukan perubahan:

``` bash
apt -s install --install-recommends winehq-stable=11.0.0.0~bookworm-1
```

Dalam sesi ini, simulasi tersebut menampilkan penggantian paket Debian
`wine` versi 8.0 oleh paket WineHQ 11.0.0 untuk Bookworm. Jika simulasi
di sistem Anda berbeda, **jangan langsung menyalin versi paket secara
membabi buta**; gunakan versi yang benar-benar tersedia pada
`apt-cache policy`.

Jika dependensi dapat dipenuhi dan Anda sudah memiliki backup/snapshot:

``` bash
apt install --install-recommends winehq-stable=11.0.0.0~bookworm-1
```

Verifikasi versi:

``` bash
wine --version
```

Hasil yang diuji pada sesi ini:

``` text
wine-11.0
```

### Jika muncul masalah dependensi

Periksa apakah sumber WineHQ Debian 13/Trixie ikut aktif:

``` bash
grep -Rin 'trixie' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
```

Jangan mencampur paket Trixie dengan Debian 12 Bookworm. Nonaktifkan
hanya berkas sumber Trixie milik WineHQ yang benar-benar ditemukan, lalu
jalankan `apt update` dan periksa kembali kebijakan paket.

## 5. Membuat prefix Wine MT5

Jalankan langkah ini sebagai pengguna `vncuser`, bukan root. Prefix MT5
yang berhasil digunakan pada sesi ini adalah `/home/vncuser/.wine`.

Periksa pengguna, home, versi Wine, dan prefix:

``` bash
whoami; echo "$HOME"; echo "WINEPREFIX=$WINEPREFIX"; wine --version
```

Pastikan pengguna yang aktif adalah `vncuser` dan home adalah
`/home/vncuser`.

Jika prefix `.wine` sudah ada dan berisi aplikasi yang sedang digunakan,
**jangan menginisialisasi ulang atau menghapusnya**. Periksa dulu
isinya:

``` bash
ls -lah /home/vncuser/.wine
```

Untuk membuat prefix baru yang benar-benar terpisah bagi MT5, gunakan
direktori baru, misalnya `/home/vncuser/.mt5-wine11`:

``` bash
WINEPREFIX=/home/vncuser/.mt5-wine11 wineboot -u
```

Buka pengaturan Windows untuk prefix baru:

``` bash
WINEPREFIX=/home/vncuser/.mt5-wine11 winecfg
```

Pilih Windows 10 atau Windows 11 pada tab Applications jika diperlukan,
kemudian tutup jendela. Prefix baru tersebut tidak otomatis berisi MT5;
MT5 harus diinstal ke prefix itu secara khusus.

**Kondisi yang benar-benar berhasil dalam sesi ini:** MT5 dibuka dari
prefix yang sudah ada di `/home/vncuser/.wine`. Jika ingin
mempertahankan kondisi yang sudah berhasil, jangan memindahkan MT5 ke
prefix lain sebelum membuat backup dan mengujinya.

## 6. Memasang MT5

Unduh installer MT5 dari situs resmi MetaQuotes atau dari situs resmi
broker yang Anda gunakan:

-   https://www.metatrader5.com/en/download

Jalankan installer sebagai `vncuser`. Contoh berikut mengasumsikan
installer bernama `mt5setup.exe` berada di direktori Downloads dan
targetnya prefix `/home/vncuser/.wine`:

``` bash
WINEPREFIX=/home/vncuser/.wine wine "$HOME/Downloads/mt5setup.exe"
```

Sesuaikan nama berkas dan lokasinya dengan installer yang benar-benar
diunduh. Ikuti wizard instalasi sampai selesai.

Lokasi executable yang ditemukan pada sistem ini:

``` text
/home/vncuser/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe
```

Ada instalasi lain di:

``` text
/home/vncuser/.PlayOnLinux/wineprefix/WIN64/drive_c/Program Files/MetaTrader 5/terminal64.exe
```

Kedua lokasi tersebut adalah instalasi/prefix yang berbeda. Jangan
menganggap pengujian pada satu prefix membuktikan prefix lainnya juga
berfungsi.

## 7. Mengatasi pesan debugger saat MT5 dibuka

Pesan yang terlihat sebelumnya:

``` text
A debugger has been found running in your system. Please, unload it from memory and restart your program.
```

Log Wine yang juga terlihat:

``` text
fixme:ntdll:NtRaiseHardError ... stub
```

Baris `fixme ... stub` tidak dengan sendirinya membuktikan penyebab
error. Dalam pengujian ini, MT5 kemudian berhasil muncul saat
diluncurkan menggunakan prefix `/home/vncuser/.wine` dengan Wine 11.0.

### Periksa proses debugger

``` bash
ps aux | grep -Ei '[g]db|[l]ldb|[w]inedbg|[d]ebugger'
```

Tidak adanya hasil hanya berarti proses dengan nama yang dicari tidak
terlihat; itu tidak membuktikan tidak ada pemeriksaan debugger internal
oleh MT5.

### Periksa lokasi executable

``` bash
find /home /root -type f -iname 'terminal64.exe' 2>/dev/null
```

### Jalankan MT5 dengan log diagnostik

Perintah satu baris yang digunakan untuk menguji executable pada prefix
`.wine`:

``` bash
WINEPREFIX="/home/vncuser/.wine" WINEDEBUG=+seh,+tid wine "/home/vncuser/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" 2>&1 | tee "/home/vncuser/mt5-seh.log"
```

Perintah ini berhasil menampilkan jendela MT5 pada pengujian. Jika ingin
melihat bagian akhir log:

``` bash
tail -n 100 /home/vncuser/mt5-seh.log
```

Jangan mengubah registry atau mematikan perlindungan keamanan secara
acak. Jika MT5 sudah berhasil terbuka, lanjutkan dengan pengujian
koneksi akun broker dan stabilitas aplikasi.

## 8. Uji jalankan MT5 secara normal

Jalankan sebagai `vncuser`:

``` bash
WINEPREFIX="/home/vncuser/.wine" wine "/home/vncuser/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
```

Periksa proses:

``` bash
pgrep -af 'terminal64.exe'
```

Pastikan: - Jendela MT5 terbuka. - Pesan debugger tidak muncul. -
Terminal tidak langsung menutup. - Koneksi ke server broker dapat diuji
melalui akun yang sah.

## 9. Membuat skrip startup MT5

Skrip berikut menjalankan MT5 dari prefix `.wine`. Skrip memeriksa
proses terlebih dahulu agar tidak sengaja membuka instance kedua jika
`terminal64.exe` sudah terdeteksi.

Buat direktori skrip:

``` bash
mkdir -p /home/vncuser/bin
```

Buat skrip startup:

``` bash
printf '%s\n' '#!/bin/bash' 'export WINEPREFIX="/home/vncuser/.wine"' 'cd "$WINEPREFIX/drive_c/Program Files/MetaTrader 5" || exit 1' 'if ! pgrep -u "$(id -u)" -f "[t]erminal64.exe" >/dev/null; then wine "$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe" >/home/vncuser/mt5-autostart.log 2>&1; fi' > /home/vncuser/bin/jalankan-mt5.sh && chmod +x /home/vncuser/bin/jalankan-mt5.sh
```

Pastikan kepemilikan berkas:

``` bash
chown vncuser:vncuser /home/vncuser/bin/jalankan-mt5.sh
```

Uji skrip secara manual:

``` bash
/home/vncuser/bin/jalankan-mt5.sh
```

Jika gagal, periksa log:

``` bash
tail -n 50 /home/vncuser/mt5-autostart.log
```

> Skrip ini menggunakan prefix MT5 yang sudah ada,
> `/home/vncuser/.wine`. Jika prefix tersebut juga berisi MT4 atau
> aplikasi lain, pertimbangkan memindahkan MT5 ke prefix terpisah
> setelah melakukan backup dan menguji instalasi baru. Jangan menghapus
> prefix `.wine` yang sekarang.

## 10. Mengatur startup saat desktop VNC dibuka

Buat direktori autostart desktop:

``` bash
mkdir -p /home/vncuser/.config/autostart
```

Buat berkas `metatrader5.desktop`:

``` bash
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=MetaTrader 5' 'Comment=Menjalankan MetaTrader 5 otomatis' 'Exec=/home/vncuser/bin/jalankan-mt5.sh' 'Terminal=false' 'X-GNOME-Autostart-enabled=true' > /home/vncuser/.config/autostart/metatrader5.desktop
```

Atur pemilik berkas:

``` bash
chown -R vncuser:vncuser /home/vncuser/bin /home/vncuser/.config/autostart
```

Periksa isi berkas:

``` bash
cat /home/vncuser/.config/autostart/metatrader5.desktop
```

Keluar dari sesi desktop VNC, kemudian masuk kembali. Jika desktop yang
dipakai membaca autostart XDG, MT5 akan dijalankan saat sesi desktop
dimulai.

**Penting:** ini menjalankan MT5 saat sesi desktop `vncuser` dimulai,
bukan otomatis ketika container baru menyala tanpa sesi desktop. Jika
autostart tidak bekerja, periksa desktop/session manager yang sebenarnya
digunakan.

## 11. Checklist pengujian akhir

-   [ ] Container Debian 12 LXC dapat berjalan di Proxmox.
-   [ ] Desktop VNC/noVNC dapat dibuka.
-   [ ] Pengguna desktop adalah `vncuser`.
-   [ ] `wine --version` menunjukkan Wine 11.0.
-   [ ] `terminal64.exe` ada pada lokasi yang benar.
-   [ ] MT5 terbuka tanpa pesan debugger.
-   [ ] Koneksi ke server broker dapat diuji.
-   [ ] Skrip `/home/vncuser/bin/jalankan-mt5.sh` berjalan.
-   [ ] Berkas `/home/vncuser/.config/autostart/metatrader5.desktop`
    sudah dibuat.
-   [ ] MT4 tidak dihapus atau diubah selama pengujian MT5.

## 12. Perintah ringkas untuk pemeliharaan

Cek versi Wine:

``` bash
wine --version
```

Cek lokasi MT5:

``` bash
find /home/vncuser -type f -iname 'terminal64.exe' 2>/dev/null
```

Jalankan MT5:

``` bash
WINEPREFIX="/home/vncuser/.wine" wine "/home/vncuser/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
```

Cek proses MT5:

``` bash
pgrep -af 'terminal64.exe'
```

Lihat log startup:

``` bash
tail -n 100 /home/vncuser/mt5-autostart.log
```

------------------------------------------------------------------------

## Catatan akhir

Panduan ini merekam konfigurasi yang digunakan dan langkah pengujian
yang berhasil pada sesi ini. Karena detail final pembuatan LXC, alamat
IP, nama CT, desktop/session manager aktif, serta cara menjalankan
layanan noVNC dapat berbeda antarkonfigurasi Proxmox, sesuaikan bagian
tersebut dengan sistem Anda. Pertahankan backup/snapshot sebelum
mengubah Wine sistem, terutama karena MT4 sebelumnya berjalan
menggunakan Wine 8.0.
