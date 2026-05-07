Ini digunakan untuk membuat server dengan port dan ssl dengan tambahan caching css dan lainnya

server {
        listen 8102 ssl;

        include snippets/snakeoil.conf;

        root /home/web/www/smkn1abang/lsp/public;

        index index.php;

        server_name lsp-smkn1abang.nanatech.id;

        location / {
                try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        }

        location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
            expires 30d;
            access_log off;
        }
}