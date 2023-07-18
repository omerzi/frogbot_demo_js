#!/bin/bash -xe

apt-get update 
apt-get install -y unzip
cd /usr/local/bin
curl -J -O -L https://app.strongdm.com/releases/cli/linux && unzip sdmcli* && rm -f sdmcli*
./sdm install --relay --user ubuntu --token="${token}"
# Enable ip forwarding and nat
sysctl -w net.ipv4.ip_forward=1

# Make forwarding persistent.
sed -i= 's/^[# ]*net.ipv4.ip_forward=[[:digit:]]/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE


echo "${sshkeys}" >> /home/ubuntu/.ssh/authorized_keys

