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

4. Agar tim Dev dan Support di Divisi A menerima jatah alamat yang berbeda, atur dua pool DHCP pada Network 2. Tetapkan Pool 1 (10.94.2.10–10.94.2.35) untuk itadori dan fushiguro, serta Pool 2 (10.94.2.70–10.94.2.95) untuk zenin dan okkotsu. Rentang 10.94.2.36–10.94.2.69 tidak boleh dialokasikan. Karena seluruh client berada pada subnet yang sama, gunakan DHCP class berdasarkan MAC Address atau Client ID untuk memisahkan kedua kelompok.

Untuk memisahkan alokasi alamat IP antara tim Dev (`itadori`, `fushiguro`) dan tim Support (`zenin`, `okkotsu`) dalam satu subnet Network 2 (`10.94.2.0/24`), dikonfigurasikan mekanisme **DHCP Classing** berdasarkan pencocokan awalan MAC Address (_Hardware Address Substring_) pada server `tengen` (`10.94.4.10`).

### Langkah Penyelesaian:

1. **Deklarasi DHCP Class (`class`)**:
   Membuat dua kelas DHCP pada berkas `/etc/dhcp/dhcpd.conf`:
   - **`Pool1-Dev`**: Memfilter client dari kelompok Dev berdasarkan pola MAC Address (`00:50:56` atau `02:42:ac`).
   - **`Pool2-Support`**: Memfilter client dari kelompok Support berdasarkan pola MAC Address (`08:00:27` atau `52:54:00`).

2. **Pengaturan Dual Pool & Proteksi Rentang IP**:
   - **Pool 1 (Dev)**: Menyiapkan rentang IP `10.94.2.10` hingga `10.94.2.35` dan hanya mengizinkan anggota kelas `Pool1-Dev` (`allow members of "Pool1-Dev"`).
   - **Pool 2 (Support)**: Menyiapkan rentang IP `10.94.2.70` hingga `10.94.2.95` dan hanya mengizinkan anggota kelas `Pool2-Support` (`allow members of "Pool2-Support"`).
   - **Rentang `10.94.2.36–10.94.2.69`**: Dibiarkan kosong tanpa deklarasi `range` sehingga otomatis terlindungi dan tidak akan pernah dialokasikan ke client mana pun.

3. **Pemetaan IP Tetap (_Fixed IP Address_)**:
   Menetapkannya secara spesifik menggunakan blok `host` berdasarkan alamat fisik (_MAC Address_) unik dari masing-masing node agar mendapatkan IP sesuai alokasi tugasnya:
   - `itadori`: `10.94.2.10` (MAC `02:42:3f:d0:37:00`)
   - `fushiguro`: `10.94.2.11` (MAC `02:42:bd:b8:fe:00`)
   - `zenin`: `10.94.2.70` (MAC `02:42:a4:60:38:00`)
   - `okkotsu`: `10.94.2.71` (MAC `02:42:18:7a:9b:00`)

#### Konfigurasi Berkas `/etc/dhcp/dhcpd.conf` pada Node `tengen`:

```dhcpd
# --- SOAL 4: CLASS & DUAL POOL NETWORK 2 ---
class "Pool1-Dev" {
    match if substring(hardware, 1, 6) = 00:50:56 or substring(hardware, 1, 6) = 02:42:ac;
}

class "Pool2-Support" {
    match if substring(hardware, 1, 6) = 08:00:27 or substring(hardware, 1, 6) = 52:54:00;
}

subnet 10.94.2.0 netmask 255.255.255.0 {
    option routers 10.94.2.1;
    option broadcast-address 10.94.2.255;
    option domain-name-servers 10.94.1.2, 10.94.1.3;
    option domain-name "jujutsu.com";

    # Pool 1 (Dev): 10.94.2.10 - 10.94.2.35
    pool {
        allow members of "Pool1-Dev";
        range 10.94.2.10 10.94.2.35;
    }

    # Pool 2 (Support): 10.94.2.70 - 10.94.2.95
    pool {
        allow members of "Pool2-Support";
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
```

### Pengujian

1. Verifikasi Konfigurasi Class & Dual Pool di Server tengen:

