#!/bin/bash
# 1. Network Setup
ifconfig eth0 10.94.4.2 netmask 255.255.255.0 up
ip route add default via 10.94.4.1 dev eth0 2>/dev/null
echo "nameserver 10.94.1.2" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# 2. Install MariaDB
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y mariadb-server

# 3. Buat folder log mysql & berikan izin (PENTING untuk Master)
mkdir -p /var/log/mysql
chown -R mysql:mysql /var/log/mysql
chmod 755 /var/log/mysql

# 4. Configure Master (my.cnf)
cat << 'EOF' > /etc/mysql/mariadb.conf.d/50-server.cnf
[mysqld]
user            = mysql
pid-file        = /run/mysqld/mysqld.pid
socket          = /run/mysqld/mysqld.sock
port            = 3306
basedir         = /usr
datadir         = /var/lib/mysql
tmpdir          = /tmp
lc-messages-dir = /usr/share/mysql
bind-address    = 0.0.0.0

# Replikasi Master
server-id       = 1
log-bin         = /var/log/mysql/mysql-bin.log
binlog-do-db    = db_shibuya_K61
EOF

service mariadb restart

# 5. Create Database, Table, and Replication User
mysql -u root << 'EOF'
CREATE DATABASE db_shibuya_K61;
USE db_shibuya_K61;
CREATE TABLE request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    log_message VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO request_logs (log_message) VALUES ('Log awal kutukan shibuya kelompok K61');

CREATE USER 'replicator'@'10.94.4.%' IDENTIFIED BY 'password123';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'10.94.4.%';
FLUSH PRIVILEGES;
FLUSH TABLES WITH READ LOCK;
EOF

echo "Setup Master K61 Selesai!"