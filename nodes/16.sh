#!/bin/bash

# 1. Update dan instal dependensi yang dibutuhkan (Nginx & PHP PDO MySQL)
apt-get update
apt-get install -y nginx php-fpm php-mysql

# 2. Buat direktori root untuk API sesuai konfigurasi Nginx
mkdir -p /var/www/html/api

# 3. Buat file index.php secara otomatis menggunakan heredoc
cat << 'EOF' > /var/www/html/api/index.php
<?php
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

# 4. Atur kepemilikan dan hak akses folder web
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# 5. Restart service Nginx dan PHP-FPM
systemctl restart nginx
systemctl restart php*-fpm

echo "Setup worker selesai dan berhasil!"