```
grep -A 20 "subnet 10.94.2.0" /etc/dhcp/dhcpd.conf
```

![soal4](assets/soal4_7.png)

2. Verifikasi Lease IP Tim Dev (Pool 1):

```
udhcpc -i eth0 (pada client fushiguro)
```

![4](assets/soal4_1.png)

3. Verifikasi Lease IP Tim Support (Pool 2):

```
udhcpc -i eth0 (pada client zenin dan okkotsu)
```

![4](assets/soal4_2.png)
![4](assets/soal4_3.png)

---

5. Setiap tim lapangan memiliki durasi operasi yang berbeda. Pada Network 3, berikan short lease 30 menit (1800 detik) kepada ino dan kusakabe, serta long lease 12 jam (43200 detik) kepada miwa. Gunakan pool short lease 10.94.3.10–10.94.3.89 dan pool long lease 10.94.3.100–10.94.3.199. Sesuaikan default-lease-time dan max-lease-time untuk setiap kelas client. Berikan pula DHCP options berupa DNS 10.94.1.2 dan 10.94.1.3, serta domain-search jujutsu.com.

Untuk mengakomodasi perbedaan durasi operasi tim lapangan pada Network 3 (`10.94.3.0/24`), dikonfigurasikan dua _pool_ DHCP dengan durasi penyewaan (_lease time_) berbeda pada server `tengen` (`10.94.4.10`). Selain itu, dikonfigurasikan opsi global DNS server dan _domain search_ untuk seluruh _client_ di Network 3.

### Langkah Penyelesaian:

1. **Pengaturan Opsi DHCP Network 3**:
   Menambahkan `option domain-name-servers 10.94.1.2, 10.94.1.3;` dan `option domain-name "jujutsu.com";` pada deklarasi subnet `10.94.3.0/24`.

2. **Pembagian Pool & Waktu Penyewaan (Lease Time)**:
   - **Pool Short Lease (Ino & Kusakabe)**: Menyiapkan rentang IP `10.94.3.10` hingga `10.94.3.89` dengan `default-lease-time 1800;` dan `max-lease-time 1800;` (30 menit).
   - **Pool Long Lease (Miwa)**: Menyiapkan rentang IP `10.94.3.100` hingga `10.94.3.199` dengan `default-lease-time 43200;` dan `max-lease-time 43200;` (12 jam).

3. **Pemetaan IP Tetap Long Lease (`miwa`)**:
   Menentukan pemetaan _fixed address_ IP `10.94.3.100` khusus untuk node `miwa` berdasarkan MAC address (`02:42:08:50:31:00`) dengan durasi _lease_ 43200 detik.

#### Konfigurasi Berkas `/etc/dhcp/dhcpd.conf` pada Node `tengen`:

```dhcpd
# --- SOAL 5: NETWORK 3 (DIVISI B) ---
subnet 10.94.3.0 netmask 255.255.255.0 {
    option routers 10.94.3.1;
    option broadcast-address 10.94.3.255;
    option domain-name-servers 10.94.1.2, 10.94.1.3;
    option domain-name "jujutsu.com";

    # Pool Short Lease (1800 detik / 30 menit): 10.94.3.10 - 10.94.3.89 (Ino & Kusakabe)
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
```

### Pengujian

1. Verifikasi Short Lease pada Client ino:

```
udhcpc -i eth0 (pada client ino)
```

![soal5](assets/soal5_1.png)
![soal5](assets/soal5_2.png)

2. Verifikasi Long Lease pada Client miwa:

```
udhcpc -i eth0 (pada client miwa)
```

![5](assets/soal5_3.png)

3. Verifikasi DHCP Options (DNS & Domain Search) pada Client miwa:

```
cat /etc/resolv.conf
```

![5](assets/soal5_4.png)

4. Verifikasi Konfigurasi Subnet & Pool Network 3 di Server tengen:

```
grep -A 25 "subnet 10.94.3.0" /etc/dhcp/dhcpd.conf
```

![soal5](assets/soal5_5.png)

---

