ifconfig eth0 10.94.1.2 netmask 255.255.255.0 up
ip route add default via 10.94.1.1 dev eth0 2>/dev/null
echo "nameserver 8.8.8.8" > /etc/resolv.conf

apt-get update && apt-get install -y bind9
cat << 'EOF' > /etc/bind/named.conf.local
zone "jujutsu.com" {
    type master;
    file "/etc/bind/jujutsu.com";
    allow-transfer { 10.94.1.3; };
};

zone "1.94.10.in-addr.arpa" {
    type master;
    file "/etc/bind/1.94.10.in-addr.arpa";
    allow-transfer { 10.94.1.3; };
};
EOF

cat << 'EOF' > /etc/bind/jujutsu.com
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
EOF

cat << 'EOF' > /etc/bind/1.94.10.in-addr.arpa
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
EOF

chown -R bind:bind /etc/bind
chmod -R 775 /etc/bind
pkill named 2>/dev/null
named -u bind
rndc reload 2>/dev/null
