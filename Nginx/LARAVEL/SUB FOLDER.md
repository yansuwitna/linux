#KONFIGURASI LARAVEL PADA NGINX DENGAN SUB FOLDER UNTUK DEVELOPMENT

**Langkah - Langkah**

*1. Instal Nginx*
*2. Tambahkan*

~~~console 
    location ~ ^/(.*)?/public/ {
		root /var/www/html;
		index index.php index.html index.htm;
		
		try_files $uri $uri/ /$1/public/index.php?$args;
	}
~~~

Artinya : 
Perintah ini adalah konfigurasi Nginx untuk menangani permintaan yang mengarah ke direktori /public/. Berikut penjelasan detailnya:

1. location ~ ^/(.*)?/public/ {  
Menentukan blok konfigurasi location untuk menangani permintaan URL yang cocok dengan pola regex (~ menandakan bahwa ini adalah ekspresi reguler).  
^/(.*)?/public/ berarti mencocokkan semua URL yang mengandung /public/, dengan kemungkinan adanya path di depannya ((.*)? menangkap semua teks sebelum /public/).  
2. root /var/www/html;  
Menentukan direktori root untuk dokumen web. File yang diminta akan dicari di dalam /var/www/html.  
3. index index.php index.html index.htm;  
Menentukan file yang akan digunakan sebagai index jika pengguna mengakses direktori, misalnya:  
Jika pengguna mengakses /folder/public/, Nginx akan mencoba index.php, lalu index.html, lalu index.htm di dalam direktori tersebut.  
4. try_files $uri $uri/ /$1/public/index.php?$args;  
Menentukan bagaimana Nginx menangani file yang diminta:  
$uri → Mencoba mencari file sesuai dengan path yang diminta.  
$uri/ → Jika tidak ditemukan, coba cari sebagai direktori.  
/$1/public/index.php?$args → Jika tidak ada file atau direktori yang cocok, alihkan permintaan ke index.php dalam /public/, sambil meneruskan query string ($args).  

CONTOH : 
URL 10.10.10.10/sh/projek/sma/public akan cocok dengan regex berikut dari konfigurasi:

~~~console
    location ~ ^/(.*)?/public/ {
~~~

(.*)? akan menangkap sh/projek/sma sebagai $1  
Jadi, path yang cocok adalah /sh/projek/sma/public/  

Root direktori yang didefinisikan dalam konfigurasi adalah:

~~~console
root /var/www/html;
~~~ 

Ini berarti semua file akan dicari di dalam /var/www/html.

Namun, karena ada try_files, Nginx akan mencoba beberapa opsi:

Cek apakah file atau folder ada di /var/www/html/sh/projek/sma/public/

Jika ada file atau folder dengan path tersebut, maka akan disajikan.


Jika tidak ditemukan, maka akan dialihkan ke:

~~~console
    /$1/public/index.php?$args;
~~~

$1 adalah sh/projek/sma, sehingga akan menjadi:

~~~console
/sh/projek/sma/public/index.php?$args
~~~

Nginx akan mencari /var/www/html/sh/projek/sma/public/index.php
Jika file index.php ada, maka Nginx akan meneruskannya ke PHP-FPM untuk diproses.
Jika index.php tidak ada, akan terjadi error 404 (Not Found).


**Kesimpulan**
Jika folder /var/www/html/sh/projek/sma/public/ ada dan memiliki file, maka file tersebut akan dilayani.
Jika tidak ada file yang sesuai, maka permintaan akan diteruskan ke /var/www/html/sh/projek/sma/public/index.php.
Jika index.php tidak ada, Nginx akan menampilkan error 404 Not Found.
Jika PHP-FPM tidak dikonfigurasi dengan benar, mungkin terjadi error 502 Bad Gateway.