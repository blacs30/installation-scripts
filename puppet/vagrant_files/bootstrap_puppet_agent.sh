#!/usr/bin/env bash
cd /tmp || ( echo "ERROR changedir to /tmp, aborting"; read -r; exit 1 )
FQDN_HOST_NAME=$1
HOST_ALIAS=$2
IP=$3
IP_PUPPET_MASTER=$4
FQDN_PUPPET_MASTER=$5
ALIAS_PUPPET_MASTER=$6
echo "$FQDN_HOST_NAME" > /etc/hostname && bash /etc/init.d/hostname.sh && echo "$FQDN_HOST_NAME" > /etc/mailname
echo "$IP $FQDN_HOST_NAME $HOST_ALIAS" >> /etc/hosts
echo "$IP_PUPPET_MASTER $FQDN_PUPPET_MASTER $ALIAS_PUPPET_MASTER" >> /etc/hosts
wget https://apt.puppetlabs.com/puppetlabs-release-pc1-jessie.deb
dpkg -i /tmp/puppetlabs-release-pc1-jessie.deb
apt-get update
apt-get install --assume-yes puppet-agent
