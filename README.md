# JARKOM MODUL 3 2026 - K61

## Member

| Nama               | NRP        |
| ------------------ | ---------- |
| Ferlin Erdina Sari | 5027251002 |
| Achmad Rifqy Aqila | 5027251102 |

## Laporan

1. Ketika Curtain menutup Shibuya, jalur komunikasi antar zona Jujutsu High terputus. Pulihkan konektivitas dasar dengan mengonfigurasi jichi: eth0 memperoleh WAN dari NAT, sedangkan eth1–eth4 menjadi gateway Network 1–4 sesuai tabel pemetaan. Aktifkan IPv4 forwarding dan source NAT, lalu tetapkan IP statis host infrastruktur sesuai tabel spesifikasi. Buktikan konektivitas setiap host ke gateway dan akses eksternal dari host yang relevan.

Untuk memulihkan konektivitas dasar di seluruh zona Jujutsu High, dilakukan pengaturan IP address, gateway, dan routing pada router utama **`jichi`** serta penetapan IP statis pada node infrastruktur utama.

![topologi](assets/Topologi.png)

### Langkah Penyelesaian:

1. **Konfigurasi Interface Router `jichi`**:
   Interface `eth0` dikonfigurasi untuk memperoleh alamat IP dinamis dari NAT WAN (Internet), sedangkan interface `eth1` hingga `eth4` dikonfigurasi sebagai gateway internal untuk masing-masing subnet:
   - **Network 1 / DMZ (`eth1`)**: IP `10.94.1.1/24`
   - **Network 2 / Divisi A (`eth2`)**: IP `10.94.2.1/24`
   - **Network 3 / Divisi B (`eth3`)**: IP `10.94.3.1/24`
   - **Network 4 / Data Center (`eth4`)**: IP `10.94.4.1/24`

2. **Pengaktifan IPv4 Forwarding & Source NAT (MASQUERADE)**:
   Mengaktifkan fitur _packet forwarding_ pada kernel router `jichi` dan menerapkan aturan `iptables` dengan target `MASQUERADE` pada interface `eth0` agar seluruh trafik dari jaringan internal dapat mengakses internet luar.

3. **Penetapan IP Statis Host Infrastruktur**:
   Menetapkan IP statis dan gateway default secara manual pada berkas `/etc/network/interfaces` atau skrip persisten untuk node-node infrastruktur utama:
   - **`utahime` (DNS Master)**: IP `10.94.1.2/24`, Gateway `10.94.1.1`
   - **`shoko` (DNS Slave)**: IP `10.94.1.3/24`, Gateway `10.94.1.1`
   - **`gojo` (DMZ Gateway)**: IP `10.94.1.10/24`, Gateway `10.94.1.1`
   - **`tengen` (DHCP Server)**: IP `10.94.4.10/24`, Gateway `10.94.4.1`

#### Skrip Otomatisasi Router `jichi` (`soal1_3.sh`):

```bash
#!/bin/bash

# 1. Konfigurasi IP eth0 (WAN/NAT) & Interface Internal
ifconfig eth0 192.168.122.100 netmask 255.255.255.0 up
ip route add default via 192.168.122.1 dev eth0 2>/dev/null

ifconfig eth1 10.94.1.1 netmask 255.255.255.0 up
ifconfig eth2 10.94.2.1 netmask 255.255.255.0 up
ifconfig eth3 10.94.3.1 netmask 255.255.255.0 up
ifconfig eth4 10.94.4.1 netmask 255.255.255.0 up

# 2. Set DNS Resolver
echo "nameserver 192.168.122.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# 3. Simpan Konfigurasi Interfaces
cat <<EON > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.122.100
    netmask 255.255.255.0
    gateway 192.168.122.1

auto eth1
iface eth1 inet static
    address 10.94.1.1
    netmask 255.255.255.0

auto eth2
iface eth2 inet static
    address 10.94.2.1
    netmask 255.255.255.0

auto eth3
iface eth3 inet static
    address 10.94.3.1
    netmask 255.255.255.0

auto eth4
iface eth4 inet static
    address 10.94.4.1
    netmask 255.255.255.0
EON

# 4. Routing & NAT MASQUERADE
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# 5. Bypass Signature Validation pada Update & Install DHCP Relay
apt-get update -o Acquire::Check-Valid-Until=false --allow-unauthenticated
apt-get install -y --allow-unauthenticated isc-dhcp-relay

# 6. Konfigurasi FileS /etc/default/isc-dhcp-relay
cat <<EON > /etc/default/isc-dhcp-relay
SERVERS="10.94.4.10"
INTERFACES="eth2 eth3 eth4"
OPTIONS=""
EON

# Restart Service Relay
/etc/init.d/isc-dhcp-relay restart 2>/dev/null || service isc-dhcp-relay restart

```

