#!/bin/bash
echo "=============================================="
echo " Memulai Setup API Worker (todo - 10.94.4.7)"
echo "=============================================="

# 1. Atur Network secara Manual untuk Todo
ifconfig eth0 10.94.4.7 netmask 255.255.255.0 up
ip route add default via 10.94.4.1 dev eth0 2>/dev/null
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# 2. Update dan Install Nginx & PHP-FPM
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx php-fpm php-mysql

# 3. Buat API Endpoint yang mencatat log ke Master yaga (10.94.4.2)
mkdir -p /var/www/html/api
cat << 'EOF' > /var/www/html/api/index.php
<?php
header('Content-Type: application/json');
$host = '10.94.4.2'; // IP Master yaga
$db   = 'db_shibuya_K61';
$user = 'root';
$pass = '';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$db;charset=utf8", $user, $pass);
    $hostname = gethostname();
    $stmt = $pdo->prepare("INSERT INTO request_logs (log_message) VALUES (:msg)");
    $stmt->execute(['msg' => "Request diproses oleh API Worker: " . $hostname]);

    echo json_encode([
        "status" => "success",
        "worker" => $hostname,
        "message" => "Berhasil mencatat log ke database yaga!"
    ]);
} catch (\PDOException $e) {
    echo json_encode([
        "status" => "error",
        "message" => "Gagal koneksi DB: " . $e->getMessage()
    ]);
}
EOF

# 4. Konfigurasi Nginx agar mengenali PHP (Versi Bersih)
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
echo " Setup API Worker Todo Selesai & Berhasil!"
echo "=============================================="