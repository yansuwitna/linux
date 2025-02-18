# Instalasi dan Konfigurasi DNS Server Menggunakan Bind9

## Rencana Konfigurasi
**IP Address**
IP Address : **192.168.10.200**

**Domain**
DNS : **smkn1abang.com**

**Sub Domain dengan CNAME**  
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
```console
;
; BIND data file for local loopback interface
;
$TTL    604800
@       IN      SOA     smkn1abang.com. root.smkn1abang.com. (
                             20         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      smkn1abang.com.
@       IN      A       192.168.10.200
www     IN      CNAME   smkn1abang.com.
ftp     IN      CNAME   smkn1abang.com.
osis    IN      CNAME   smkn1abang.com.
sia     IN      CNAME   smkn1abang.com.
mail    IN      CNAME   smkn1abang.com.
```


**4. Konfigurasi IP pada File /etc/bind/db.ip**
```console
; BIND reverse data file for local loopback interface
;
$TTL    604800
@       IN      SOA     smkn1abang.com. root.smkn1abang.com. (
                             10         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      smkn1abang.com.
200     IN      PTR     smkn1abang.com.
```

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


**CARA CEPAT MENGUBAH ISI FILE**  
sed -i 's/localhost/smkn1abang.com' db.smk  

***Artinya***
s = String/Text  
localhost = Text yang dicari  
smkn1abang.com = Pengganti  
db.smk = File yang akan diubah  

