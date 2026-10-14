#!/bin/bash
CONF_FILE="/etc/nginx/sites-available/default"
cp $CONF_FILE ${CONF_FILE}.bak

cat << 'EOF' > $CONF_FILE
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }
}
EOF

nginx -t && (systemctl reload nginx || service nginx reload)
echo "Setup nanami selesai!"