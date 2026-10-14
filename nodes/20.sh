#!/bin/bash

echo "[*] Memperbarui konfigurasi DHCP interface eth0..."
udhcpc -i eth0

echo "[*] Mengatur DNS sementara untuk koneksi..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf

echo "[*] Memeriksa dan menginstal Apache Benchmark (ab)..."
if ! command -v ab &> /dev/null; then
    apk update && apk add apache2-utils
fi

TARGET_IP="10.94.1.10" # IP Gateway Gojo
DOMAIN="jujutsu.K61.com"

echo "=========================================="
echo "1. Menjalankan Benchmark pada Frontend ( / )"
echo "=========================================="
ab -n 600 -c 30 -H "Host: $DOMAIN" http://$TARGET_IP/ > result_root.txt
cat result_root.txt | grep -E "Requests per second|Time per request|Failed requests"

echo ""
echo "=========================================="
echo "2. Menjalankan Benchmark pada API ( /api ) - Uji Rate Limiting"
echo "=========================================="
ab -n 600 -c 30 -H "Host: $DOMAIN" http://$TARGET_IP/api/ > result_api.txt
cat result_api.txt | grep -E "Requests per second|Time per request|Failed requests|Non-2xx"

echo ""
echo "[SUCCESS] Pengujian benchmark selesai! Hasil disimpan di result_root.txt dan result_api.txt"