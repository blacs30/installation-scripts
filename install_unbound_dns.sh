#!/bin/sh
# https://feeding.cloud.geek.nz/posts/setting-up-your-own-dnssec-aware/
apt-get install unbound
unbound-anchor

sed -i 's,/var/lib/,/etc/,g' /etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf

echo "server:
            interface: 127.0.0.1
            do-ip6: no
            directory: "/etc/unbound"
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
" > /etc/unbound/unbound.conf.d/dns_setting.conf

service unbound restart

UNBOUNDISSTARTED=$(ps -C unbound | grep unbound | wc -l)

# Generate Apache directory and vhost config $SSL_CONF
# if vhost config does not exist
echo "Create apache vhost config files"
if [ "$UNBOUNDISSTARTED" -ge "1" ];
        then
          sed -i 's/^/# /g' /etc/resolv.conf
          echo "nameserver 127.0.0.1" >> /etc/resolv.conf
          echo "nameserver 127.0.0.1" >> /etc/resolv.conf
          echo "nameserver 127.0.0.1" >> /etc/resolv.conf
else
      echo "ERROR: Unbound did not start"
      service unbound status
fi