![soal1](assets/soal%201.png)

#### Pengujian

```bash
# Ping dari utahime ke Gateway
ping -c 2 10.94.1.1

# Ping dari utahime ke Internet
ping -c 2 8.8.8.8
```

---

2. Tengen, penjaga pusat distribusi di Data Center, harus mengambil alih pengalokasian alamat bagi wilayah yang membutuhkan konfigurasi dinamis. Konfigurasikan isc-dhcp-server pada 10.94.4.10. Deklarasikan Network 4 (10.94.4.0/24) sebagai subnet lokal tanpa pool dinamis, lalu siapkan scope DHCP untuk Network 2 (10.94.2.0/24) dan Network 3 (10.94.3.0/24). Validasi konfigurasi dan pastikan service aktif tanpa error “No subnet declaration”.

Untuk mengonfigurasi **`tengen`** (`10.94.4.10`) sebagai pusat server DHCP terpusat, dilakukan pemasangan paket `isc-dhcp-server` dan deklarasi subnet jaringan internal pada berkas konfigurasi `/etc/dhcp/dhcpd.conf`.

### Langkah Penyelesaian:

1. **Deklarasi Subnet Lokal Network 4 (`10.94.4.0/24`)**:
   Agar daemon DHCP tidak menghasilkan kesalahan (_error_) _"No subnet declaration for eth0"_, subnet lokal tempat server `tengen` berada (`10.94.4.0/24`) wajib dideklarasikan di dalam berkas konfigurasi tanpa menyertakan `range` IP dinamis.

2. **Deklarasi Scope DHCP Network 2 (`10.94.2.0/24`) dan Network 3 (`10.94.3.0/24`)**:
   Menyiapkan blok konfigurasi subnet untuk jaringan lokal yang nantinya akan dilayani melalui mekanisme DHCP Relay (`jichi`).

3. **Penetapan Interface Server**:
   Mengarahkan listening interface DHCP pada berkas `/etc/default/isc-dhcp-server` ke `eth0`.

#### Konfigurasi Berkas `/etc/dhcp/dhcpd.conf` pada Node `tengen`:

```dhcpd
# Global Options
default-lease-time 600;
max-lease-time 7200;
authoritative;

# 1. Subnet Lokal Server Tengen (Tanpa Pool Dinamis)
subnet 10.94.4.0 netmask 255.255.255.0 {
    option routers 10.94.4.1;
    option domain-name-servers 10.94.1.2;
}

# 2. Subnet Network 2 (Divisi A)
subnet 10.94.2.0 netmask 255.255.255.0 {
    option routers 10.94.2.1;
    option domain-name-servers 10.94.1.2;
}

# 3. Subnet Network 3 (Divisi B)
subnet 10.94.3.0 netmask 255.255.255.0 {
    option routers 10.94.3.1;
    option domain-name-servers 10.94.1.2;
}
```

#### Skrip Otomatisasi DHCP Server tengen (soal2_4_5_6.sh):

```Bash
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

```

### Pengujian

```
ps aux | grep dhcpd
```

![soal2](assets/soal%202.png)

---

3. Permintaan alamat dari Divisi A dan Divisi B tidak dapat menyeberangi subnet secara langsung. Konfigurasikan jichi sebagai DHCP Relay menuju tengen (10.94.4.10), menggunakan eth2 untuk Network 2 dan eth3 untuk Network 3. Buktikan bahwa client dari kedua subnet berhasil memperoleh lease melalui relay.

