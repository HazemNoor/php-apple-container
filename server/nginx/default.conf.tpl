server {
    listen 80;
    server_name __APP_DOMAIN__;
    root /var/www/html/public;
    index index.php;

    location = /favicon.ico {
        access_log off;
        log_not_found off;
        try_files $uri =404;
    }

    # Chrome probes /.well-known/appspecific/com.chrome.devtools.json when
    # DevTools is open; don't let it (or anything under .well-known) hit PHP.
    location ^~ /.well-known/ {
        access_log off;
        log_not_found off;
        try_files $uri =404;
    }

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass __PHP_IP__:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}

server {
    listen 80;
    server_name __PMA_DOMAIN__;

    location / {
        proxy_pass http://__PMA_IP__;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
    }
}
