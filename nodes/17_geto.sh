#!/bin/bash
CONF_FILE="/etc/nginx/sites-available/default"
cp $CONF_FILE ${CONF_FILE}.bak

cat << 'EOF' > $CONF_FILE
upstream api_cluster {
    server 10.94.4.6 weight=3; # nanami
    server 10.94.4.7 weight=1; # todo
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location /api {
        proxy_pass http://api_cluster/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location / {
        proxy_pass http://api_cluster/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Konfigurasi Real IP global di nginx.conf
NGINX_CONF="/etc/nginx/nginx.conf"
sed -i '/set_real_ip_from/d' $NGINX_CONF
sed -i '/real_ip_header/d' $NGINX_CONF
sed -i '/real_ip_recursive/d' $NGINX_CONF
sed -i '/http {/a \    set_real_ip_from 10.94.1.10;\n    real_ip_header X-Forwarded-For;\n    real_ip_recursive on;' $NGINX_CONF

nginx -t && (systemctl reload nginx || service nginx reload)
echo "Setup geto selesai!"