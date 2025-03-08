#Akses SSH Dari Server Lokal Menggunakan Cloudflare

**1. DNS Sudah ada di Cloudflare**

**2. Membuat Konfigurasi Zero Trust**

Sub Domain : ssh  
Domain : pilih yang ada  misalkan coba.com
type : ssh  
URL : localhost:22

**3. Instalasi Cloudflare di Server Lokal**

```console 
    apt-get install curl

    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb

    dpkg -i cloudflared.deb && 

    cloudflared service install kode_token

    systemctl restart cloudflared

    cloudflared tunnel login   
```

**4. Koneksi Di WIndows**

Download Aplikasi Cloudflare letakkan di C:\cloudflare\cloadflare.exe

Buka CMD/Shell

```console 
    cloudflared access ssh --hostname ssh.coba.com --url ssh://localhost:22
    ssh nama_user@localhost
```