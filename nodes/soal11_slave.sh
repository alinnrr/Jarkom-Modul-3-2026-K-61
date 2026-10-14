#!/bin/bash

echo "=== [SHOKO] MENYIAPKAN NETWORK & BIND9 SLAVE ==="

# 1. Konfigurasi Network & DNS Resolv
ifconfig eth0 10.94.1.3 netmask 255.255.255.0 up
ip route add default via 10.94.1.1 dev eth0 2>/dev/null
echo "nameserver 192.168.122.1" > /etc/resolv.conf

# 2. Cek & Install BIND9 jika belum terpasang
if ! command -v named &> /dev/null; then
    echo "[!] BIND9 belum terinstall. Mengunduh & meng-install paket..."
    apt-get update && apt-get install -y bind9 bind9utils bind9-doc
fi

# 3. Pastikan Direktori BIND9 & Cache Ada
mkdir -p /etc/bind
mkdir -p /var/lib/bind

# 4. Konfigurasi Options
cat << 'EON' > /etc/bind/named.conf.options
options {
        directory "/var/cache/bind";
        listen-on { any; };
        listen-on-v6 { any; };
        allow-query { any; };
        auth-nxdomain no;
};
EON

# 5. Deklarasi Zona Slave jujutsu.com
cat << 'EON' > /etc/bind/named.conf.local
zone "jujutsu.com" {
    type slave;
    masters { 10.94.1.2; };
    file "/var/lib/bind/jujutsu.com";
};
EON

# 6. Atur Permission & Jalankan Service
chown -R bind:bind /var/lib/bind /etc/bind
chmod -R 775 /var/lib/bind /etc/bind

pkill named 2>/dev/null
named -u bind

echo "=== [SHOKO] KONFIGURASI SOAL 11 SLAVE SELESAI ==="
