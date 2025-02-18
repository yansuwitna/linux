# WEBMAIL dengan Postfix, Dovecot Imapd dan Roundcube
***Catatan***  
*Harus Sudah Selesai DNS dan Web Server***

**1. Instalasi Aplikasi**
```console

apt-get install postfix dovecot-imapd mariadb-server roundcube -y

```
*Postfix Configuration*  
Melanjutkan Konfigurasi: **OK**  
Type mail : **Internet Site**  
System mail name : **mail.smkn1abang.com** (*Sesuai dengan Domain*)  

*Konfig Rouncube*   
Config Database : **Yes**  
Password MySQL : **123** (*Sesuai Keinginan*)  
Ulangi Password : **123** (*Harus Sama Dengan Diatas*)  

**Konfigurasi Postfix /etc/postfix/main.cf**  

```console
myhostname = smkn1abang.com

#Tambahkan Ini
home_mailbox = Maildir/
```

**Konfigurasi Dovecot /etc/dovecot/conf.d/10-mail.conf**
```console
mail_location = maildir:~/Maildir
```

**Konfigurasi Rouncube /etc/roundube/config.inc.php**
```console
$config['default_host'] = 'smkn1abang.com';
$config['smtp_server'] = 'smkn1abang.com';
$config['smtp_port'] = '25';
$config['smtp_user'] = '';
$config['smtp_pass'] = '';
```

**Mengaktifkan Virtual Host mail.smkn1abang.com pada apache**
```console
cd /etc/apache2/sites-available

cp 000-default.conf mail.conf

nano mail.conf
```

*Ubah Isinya *

```console
    ServerName mail.smkn1abang.com
    ....
    DocumentRoot /usr/share/roundcube
```

*Mengaktifkan Sites *
```console
    a2ensite mail.conf
```

**Membuat User Baru**
```console
adduser bima
```

**Restart Service Postfix, Dovecot dan Apache2**
```console
service postfix restart
service dovecot restart
service apache2 restart
```

**Penghujian Pengiriman Email**
```console
    Buka Broswer dengan URL : mail.smkn1abang.com
```

**Melihat Port Aktif**
```console
    apt-get install net-tools
    netstat -tulnp
```
