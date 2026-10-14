#!/bin/bash
# 1. Buat direktori web root dan file API index.php
mkdir -p /var/www/html/api

cat << 'EOF' > /var/www/html/api/index.php
<?php
$host = '10.94.4.2'; // IP Master yaga
$db   = 'db_shibuya_K61';
$user = 'root';
$pass = '';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$db;charset=utf8", $user, $pass);
    $hostname = gethostname();
    $client_ip = $_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['REMOTE_ADDR'];
    
    $stmt = $pdo->prepare("INSERT INTO request_logs (log_message, client_ip) VALUES (:msg, :cip)");
    $stmt->execute([
        'msg' => "Request diproses oleh API Worker Backup: " . $hostname,
        'cip' => $client_ip
    ]);

    echo json_encode([
        "status" => "success",
        "worker" => $hostname,
        "client_ip" => $client_ip,
        "message" => "Berhasil mencatat log ke database yaga melalui backup!"
    ]);
} catch (\PDOException $e) {
    echo json_encode([
        "status" => "error",
        "message" => "Gagal koneksi DB: " . $e->getMessage()
    ]);
}
?>
EOF

# 2. Konfigurasi Nginx di worker backup kirara
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
echo "Setup worker backup kirara selesai!"