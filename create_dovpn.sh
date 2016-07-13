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


