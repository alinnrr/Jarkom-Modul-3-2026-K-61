#!/bin/bash

echo "=============================================="
echo " Memulai Setup MariaDB Slave (Inumaki) - K61"
echo "=============================================="

# 1. Update dan Pastikan Paket Terinstal
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y mariadb-server mariadb-client

# 2. Pastikan Service MariaDB Menyala
systemctl stop mariadb
systemctl start mariadb
systemctl enable mariadb

# 3. Konfigurasi Server ID untuk Slave (Server ID = 2)
CONFIG_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"

if [ -f "$CONFIG_FILE" ]; then
    # Pastikan server-id diatur ke 2 untuk slave inumaki
    sed -i 's/^#* *server-id.*/server-id = 2/' "$CONFIG_FILE"
    
    # Pastikan bind-address terbuka untuk koneksi jaringan
    sed -i 's/^#* *bind-address.*/bind-address = 0.0.0.0/' "$CONFIG_FILE"
fi

# Restart MariaDB untuk menerapkan konfigurasi
systemctl restart mariadb

echo "Konfigurasi dasar selesai. Menghubungkan ke Master (yaga)..."

# 4. Eksekusi Konfigurasi Replikasi Master-Slave & Pembuatan Tabel Pengaman
mysql -u root <<EOF
-- Reset konfigurasi slave sebelumnya jika ada
STOP SLAVE;
RESET SLAVE ALL;

-- Hubungkan ke Master yaga (10.94.4.2) menggunakan file & posisi binlog terbaru
CHANGE MASTER TO
    MASTER_HOST='10.94.4.2',
    MASTER_USER='replicator',
    MASTER_PASSWORD='password123',
    MASTER_LOG_FILE='mysql-bin.000002',
    MASTER_LOG_POS=342;

-- Jalankan Slave
START SLAVE;

-- Buat database dan tabel pengaman agar struktur langsung siap
CREATE DATABASE IF NOT EXISTS db_shibuya_K61;
USE db_shibuya_K61;
CREATE TABLE IF NOT EXISTS request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    log_message VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

echo "=============================================="
echo " Setup Slave K61 Selesai & Berhasil Disesuaikan!"
echo "=============================================="