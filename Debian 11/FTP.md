# Konfigurasi FTP dan FTPS dengan Proftpd

**1. Instalasi FTP**

```console
apt-get install proftpd proftpd-mod-crypto -y
```

**2. Konfig file /etc/proftpd/proftpd.conf**

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