#!/bin/bash
CONF_FILE="/etc/nginx/sites-available/default"
cp $CONF_FILE ${CONF_FILE}.bak

cat << 'EOF' > $CONF_FILE
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location /api/ {
        proxy_pass http://10.94.4.9/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location / {
        proxy_pass http://10.94.4.9/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

nginx -t && (systemctl reload nginx || service nginx reload)
echo "Setup gojo selesai!"