6. Kugisaki ditetapkan sebagai personel VIP yang harus mempertahankan alamat yang sama setiap kali terhubung. Buat DHCP static lease berdasarkan MAC Address client tersebut dengan fixed address 10.94.3.99. Pastikan alamat ini berada di luar seluruh pool dinamis, validasi konfigurasi server, lalu renew lease pada client. Buktikan bahwa alamat yang diterima sesuai dengan reservasi.

Untuk memastikan personel VIP `kugisaki` selalu mendapatkan alamat IP yang sama setiap kali terhubung ke jaringan tanpa mengganggu alokasi dinamis, dikonfigurasikan pemetaan IP statis (_DHCP Static Lease_) pada server `tengen` (`10.94.4.10`). Alamat IP reservasi yang ditetapkan adalah `10.94.3.99`, yang posisinya berada di luar seluruh _range pool_ dinamis Network 3 (`10.94.3.10–10.94.3.89` dan `10.94.3.100–10.94.3.199`).

### Langkah Penyelesaian:

1. **Konfigurasi Reservasi VIP di Server `tengen`**:
   Menambahkan blok deklarasi `host kugisaki-vip` pada berkas `/etc/dhcp/dhcpd.conf` dengan mencocokkan alamat fisik (_MAC Address_) dari interface `eth0` milik `kugisaki` (`02:42:3b:bb:a5:00`) dan mengarahkan _fixed-address_ ke `10.94.3.99`.

2. **Memuat Ulang Layanan DHCP Server**:
   Melakukan validasi dan _restart_ layanan `isc-dhcp-server` pada `tengen` agar entri pemetaan IP statis VIP aktif.

3. **Pemberharuan Lease (_Renew Lease_) pada Client**:
   Mengeksekusi pembaharuan alokasi IP dinamis pada node `kugisaki` menggunakan utilitas DHCP client (`udhcpc`).

#### Konfigurasi Berkas `/etc/dhcp/dhcpd.conf` pada Node `tengen`:

```dhcpd
# Fixed VIP Lease (Kugisaki) - Soal 6
host kugisaki-vip {
    hardware ethernet 02:42:3b:bb:a5:00;
    fixed-address 10.94.3.99;
}
```

### Pengujian

1. Verifikasi Renew Lease pada Client kugisaki:

```
udhcpc -i eth0 (pada terminal kugisaki)
```

![6](assets/soal%206.png)

2. Verifikasi Konfigurasi Static Lease di Server tengen:

```
tail -n 10 /etc/dhcp/dhcpd.conf
```

![6](assets/soal6_1.png)

3. Verifikasi Alamat Interface pada Client kugisaki:

```
ifconfig eth0 (pada kugisaki)
```

![6](assets/soal6_2.png)

---

7. Setelah aturan alokasi diterapkan, pastikan setiap client menerima konfigurasi jaringan sesuai wilayahnya: subnet mask 255.255.255.0 (/24), gateway dan broadcast address yang benar, DNS 10.94.1.2 serta 10.94.1.3, dan domain-search yang ditentukan. Periksa IP address dan routing seluruh client Divisi A dan Divisi B, kemudian cocokkan lease dengan /var/lib/dhcp/dhcpd.leases pada tengen. Pastikan tidak ada alamat yang bertabrakan atau berada di luar kebijakan pool.

Untuk menjamin seluruh aturan alokasi alamat dan opsi jaringan terdistribusi secara tepat di setiap wilayah, dilakukan pencocokan antara catatan berkas _lease_ aktif di server `tengen` (`10.94.4.10`) dengan konfigurasi IP address, subnet mask, default gateway, serta tabel routing pada _client_ Divisi A dan Divisi B.

### Langkah Penyelesaian:

1. **Pemeriksaan Catatan Lease di Server `tengen`**:
   Membuka dan memeriksa isi berkas `/var/lib/dhcp/dhcpd.leases` pada `tengen` untuk memvalidasi daftar penyewaan IP aktif, alamat fisik (_hardware ethernet/MAC address_), serta batas waktu awal (_starts_) dan akhir (_ends_) sewa IP.

