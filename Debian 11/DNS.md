# Instalasi dan Konfigurasi DNS Server Menggunakan Bind9

## Rencana Konfigurasi
**IP Address**
IP Address : **192.168.10.200**

**Domain**
DNS : **smkn1abang.com**

**Sub Domain**  
Sub Domain 1 : **www.smkn1abang.com**  
Sub Domain 2 : **ftp.smkn1abang.com**  
Sub Domain 3 : **osis.smkn1abang.com**  
Sub Domain 4 : **sia.smkn1abang.com**  
Sub Domain 5 : **mail.smkn1abang.com**  

## Instalasi 

```console
apt-get install bind9 dnsutils -y
```

## Konfigurasi 

**1. Tambahkan Pada File /etc/bind/named.conf.default-zones**

```console
    zone "smkn1abang.com" {
        type master;
        file "/etc/bind/db.smk";
    };

    zone "10.168.192.in-addr.arpa" {
        type master;
        file "/etc/bind/db.ip";
    }
```

**2. Membuat File Zone**

```console
cp /etc/bind/db.local /etc/bind/db.smk
cp /etc/bind/db.127 /etc/bind/db.ip
```

**3. Konfigurasi DNS pada File /etc/bind/db.smk**



**4. Konfigurasi IP pada File /etc/bind/db.ip**


**5. Restart Service**
```console
    service bind9 restart
```
**6. Tambahkan Nameserver pada File /etc/resolv.conf**
```console
    domain  smkn1abang.com
    search  smkn1abang.com

    nameserver 192.168.10.200
```

**7. Tambahkan Host pada File /etc/hosts**
```console
    192.168.10.200  smkn1abang.com  server
```

**8. Pengujian**
```console
    nslookup

    nslookup>set type=any

    nslookup>smkn1abang.com

    nslookup>www.smkn1abang.com

    nslookup>osis.smkn1abang.com

    nslookup>192.168.10.200 
```


