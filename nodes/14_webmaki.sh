#!/bin/bash
echo "=============================================="
echo " Memulai Setup Web Frontend (maki - 10.94.4.4)"
echo "=============================================="

# 1. Atur Network secara Manual untuk Maki
ifconfig eth0 10.94.4.4 netmask 255.255.255.0 up
ip route add default via 10.94.4.1 dev eth0 2>/dev/null
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# 2. Update dan Install Nginx & PHP-FPM
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx php-fpm php-mysql

# 3. Buat Web Frontend
mkdir -p /var/www/html
cat << 'EOF' > /var/www/html/index.php
<!DOCTYPE html>
<html>
<head><title>Jarkom K61 - Maki</title></head>
<body>
    <h1>Halo dari Web Worker: <?php echo gethostname(); ?></h1>
    <p>IP Address: 10.94.4.4</p>
</body>
</html>
EOF

# 4. Konfigurasi Nginx agar mengenali PHP (Versi Bersih/Anti-Error)
cat << 'EOF' > /etc/nginx/sites-available/default
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

# 5. Nyalakan PHP-FPM & Nginx
service php8.4-fpm start
killall nginx 2>/dev/null
nginx

echo "=============================================="
echo " Setup Web Frontend Maki Selesai & Berhasil!"
echo "=============================================="