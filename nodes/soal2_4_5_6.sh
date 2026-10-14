#!/bin/bash

echo "=== [TENGEN] CONFIGURING DHCP SERVER (SOAL 2, 4, 5, 6 REVISI) ==="

# 1. Update Jam Sistem & Network Interface
date -s "2026-10-13 00:00:00"
ifconfig eth0 10.94.4.10 netmask 255.255.255.0 up
ip route add default via 10.94.4.1 dev eth0 2>/dev/null
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# 2. Install ISC DHCP Server (jika belum terpasang)
if ! command -v dhcpd &> /dev/null; then
    apt-get update --allow-insecure-repositories 2>/dev/null || apt-get update
    apt-get install -y --allow-unauthenticated isc-dhcp-server
fi

# 3. Set Interface Listener DHCP Server
echo 'INTERFACESv4="eth0"' > /etc/default/isc-dhcp-server

# 4. Konfigurasi /etc/dhcp/dhcpd.conf Lengkap
cat << 'EON' > /etc/dhcp/dhcpd.conf
default-lease-time 600;
max-lease-time 7200;
authoritative;

# --- SOAL 2: SUBNET LOKAL TENGEN (NETWORK 4) ---
subnet 10.94.4.0 netmask 255.255.255.0 {
}

# --- SOAL 4: DUAL POOL NETWORK 2 (DIVISI A) ---
subnet 10.94.2.0 netmask 255.255.255.0 {
    option routers 10.94.2.1;
    option broadcast-address 10.94.2.255;
    option domain-name-servers 10.94.1.2, 10.94.1.3;

    # Pool 1 (Dev): 10.94.2.10 - 10.94.2.35
    pool {
        range 10.94.2.10 10.94.2.35;
        allow unknown-clients;
    }

    # Pool 2 (Support): 10.94.2.70 - 10.94.2.95
    pool {
        range 10.94.2.70 10.94.2.95;
    }
}

# Mapping Fixed IP Divisi A
host itadori {
    hardware ethernet 02:42:3f:d0:37:00;
    fixed-address 10.94.2.10;
}

host fushiguro {
    hardware ethernet 02:42:bd:b8:fe:00;
    fixed-address 10.94.2.11;
}

host zenin {
    hardware ethernet 02:42:a4:60:38:00;
    fixed-address 10.94.2.70;
}

host okkotsu {
    hardware ethernet 02:42:18:7a:9b:00;
    fixed-address 10.94.2.71;
}

# --- SOAL 5 & 6: NETWORK 3 (DIVISI B) ---
subnet 10.94.3.0 netmask 255.255.255.0 {
    option routers 10.94.3.1;
    option broadcast-address 10.94.3.255;
    option domain-name-servers 10.94.1.2, 10.94.1.3;
    option domain-name "jujutsu.com";

    # Pool Short Lease (1800 detik / 30 menit): 10.94.3.10 - 10.94.3.89 (Ino & K                                                                                                             usakabe)
    pool {
        range 10.94.3.10 10.94.3.89;
        default-lease-time 1800;
        max-lease-time 1800;
    }

    # Pool Long Lease (43200 detik / 12 jam): 10.94.3.100 - 10.94.3.199
    pool {
        range 10.94.3.100 10.94.3.199;
        default-lease-time 43200;
        max-lease-time 43200;
    }
}

# Fixed Mapping Long Lease (Miwa) - Soal 5
host miwa {
    hardware ethernet 02:42:08:50:31:00;
    fixed-address 10.94.3.100;
    default-lease-time 43200;
    max-lease-time 43200;
}

# Fixed VIP Lease (Kugisaki) - Soal 6
host kugisaki-vip {
    hardware ethernet 02:42:3b:bb:a5:00;
    fixed-address 10.94.3.99;
}
EON

# 5. Restart Service & Verifikasi
service isc-dhcp-server restart
echo "=== [TENGEN] SETUP COMPLETE ==="
