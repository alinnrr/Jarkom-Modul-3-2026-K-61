#!/bin/bash
CONF_FILE="/etc/nginx/sites-available/default"
cp $CONF_FILE ${CONF_FILE}.bak

cat << 'EOF' > $CONF_FILE
upstream api_cluster {
    server 10.94.4.6 max_fails=2 fail_timeout=5s; # nanami (utama)
    server 10.94.4.7 max_fails=2 fail_timeout=5s; # todo (utama)
    server 10.94.4.8 backup;                     # kirara (cadangan/backup)
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

nginx -t && (systemctl reload nginx || service nginx reload)
echo "Setup geto dengan backup kirara berhasil!"