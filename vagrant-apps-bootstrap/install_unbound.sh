#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

echo "Running install_unbound.sh"

source /vagrant/environment.sh

$INSTALLER install -y unbound

mkdir -v -p "$(dirname "$UNBOUND_NEW_ROOT_KEY")"

if ! unbound-anchor -v -a "$UNBOUND_NEW_ROOT_KEY" && [ ! -f "$UNBOUND_NEW_ROOT_KEY" ]; then
	echo "Error while creating unbound root.key - Exiting"
	exit 1
fi

chown -R unbound:unbound "$(dirname "$UNBOUND_NEW_ROOT_KEY")"

sed -i "s,auto-trust-anchor-file.*,auto-trust-anchor-file: \"$UNBOUND_NEW_ROOT_KEY\"," "$UNBOUND_TRUST_FILE"

echo "server:
interface: 127.0.0.1
do-ip6: no
directory: \"/etc/unbound\"
username: unbound
harden-below-nxdomain: yes
harden-referral-path: yes
# not yet available            harden-algo-downgrade: no # false positives with improperly configured zones
use-caps-for-id: no # makes lots of queries fail
hide-identity: yes
hide-version: yes
prefetch: yes
prefetch-key: yes
msg-cache-size: 128k
msg-cache-slabs: 2
rrset-cache-size: 8m
rrset-cache-slabs: 2
key-cache-size: 32m
key-cache-slabs: 2
cache-min-ttl: 3600
num-threads: 2
val-log-level: 2
use-syslog: yes
verbosity: 1
remote-control:
control-enable: no
#            control-interface: 127.0.0.1
" > "$(dirname $UNBOUND_TRUST_FILE)"/dns_setting.conf

systemctl restart unbound


sed -i 's/^/# /g' /etc/resolv.conf

echo "nameserver 127.0.0.1" >> /etc/resolv.conf

for i in $NAMESERVER
do
echo "nameserver $i" >> /etc/resolv.conf
done
