#!/usr/bin/env bash
cd /tmp || ( echo "ERROR changedir to /tmp, aborting"; read -r; exit 1 )
FQDN_HOST_NAME=$1
HOST_ALIAS=$2
IP=$3
echo "$FQDN_HOST_NAME" > /etc/hostname && bash /etc/init.d/hostname.sh && echo "$FQDN_HOST_NAME" > /etc/mailname
echo "$IP $FQDN_HOST_NAME $HOST_ALIAS" >> /etc/hosts
wget https://apt.puppetlabs.com/puppetlabs-release-pc1-jessie.deb
dpkg -i /tmp/puppetlabs-release-pc1-jessie.deb
apt-get update
apt-get install --assume-yes puppetserver
puppet module install puppetlabs-puppetdb --version 5.1.2
puppet module install puppetlabs-puppet_agent --version 1.3.2

# adding puppetdb to the puppet master node
cat << MASTER > /etc/puppetlabs/code/environments/production/manifests/site.pp
node 'default' {

}

node 'puppet' {
  # Configure puppetdb and its underlying database
  class { 'puppetdb': }
  # Configure the Puppet master to use puppetdb
  class { 'puppetdb::master::config': }
}
MASTER
