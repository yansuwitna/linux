Khusus Untuk Laravel Dengan Banyak Aplikasi Berupa Folder 
Dengan Keamanan file .env

server {
    listen 443 ssl;
    server_name nanatech.id;

    include snippets/snakeoil.conf;
    root /home/web/www;
    index index.php;

    # BLOK SEMUA AKSES DI LUAR public (GLOBAL & DINAMIS)
#location ~* ^/(?!.*public).*$ {
#    return 404;
#}


    location / {
        try_files $uri $uri/ @app;
    }

    location @app {
        rewrite ^(.*/public)(/.*)?$ $1/index.php?$args last;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