2. **Verifikasi Alamat Interface & Subnet Mask pada Client**:
   Mengeksekusi perintah `ifconfig eth0` pada _client_ (misalnya `ino`) untuk mengonfirmasi bahwa alokasi IP berada di dalam _pool_ yang sah (`10.94.3.10`) dengan _subnet mask_ `/24` (`255.255.255.0`).

3. **Verifikasi Default Gateway & Routing Table pada Client**:
   Mengeksekusi perintah `route -n` pada _client_ untuk menguji apakah jalur _default gateway_ merujuk ke interface router wilayah yang tepat (`10.94.3.1` untuk Network 3).

### Pengujian

1. **Verifikasi Berkas Database Lease (`dhcpd.leases`) di Server `tengen`**:
   Pengecekan berkas `/var/lib/dhcp/dhcpd.leases` mengonfirmasi pencatatan aktivitas sewa IP untuk seluruh MAC Address client (seperti `10.94.3.10` untuk MAC `02:42:90:d3:2b:00` milik `ino`), di mana status menunjukkan `binding state active` tanpa adanya alokasi IP yang bentrok atau keluar dari kebijakan

   ![Pemeriksaan Berkas Lease Database Tengen](assets/soal7_1.png)

2. **Verifikasi Konfigurasi Interface Active pada Client (`ino`)**:
   Pengujian perintah `ifconfig eth0` pada terminal `ino` membuktikan interface memperoleh alamat IP `10.94.3.10` dengan _netmask_ `255.255.255.0` dan _MAC address_ `02:42:90:d3:2b:00` yang cocok presisi dengan catatan _lease_ di server `tengen`.

   ![Pemeriksaan Interface Config Client Ino](assets/soal7_2.png)

3. **Verifikasi Tabel Routing & Gateway pada Client (`ino`)**:
   Pengujian perintah `route -n` pada `ino` membuktikan entri _default gateway_ (`0.0.0.0`) secara otomatis mengarah ke `10.94.3.1` melalui antarmuka `eth0`

   ![Pemeriksaan Routing Table Client Ino](assets/soal7_3.png)

---

8. Sebelum Curtain dibuka kembali, buktikan bahwa proses pemberian alamat berjalan sesuai protokol. Lakukan packet capture saat salah satu client Network 2 atau Network 3 meminta lease baru. Gunakan tcpdump pada tengen atau jalur menuju Data Center untuk menunjukkan urutan DHCPDISCOVER → DHCPOFFER → DHCPREQUEST → DHCPACK. Identifikasi alamat server, alamat yang diberikan, lease time, dan field giaddr. Pastikan nilai giaddr sesuai dengan interface jichi yang menerima request dari subnet client.

Untuk membuktikan alokasi IP via DHCP Relay berjalan sesuai standar protokol BOOTP/DHCP (DORA _Four-Way Handshake_), dilakukan _packet capture_ lalu lintas data pada antarmuka `eth0` milik DHCP Server `tengen` (`10.94.4.10`) saat _client_ `ino` meminta alokasi _lease_ baru.

### Langkah Penyelesaian:

1. **Jalankan Packet Capture pada Server `tengen`**:
   Mengeksekusi utilitas `tcpdump` pada antarmuka `eth0` di `tengen` dengan memfilter port DHCP UDP 67/68 serta mode _verbose_:
   ```bash
   tcpdump -i eth0 -vvv -n "udp port 67 or udp port 68"
   ```
2. Pemicuan Lease Baru pada Client (ino):
   Mengeksekusi pembaruan alokasi IP dinamis secara paksa pada client ino di Network 3 dengan perintah:

```Bash
udhcpc -R -i eth0
```

3. Identifikasi Field Utama Paket DHCP (DORA):Menganalisis hasil tangkapan paket (packet capture) untuk mencocokkan nilai parameter utama:

- **DHCPDISCOVER:** Diterima dari DHCP Relay 10.94.4.1:67 dengan alamat Gateway-IP (giaddr) 10.94.3.1 (IP interface eth3 jichi yang terhubung ke Network 3).
- **DHCPOFFER:** Dikirim oleh DHCP Server 10.94.4.10 yang menawarkan Your-IP 10.94.3.10, Server-ID 10.94.4.10, dan Lease-Time 1800 detik (30 menit).
- **DHCPREQUEST:** Ditransmisikan kembali oleh relay membawa alamat IP tawaran Requested-IP 10.94.3.10.
- **DHCPACK:** Konfirmasi final dari server 10.94.4.10 yang menyetujui penyewaan IP 10.94.3.10 untuk MAC 02:42:90:d3:2b:00

