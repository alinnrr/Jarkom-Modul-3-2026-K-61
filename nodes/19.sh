#!/bin/bash

echo "[*] Memulai konfigurasi Proxy Caching & Rate Limiting di Gojo..."

# 1. Tambahkan konfigurasi cache zone dan limit zone di nginx.conf jika belum ada
NGINX_CONF="/etc/nginx/nginx.conf"
cp "$NGINX_CONF" "${NGINX_CONF}.bak"

if ! grep -q "proxy_cache_path" "$NGINX_CONF"; then
    sed -i '/http {/a \    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=10g inactive=60m use_temp_path=off;\n    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;' "$NGINX_CONF"
    echo "[+] Berhasil menambahkan direktif global ke nginx.conf"
fi

# 2. Tulis konfigurasi virtual host ke sites-available/default
CONF_FILE="/etc/nginx/sites-available/default"
cp "$CONF_FILE" "${CONF_FILE}.bak"

cat << 'EOF' > "$CONF_FILE"
upstream frontend_cluster {
    server 10.94.4.4; # maki
    server 10.94.4.5; # panda
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name jujutsu.K61.com www.jujutsu.K61.com;

    # Rate Limiting pada path /api (10 request per detik)
    location /api {
        limit_req zone=api_limit burst=20 nodelay;
        proxy_pass http://10.94.4.9; # geto
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Proxy Caching pada frontend (root /) dengan masa berlaku 10 menit
    location / {
        proxy_cache my_cache;
        proxy_cache_valid 200 302 10m;
        proxy_cache_valid 404 1m;
        add_header X-Cache-Status $upstream_cache_status;

        proxy_pass http://frontend_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

echo "[+] Berhasil memperbarui konfigurasi situs default"

# 3. Buat direktori cache dan atur hak akses web server
mkdir -p /var/cache/nginx
chown -R www-data:www-data /var/cache/nginx

# 4. Uji sintaks Nginx dan muat ulang layanan
if nginx -t; then
    systemctl reload nginx 2>/dev/null || service nginx reload
    echo "[SUCCESS] Setup Proxy Caching dan Rate Limiting di Gojo selesai!"
else
    echo "[ERROR] Konfigurasi Nginx tidak valid. Periksa kembali sintaksnya."
    exit 1
fi