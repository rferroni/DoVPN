#!/bin/bash

# variables 
PATH=/etc/openvpn/easy-rsa
SFCONF=/etc/openvpn/server.conf
CFCONF=/etc/openvpn/client.ovpn
CP=/bin/cp
CAT=/bin/cat
OPENSSL=/usr/bin/openssl
IPTABLES=/sbin/iptables
OPENVPN=/usr/sbin/openvpn
#echo $PORT
#echo $REMOTE

# copia directorio easy-rsa
$CP -R /usr/share/easy-rsa /etc/openvpn/
$CP /etc/openvpn/files/vars $PATH
$CP /etc/openvpn/files/cvars $PATH
$CP /etc/openvpn/files/pkitool $PATH
$CP /etc/openvpn/files/clean-all $PATH
$CP /etc/openvpn/files/whichopensslcnf $PATH

# ir al directorio e inicializar
cd $PATH
source ./vars > /dev/null
$PATH/clean-all

# crea CA
$PATH/pkitool --initca

# crea cert server
$PATH/pkitool --server dovpn

# copia ca y cert
$CP $PATH/keys/ca.crt /etc/openvpn
$CP $PATH/keys/dovpn.crt /etc/openvpn
$CP $PATH/keys/dovpn.key /etc/openvpn

# crea server.conf para ovpn
echo $PORT > $SFCONF 
echo 'proto udp' >> $SFCONF 
echo 'dev tun' >> $SFCONF 
echo 'ca ca.crt' >> $SFCONF
echo 'cert dovpn.crt' >> $SFCONF
echo 'key dovpn.key' >> $SFCONF
echo 'dh dh2048.pem' >> $SFCONF
echo 'cipher AES-128-CBC' >> $SFCONF
echo 'server 10.12.21.0 255.255.255.0' >> $SFCONF
echo 'push "redirect-gateway def1 bypass-dhcp"' >> $SFCONF
echo 'push "dhcp-option DNS 8.8.8.8"' >> $SFCONF
echo 'keepalive 10 120' >> $SFCONF
echo 'user nobody' >> $SFCONF
echo 'group nogroup' >> $SFCONF
echo 'persist-key' >> $SFCONF
echo 'persist-tun' >> $SFCONF
echo 'status openvpn-status.log' >> $SFCONF
echo 'log         openvpn.log' >> $SFCONF
echo 'log-append  openvpn.log' >> $SFCONF
echo 'verb 3' >> $SFCONF
echo 'mute 20' >> $SFCONF

# inicialia y crea cert cliente
cd $PATH
source ./cvars > /dev/null
$PATH/pkitool --batch client

# crea cliente.ovpn
echo 'client' >> $CFCONF
echo 'proto udp' >> $CFCONF 
echo 'dev tun' >> $CFCONF 
echo $REMOTE >> $CFCONF 
echo 'resolv-retry infinite' >> $CFCONF 
echo 'nobind' >> $CFCONF 
echo 'user nobody' >> $CFCONF
echo 'group nogroup' >> $CFCONF
echo 'persist-key' >> $CFCONF
echo 'persist-tun' >> $CFCONF
echo 'ns-cert-type server' >> $CFCONF
echo 'cipher AES-128-CBC' >> $CFCONF
echo 'verb 3' >> $CFCONF
echo '<ca>' >> $CFCONF 
$CAT $PATH/keys/ca.crt >> $CFCONF 
echo '</ca>' >> $CFCONF 
echo '<cert>' >> $CFCONF 
$CAT $PATH/keys/client.crt >> $CFCONF
echo '</cert>' >> $CFCONF 
echo '<key>' >> $CFCONF 
$CAT $PATH/keys/client.key >> $CFCONF
echo '</key>' >> $CFCONF 

# crea DH
$OPENSSL dhparam -out /etc/openvpn/dh2048.pem 2048

# firewall
echo 1 > /proc/sys/net/ipv4/ip_forward
$IPTABLES -t nat -A POSTROUTING -o eth0 -j MASQUERADE
$IPTABLES -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A FORWARD -o eth0 -i tun0 -s 10.12.21.0/24 -m conntrack --ctstate NEW -j ACCEPT

# start openvpn
$OPENVPN --daemon --cd /etc/openvpn --config /etc/openvpn/server.conf

