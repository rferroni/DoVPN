# DoVPN
DoVPN = Docker + OpenVPN

# Idea

I create this new Docker with the idea to be completely integrated and automated the OpenVPN service with the creation of the certificates and configurations files used by the server and the client.

The base is a Debian image (Jessie) with the OpenVPN, Easy-RSA and Iptables packages installed.

#### Service Online: still in progress --> https://dovpn.ml


# Step by Step 
All it can be done with this 4 lines:

* docker pull rferroni/dovpn
* cd && git clone https://github.com/rferroni/DoVPN.git && cd DoVPN/
* chmod +x create_dovpn.sh && chmod +x 0000/initialize.sh
* ./create_dovpn.sh 1194


# Let´s explain in detail

We advice to create a new user in the Linux and not use Docker with root.
Create the user and add it to the "docker" group.
`$ useradd rferroni`
`$ addgroup rferroni docker`

You can choose to pull the image:
`$ docker pull rferroni/dovpn`

Or build a new image using this `cat Dockerfile`:
```bash
FROM debian:jessie 
MAINTAINER Rodrigo Ferroni <rferroni@gmail.com>
RUN apt-get update && apt-get install -y openvpn iptables easy-rsa && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /etc/openvpn
```
Of course you can modify the "MANTEINER" ;)
Now build the Docker!
`$ docker build -t rferroni/dovpn . `

We install OpenVPN, Easy-RSA and IPTables packages and remove some directories that we don´t need. 

````
$ docker images
REPOSITORY                TAG                IMAGE ID            CREATED             SIZE
rferroni/dovpn            latest             b0572xcf1aa5     2 minutes ago       139.1 MB
debian                    jessie             1b088884749b     4 weeks ago         125.1 MB
````
Check if the new image is in your local machine, also will appear the debian image used.

# How to configure

We need to create the directory "0000" in your home (because we will use the $HOME variable) where we will copy all the necessary files. 
The files you have to copy are: 
- /home/rferroni/0000/initialize.sh --> main script that create configurations files, certificates, firewall rules, etc.
- /home/rferroni/0000/files/clean-all cvars pkitool vars whichopensslcnf --> files related to create CA, server and client certificates.

#### All this files and scritps are on [GitHub Pages](https://github.com/rferroni/DoVPN).
Note: If you download the files using `git clone https://github.com/rferroni/DoVPN.git` you need to change the permissions of the scripts files. Use `chmod +x initialize.sh` and `chmod +x 0000/initialize.sh`

Now we will run the script `create_dovpn.sh` to create a new instance of the Docker image DoVPN.

Where you need to specify the port number you want to use. It is important that every instance of this Docker must have different port number. For this example I define a range from 1194 (default port) to 1204. 

#### The "create_dovpn.sh" script:
````````````````````````````````````bash
#!/bin/bash

# you need to use the port number (between 1994 and 2004) as the main variable $1
# example: ./create_dovpn.sh 1994

# check if $1 exist 
if [[ $# -eq 0 ]]
   then 
	echo "The port number is missing, have to be between 1194 and 1204"
	echo "Example: ./create_dovpn.sh 1194"
	exit 1
   else
   if [ "$1" -ge 1194 -a "$1" -le 1204 ]
	then 
	     	echo $1
		# create directory for the new instance
		cp -R $HOME/DoVPN/0000/ $HOME/DoVPN/$1

		# create new instance of dovpn
		docker run -ti -d -P --privileged --name dovpn$1 -e PORT="port ${1}" -e REMOTE="remote dovpn.ml ${1}" -p $1:$1/udp --net=bridge -v $HOME/DoVPN/$1:/etc/openvpn:rw rferroni/dovpn /bin/bash
		sleep 3

		# inicialice cert & ovpn
		docker exec dovpn$1 /bin/bash -c /etc/openvpn/initialize.sh

		# copy client.ovpn 
			# if you have a web server you can access later with an URL
			# Example: https://dovpn.ml/client1194.ovpn
			cp $HOME/client$1.ovpn /var/nginx/dovpn/client$1.ovpn
		
	else
		echo "The port number have to be between 1194 and 1204"
		echo "Example: ./create_dovpn.sh 1194"
		exit 1
   fi
fi
````````````````````````````````````
#### Notes:
- In the script we create the working directory based on the main variable $1 that it will be used as the Port number where the OpenVPN service will be Listening. 

- Then it create the new instance of the docker using de command "docker run". Among the options we declare two environment variables that will be used to create eh configuration file server.conf for the OpenVPN server. PORT and REMOTE (this last one it have to be your Public IP Address or your Domain).

- The "docker exec" is very important, because it will execute inside the Docker an script that will create all the certificates: CA, Server and Client Cert and Keys, DH. And the two OpenVPN configurations files (server.conf and client.ovpn).

- You need to copy the client.ovpn file to your device (mobile, laptop, etc) where you will import this as a profile in the OpenVPN Connect application.

#### The "initialize.sh" script:

````````````````````````````````````bash
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
````````````````````````````````````
#### Notes:
- First we need to define a lot of variables, because inside the docker I find that the binaries wouldn´t use the environment variables like $PATH when they are call in a script. 
- Then we copy five files related to Easy-RSA, I have to modify them to solve the variables problem and to use "pkitool" only in a non-interactive mode.
- The next thing is the creation of all necessaries Certificates and Configurations.
- Some Iptables rules to allow mainly the Forwarding traffic.
- And finally we start the OpenVPN services.

# Last words
* Create, Use and Destroy It.
* Secure and encrypted VPN. 
* Keeps no logs. 
* Surf anonymously.