### Pengujian

1. Verifikasi Merekam Transaksi Protokol DHCP (DORA) di Server tengen :

```
tcpdump -i eth0 -vvv -n "udp port 67 or udp port 68"
```

![8](assets/soal8_1.png)

2. Verifikasi Proses Request Lease pada Client ino:

```
udhcpc -R -i eth0 (pada client ino)
```

![8](assets/soal8_2.png)

---

9. Sebuah gangguan memutus jalur relay dan membuat permintaan alamat tidak sampai ke Data Center. Hentikan service DHCP Relay pada jichi, lalu paksa salah satu client di Network 2 atau Network 3 meminta lease baru dan catat gejalanya. Pulihkan service relay, ulangi permintaan DHCP, lalu buktikan bahwa client kembali memperoleh alamat dari pool yang benar dengan gateway semula.

Untuk mensimulasikan dan menganalisis skenario kegagalan jaringan saat layanan DHCP Relay mati, dilakukan penghentian paksa daemon `dhcrelay` pada router **`jichi`**, disusul pengujian pemulihan layanan kembali hingga _client_ dapat terhubung secara normal.

### Langkah Penyelesaian:

1. **Simulasi Gangguan (Penghentian DHCP Relay)**:
   Mengeksekusi perintah `pkill dhcrelay` pada router `jichi` untuk menghentikan proses perantara DHCP Relay.

2. **Pengujian Gejala Kegagalan pada Client (`ino`)**:
   Mengeksekusi pembaruan alokasi IP dinamis pada _client_ `ino` (Network 3) dengan perintah `udhcpc -i eth0`. Karena jalur perantara terputus, paket _broadcast_ `DHCPDISCOVER` gagal mencapai Data Center dan menghasilkan pesan _error_: `udhcpc: failed to get a DHCP lease`.

3. **Pemulihan Layanan DHCP Relay pada `jichi`**:
   Menjalankan kembali skrip konfigurasi `soal1_3.sh` pada router `jichi` untuk mengaktifkan ulang daemon `isc-dhcp-relay`.

4. **Pengujian Pemulihan Konektivitas Client**:
   Mengeksekusi ulang perintah `udhcpc -i eth0` pada `ino` untuk membuktikan _client_ kembali mendapatkan alokasi IP dari _pool_ yang sah.

---

### Pengujian

1. **Penghentian Daemon DHCP Relay pada Router `jichi`**:
   Eksekusi perintah `pkill dhcrelay` berhasil mematikan daemon perantara di `jichi`.

   ![Pkill DHCP Relay Jichi](assets/soal9_1.png)

2. **Gejala Kegagalan Lease IP pada Client `ino`**:
   Saat mengeksekusi `udhcpc -i eth0`, _client_ `ino` terus-menerus mengirimkan `broadcasting discover` tanpa balasan hingga akhirnya gagal mendapatkan alokasi IP (`udhcpc: failed to get a DHCP lease`).

   ![Gejala Gagal Lease Ino](assets/soal9_2.png)

3. **Pemulihan Service Relay pada Router `jichi`**:
   Mengeksekusi kembali skrip `soal1_3.sh` pada `jichi` untuk mengaktifkan ulang layanan `isc-dhcp-relay`.

   ![Pemulihan Relay Jichi](assets/soal9_3.png)

4. **Verifikasi Client Berhasil Memperoleh IP Kembali**:
   Pengujian ulang perintah `udhcpc -i eth0` pada _client_ `ino` membuktikan _client_ berhasil memperoleh kembali alamat IP `10.94.3.10` dari server `10.94.4.10` dengan _lease time_ 1800 detik

   ![Verifikasi Lease Normal Ino](assets/soal9_4.png)

---