Karena paket _broadcast_ DHCP (DORA) secara _default_ dihentikan oleh router dan tidak dapat menyeberangi antar-subnet secara langsung, maka router **`jichi`** dikonfigurasi sebagai **DHCP Relay Agent** (`isc-dhcp-relay`) untuk meneruskan permintaan lease dari Network 2 (`eth2`) dan Network 3 (`eth3`) menuju DHCP Server `tengen` (`10.94.4.10`) di Network 4 (`eth4`).

### Langkah Penyelesaian:

1. **Instalasi & Pengaturan DHCP Relay pada Node `jichi`**:
   Memasang paket `isc-dhcp-relay` pada node router `jichi`.
2. **Penetapan Interface & Server Tujuan**:
   Mengatur berkas `/etc/default/isc-dhcp-relay` untuk mendengarkan antarmuka `eth2` (Network 2), `eth3` (Network 3), dan `eth4` (Network 4), serta mengarahkan alamat server DHCP tujuan (_SERVERS_) ke IP `10.94.4.10`.
3. **Menjalankan Daemon `dhcrelay`**:
   Menjalankan layanan relay dengan opsi `-i eth2 -i eth3 -i eth4 10.94.4.10` agar request broadcast dari Network 2 dan Network 3 dikonversi menjadi _unicast_ menuju server `tengen`.

#### Konfigurasi Berkas `/etc/default/isc-dhcp-relay` pada Node `jichi`:

```bash
SERVERS="10.94.4.10"
INTERFACES="eth2 eth3 eth4"
OPTIONS=""
```

#### Skrip Otomatisasi DHCP Relay jichi (soal1_3.sh):

```Bash
#!/bin/bash

# 1. Konfigurasi IP eth0 (WAN/NAT) & Interface Internal
ifconfig eth0 192.168.122.100 netmask 255.255.255.0 up
ip route add default via 192.168.122.1 dev eth0 2>/dev/null

ifconfig eth1 10.94.1.1 netmask 255.255.255.0 up
ifconfig eth2 10.94.2.1 netmask 255.255.255.0 up
ifconfig eth3 10.94.3.1 netmask 255.255.255.0 up
ifconfig eth4 10.94.4.1 netmask 255.255.255.0 up

# 2. Set DNS Resolver
echo "nameserver 192.168.122.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# 3. Simpan Konfigurasi Interfaces
cat <<EON > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.122.100
    netmask 255.255.255.0
    gateway 192.168.122.1

auto eth1
iface eth1 inet static
    address 10.94.1.1
    netmask 255.255.255.0

auto eth2
iface eth2 inet static
    address 10.94.2.1
    netmask 255.255.255.0

auto eth3
iface eth3 inet static
    address 10.94.3.1
    netmask 255.255.255.0

auto eth4
iface eth4 inet static
    address 10.94.4.1
    netmask 255.255.255.0
EON

# 4. Routing & NAT MASQUERADE
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# 5. Bypass Signature Validation pada Update & Install DHCP Relay
apt-get update -o Acquire::Check-Valid-Until=false --allow-unauthenticated
apt-get install -y --allow-unauthenticated isc-dhcp-relay

# 6. Konfigurasi FileS /etc/default/isc-dhcp-relay
cat <<EON > /etc/default/isc-dhcp-relay
SERVERS="10.94.4.10"
INTERFACES="eth2 eth3 eth4"
OPTIONS=""
EON

# Restart Service Relay
/etc/init.d/isc-dhcp-relay restart 2>/dev/null || service isc-dhcp-relay restart

```

### Pengujian

1. Verifikasi Status Daemon DHCP Relay (dhcrelay) di jichi:

```
ps aux | grep dhcrelay
```

![soal3](assets/soal%203.png)

2. Verifikasi Client Menerima Lease IP via Relay (pada ino) :

```
udhcpc -i eth0
```

![soal3](assets/soal3_1.png)

---
