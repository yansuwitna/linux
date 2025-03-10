#Forward Port di Nginx

~~~console 
server {
    listen 80;
    #server_name example.com;

    #ssl_certificate "/etc/letsencrypt/live/example.com/fullchain.pem";
    #ssl_certificate_key "/etc/letsencrypt/live/example.com/privkey.pem";

    #ssl_protocols TLSv1.2 TLSv1.3;
    #ssl_ciphers HIGH:!aNULL:!MD5;


    location / {
        proxy_pass http://localhost:1000/;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
~~~

Contoh Lain 

~~~console 
server {
    listen 443 ssl;
    server_name example.com.sch.id;

    ssl_certificate "/etc/letsencrypt/live/example.com.sch.id/fullchain.pem";
    ssl_certificate_key "/etc/letsencrypt/live/example.com.sch.id/privkey.pem";
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://10.10.10.11:7252;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
~~~