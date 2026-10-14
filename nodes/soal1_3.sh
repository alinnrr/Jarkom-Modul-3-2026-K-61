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
