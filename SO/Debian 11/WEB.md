# WEB SERVER DENGAN APACHE dan PHP

**1. Instalasi Web Server**
```console
apt-get install apache2 php
```

**Membuat Folder**
```console
mkdir /var/www/html/utama
mkdir /var/www/html/osis
``` 

**Membuat File html Website Utama**
```console
nano /var/www/html/utama/index.php
```

isikan   

```console
Website Utama
```

Kemudian Simpan dengan **ctrl+x** ketik **y** lalu **enter**

**Membuat File html Website Osis**
```console
nano /var/www/html/utama/index.php
```

isikan   

```console
Website Utama
```

Kemudian Simpan dengan **ctrl+x** ketik **y** lalu **enter**

**Mengaktifkan Module SSL**
```console
a2enmod ssl
```

**Membuat Sertifikat**
```console

cd /etc/apache2
mkdir ssl
cd ssl

openssl req -x509 -newkey rsa:2048 -nodes -days 365 -keyout web.key -out web.crt
```

**Membuat Sites**
```console
cd /etc/apache2/sites-available


nano default-ssl.conf

/etc/apache2/ssl/web.key
/etc/apache2/ssl/web.key

cp default-ssl.conf utama.conf
cp default-ssl.conf osis.conf

Konfigurasi Utama 

nano utama.conf

home direktori /var/www/html/utama

Simpan dengan ctrl+x > y > enter

Konfigurasi Osis 

nano osis.conf

home direktori /var/www/html/utama

Simpan dengan ctrl+x > y > enter
```

**Mengkatifkan Sites**
```console
a2ensite utama.conf
a2ensite osis.conf

```

**Merestart Service**
```console
service apache2 restart

```

**Pengujian**
```console
Buka Browser dengan URL : https://smkn1abang.com dan https://osis.smkn1abang.com
```