10. Setelah gangguan Shibuya tertangani, pastikan pemulihan bertahan setelah restart. Aktifkan autostart DHCP Server pada tengen dan DHCP Relay pada jichi, lalu restart kedua node. Verifikasi status layanan, IP, gateway, lease, dan konektivitas client Network 2–3. Pastikan kebijakan Pool 1, Pool 2, short lease, long lease, dan fixed address tetap berlaku.

Untuk menjamin seluruh layanan distribusi IP dan perantara jaringan bersifat persisten serta dapat langsung beroperasi otomatis saat sistem mengalami booting ulang (_restart_), dilakukan aktivasi _autostart_ pada DHCP Server **`tengen`** (`10.94.4.10`) dan DHCP Relay **`jichi`**, dilanjutkan dengan pengujian validasi pasca-_restart_.

### Langkah Penyelesaian:

1. **Aktivasi Autostart DHCP Server di `tengen`**:
   Mengeksekusi perintah `update-rc.d isc-dhcp-server enable` pada node `tengen` untuk mendaftarkan layanan DHCP Server ke dalam skrip _init startup_ sistem.

2. **Aktivasi Autostart DHCP Relay di `jichi`**:
   Mengeksekusi perintah `update-rc.d isc-dhcp-relay enable` pada router `jichi` untuk memastikan daemon `dhcrelay` berjalan otomatis saat proses _booting_.

3. **Simulasi Restart & Pengujian Pasca-Booting**:
   Melakukan _restart_ pada kedua node (`tengen` dan `jichi`), kemudian memverifikasi status layanan `service status` serta ketersediaan proses daemon aktif (`dhcpd` dan `dhcrelay`).

4. **Verifikasi Kebijakan Lease pada Client**:
   Mengeksekusi perintah `udhcpc -i eth0` pada _client_ (seperti `ino` di Network 3) untuk membuktikan bahwa seluruh kebijakan distribusi IP (_Pool 1_, _Pool 2_, _short lease_, _long lease_, dan _fixed address_) tetap berjalan normal tanpa kendala.

### Pengujian

1. **Verifikasi Autostart & Status DHCP Server pada `tengen`**:
   Hasil eksekusi `update-rc.d isc-dhcp-server enable` dan pengecekan `service isc-dhcp-server status` mengonfirmasi status layanan aktif dengan pesan: `Status of ISC DHCPv4 server: dhcpd is running`.

   ![Autostart DHCP Server Tengen](assets/soal10_1.png)

2. **Verifikasi Autostart & Status Daemon DHCP Relay pada `jichi`**:
   Hasil eksekusi `update-rc.d isc-dhcp-relay enable` dan pengecekan proses `ps aux | grep dhcrelay` membuktikan daemon `/usr/sbin/dhcrelay -q -i eth2 -i eth3 -i eth4 10.94.4.10` otomatis berjalan kembali pasca-_restart_

   ![Autostart DHCP Relay Jichi](assets/soal10_2.png)

3. **Verifikasi Konektivitas & Kebijakan Lease Client (`ino`)**:
   Pengujian ulang permintaan IP via `udhcpc -i eth0` pada terminal _client_ `ino` membuktikan _client_ berhasil memperoleh alamat IP `10.94.3.10` dari server `10.94.4.10` secara normal sesuai kebijakan alokasi semula.

   ![Verifikasi Lease Client Ino Pasca Restart](assets/soal10_3.png)

---

11. Utahime dan Shoko ditugaskan membangun sistem penamaan domain resmi agar seluruh pos tidak perlu menghafal alamat IP mentah. Konfigurasikan BIND9 pada utahime sebagai DNS Master dan shoko sebagai DNS Slave untuk mengelola domain jujutsu.com. Atur SOA record, NS delegasi untuk kedua server, dan terapkan allow-transfer dari Master ke Slave. Pastikan file zona berhasil tersinkronisasi otomatis ke shoko saat nomor serial di utahime dinaikkan, lalu buktikan dengan melakukan query dig ke kedua server dari salah satu client.

Untuk menyediakan layanan resolusi nama domain resmi secara redundan dan handal di DMZ (Network 1), dikonfigurasikan layanan BIND9 pada node **`utahime`** (`10.94.1.2`) sebagai **DNS Master** dan **`shoko`** (`10.94.1.3`) sebagai **DNS Slave** yang mengelola zona domain `jujutsu.com`.

