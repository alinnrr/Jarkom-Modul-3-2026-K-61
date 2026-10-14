#!/bin/bash
echo "=============================================="
echo " Memulai Setup Internal Load Balancer (geto)"
echo "=============================================="

# 1. Atur Network secara Manual untuk Geto
ifconfig eth0 10.94.4.9 netmask 255.255.255.0 up
ip route add default via 10.94.4.1 dev eth0 2>/dev/null
echo "nameserver 10.94.1.2" > /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# 2. Update dan Install Nginx
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx

# 3. Konfigurasi Nginx sebagai Load Balancer dengan Weighted Round Robin (3:1)
cat << 'EOF' > /etc/nginx/sites-available/default
upstream api_cluster {
    server 10.94.4.6 weight=3; # nanami
    server 10.94.4.7 weight=1; # todo
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        proxy_pass http://api_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# 4. Restart Nginx
killall nginx 2>/dev/null
nginx

echo "=============================================="
echo " Setup Load Balancer Geto Selesai & Berhasil!"
echo "=============================================="