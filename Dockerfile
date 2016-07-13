FROM debian:jessie 
MAINTAINER Rodrigo Ferroni <rferroni@gmail.com>
RUN apt-get update && apt-get install -y openvpn iptables easy-rsa && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /etc/openvpn

