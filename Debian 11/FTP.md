# Konfigurasi FTP dan FTPS dengan Proftpd

**1. Instalasi FTP**

```console
apt-get install proftpd proftpd-mod-crypto -y
```

**2. Edit file /etc/proftpd/proftpd.conf**

```console
UseIPv6 off
DefaultRoot ~
Include /etc/proftpd/tls.conf

<Anonymous ~ftp>
    User ftp
    Group nogroup
    UserAlias anonymous ftp
    DirFakeUser on ftp
    DirFakeGroup on ftp
    RequireValidShell off
    MaxClients 10
    DisplayLogin welcome.msg
    DisplayChdir .message 
</Anonymous>
```

**3. Edit File /etc/proftpd/modules.conf**

```console
    LoadModule mod_tls.c
```

**4. Edit File /etc/proftpd/tls.conf**

```console
    TLSEngine       on
    TLSLog          /var/log/proftpd/tls.log
    TLSProtocol     SSLv23

    TLSRSACertificateFile       /etc/ssl/certs/proftpd.crt
    TLSRSACertificateKeyFile    /etc/ssl/private/proftpd.key

    TLSRequired     on
```

**5. Buat Sertifikat**

```console
    openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/private/proftpd.key -out /etc/ssl/certs/proftpd.crt -nodes -days 365
```

**6. Restart Service**

```console
    service proftpd restat 
```

**7. Pengujian Menggunakan File Zilla**

Install **Filezilla**  
Klik **File** > **Site Manager**  
Klik New Sites