### Langkah Penyelesaian:

1. **Konfigurasi Master DNS pada Node `utahime`**:
   - Mendeklarasikan zona `jujutsu.com` dengan tipe `master` pada berkas `/etc/bind/named.conf.local` serta membatasi hak _zone transfer_ (`allow-transfer`) hanya ke alamat IP Slave `10.94.1.3`.
   - Menyusun berkas data zona `/etc/bind/jujutsu.com` yang berisi catatan _Start of Authority_ (SOA) dengan serial `2026101301`, delegasi _Name Server_ (NS) ke `utahime.jujutsu.com` dan `shoko.jujutsu.com`, serta A record untuk masing-masing _name server_.

2. **Konfigurasi Slave DNS pada Node `shoko`**:
   - Mendeklarasikan zona `jujutsu.com` dengan tipe `slave` pada berkas `/etc/bind/named.conf.local` dan mengarahkan parameter `masters` ke IP Master `10.94.1.2`.
   - Mengarahkan penyimpanan berkas hasil transfer zona otomatis ke direktori `/var/lib/bind/jujutsu.com`.

3. **Verifikasi Sinkronisasi & Query Domain**:
   - Mengeksekusi pengujian resolusi nama (_query_) dari _client_ `ino` menggunakan utilitas `dig` ke DNS Master (`10.94.1.2`) dan DNS Slave (`10.94.1.3`) untuk memvalidasi nomor serial SOA dan delegasi NS.

#### Konfigurasi Master DNS (`utahime`) — `/etc/bind/named.conf.local`:

```bind
zone "jujutsu.com" {
    type master;
    file "/etc/bind/jujutsu.com";
    allow-transfer { 10.94.1.3; };
};
```

#### Berkas Zona Forward (utahime) — /etc/bind/jujutsu.com:

```
DNS Zone file
$TTL 604800
@ IN SOA utahime.jujutsu.com. root.jujutsu.com. (
    2026101301 ; Serial
    604800     ; Refresh
    86400      ; Retry
    2419200    ; Expire
    604800 )   ; Negative Cache TTL

@ IN NS utahime.jujutsu.com.
@ IN NS shoko.jujutsu.com.

utahime IN A 10.94.1.2
shoko   IN A 10.94.1.3
```

#### Konfigurasi Slave DNS (shoko) — /etc/bind/named.conf.local:

```
DNS Zone file
zone "jujutsu.com" {
    type slave;
    masters { 10.94.1.2; };
    file "/var/lib/bind/jujutsu.com";
};
```

### Pengujian

1. Pengujian Query Record SOA pada Master DNS (utahime):

```
dig @10.94.1.2 jujutsu.com SOA
```

![11](assets/soal11_1.png)

2. Pengujian Query Record NS Delegasi pada Master DNS (utahime):

```
dig @10.94.1.2 jujutsu.com NS
```

![11](assets/soal11_2.png)

3. Pengujian Replikasi & Query Record SOA pada Slave DNS (shoko):

```
dig @10.94.1.3 jujutsu.com SOA
```

![11](assets/soal11_3.png)

---

12. Peta domain harus memetakan pintu masuk utama dan tetap bisa mencari alamat di luar kawasan Shibuya. Pada utahime, buat A record jujutsu.com yang mengarah ke gojo, serta CNAME www yang merujuk ke domain utama tersebut. Buat pula Reverse DNS (zona PTR) untuk melacak IP gojo kembali ke domain resminya, dan aktifkan fitur DNS Forwarder pada BIND9 mengarah ke IP gateway internet (192.168.122.1). Uji dari client dengan dig untuk mengecek CNAME, PTR, dan buktikan client tetap bisa melakukan ping ke domain internet seperti google.com.

Untuk melengkapi konfigurasi DNS agar memetakan gerbang utama DMZ (`gojo` - `10.94.1.10`) serta mendukung pencarian alamat ke internet publik, dikonfigurasikan _A Record_, _CNAME Record_, _Reverse DNS_ (PTR Record), serta fitur _DNS Forwarder_ pada server DNS Master **`utahime`** (`10.94.1.2`).

