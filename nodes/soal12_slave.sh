ifconfig eth0 10.94.1.3 netmask 255.255.255.0 up
ip route add default via 10.94.1.1 dev eth0 2>/dev/null
echo "nameserver 8.8.8.8" > /etc/resolv.conf
apt-get update && apt-get install -y bind9

cat << 'EOF' > /etc/bind/named.conf.local
zone "jujutsu.com" {
    type slave;
    masters { 10.94.1.2; };
    file "/var/lib/bind/jujutsu.com";
};

zone "1.94.10.in-addr.arpa" {
    type slave;
    masters { 10.94.1.2; };
    file "/var/lib/bind/1.94.10.in-addr.arpa";
};
EOF

mkdir -p /var/lib/bind
chown -R bind:bind /var/lib/bind /etc/bind
chmod -R 775 /var/lib/bind /etc/bind
pkill named 2>/dev/null
named -u bind