### Langkah Penyelesaian:

1. **Konfigurasi Zona Forward & Reverse Master di `utahime`**:
   - Mendeklarasikan zona forward `jujutsu.com` dan zona reverse `1.94.10.in-addr.arpa` pada berkas `/etc/bind/named.conf.local` di `utahime` dengan izin transfer ke Slave `10.94.1.3`.
   - Pada berkas `/etc/bind/jujutsu.com`, menambahkan A record `@ IN A 10.94.1.10` (`gojo`), A record `gojo IN A 10.94.1.10`, dan CNAME record `www IN CNAME jujutsu.com.`.
   - Pada berkas zona PTR `/etc/bind/1.94.10.in-addr.arpa`, menambahkan pemetaan pembalik `10 IN PTR jujutsu.com.` untuk melacak IP `10.94.1.10` kembali ke domain resminya.

2. **Aktivasi DNS Forwarder**:
   Mengonfigurasi blok `options` pada berkas `/etc/bind/named.conf.options` di `utahime` dan `shoko` dengan menambahkan arahan `forwarders { 192.168.122.1; 8.8.8.8; };` agar query untuk domain di luar `jujutsu.com` diteruskan ke gateway internet NAT.

3. **Pengujian Integrasi via Client (`ino`)**:
   - Mengeksekusi `dig @10.94.1.2 www.jujutsu.com` untuk memverifikasi resolusi CNAME dan A record.
   - Mengeksekusi `dig -x 10.94.1.10 @10.94.1.2` untuk memverifikasi pemetaan balik PTR record.
   - Mengeksekusi `dig @10.94.1.2 google.com` dan `ping -c 4 google.com` untuk memvalidasi fitur DNS Forwarder dan konektivitas ke internet luar.

#### Konfigurasi Berkas `/etc/bind/named.conf.options` pada `utahime`:

```bind
options {
        directory "/var/cache/bind";
        forwarders {
                192.168.122.1;
                8.8.8.8;
        };
        allow-query { any; };
        recursion yes;
        allow-recursion { any; };
        dnssec-validation no;
        auth-nxdomain no;
        listen-on { any; };
        listen-on-v6 { any; };
};
```

#### Berkas Forward Zone (utahime) — /etc/bind/jujutsu.com:

```
DNS Zone file
$TTL 604800
@ IN SOA utahime.jujutsu.com. root.jujutsu.com. (
    2026101309 ; Serial
    604800     ; Refresh
    86400      ; Retry
    2419200    ; Expire
    604800 )   ; Negative Cache TTL

@ IN NS utahime.jujutsu.com.
@ IN NS shoko.jujutsu.com.

utahime IN A 10.94.1.2
shoko   IN A 10.94.1.3
gojo    IN A 10.94.1.10

@       IN A     10.94.1.10
www     IN CNAME jujutsu.com.
```

#### Berkas Reverse Zone (utahime) — /etc/bind/1.94.10.in-addr.arpa:

```
DNS Zone file
$TTL 604800
@ IN SOA utahime.jujutsu.com. root.jujutsu.com. (
    2026101309 ; Serial
    604800
    86400
    2419200
    604800 )

@ IN NS utahime.jujutsu.com.
@ IN NS shoko.jujutsu.com.

10 IN PTR jujutsu.com.
```

### Pengujian

1. Verifikasi Query CNAME & A Record (www.jujutsu.com):

```
dig @10.94.1.2 www.jujutsu.com (dari client ino)
```

![12](assets/soal12_1.png)

2. Verifikasi Query Reverse DNS / PTR Record (10.94.1.10):

```
dig -x 10.94.1.10 @10.94.1.2 (dari client ino)
```

![12](assets/soal12_2.png)

3. Verifikasi Fitur DNS Forwarder ke Internet (google.com):

```
dig @10.94.1.2 google.com (dari client ino)
```

![12](assets/soal12_3.png)

4. Verifikasi Konektivitas Internet End-to-End (ping google.com):

```
ping -c 4 google.com (dari client ino
```

![12](assets/soal12_4.png)

---
