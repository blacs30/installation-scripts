# Install Unbound
I use unbound as a DNS resolver and DNS cache. It has built in DNSSEC support which is required when using DANE in a mailserver configuration.

The installation is not complicated and the configuration is not complex for this type of usage. It is not creating a zone in my configuration and for all the DNS keys I use the DNS services of my hoster.

Let's start with the installation:  
aptitude install unbound

This command will create (or update) the root trust anchor which is required for DNSSEC validation. Before running it I create the target folder. After creating the key set user and group ownership to unbound.

```bash
mkdir -p /usr/local/etc/unbound/runtime
unbound-anchor -a /usr/local/etc/unbound/runtime/root.key
chown -R unbound:unbound /usr/local/etc/unbound/runtime
```

In the file `/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf` is a setting to the trust anchor file. That refrence has to be updated and set to the path of the key which we just created:  
- auto-trust-anchor-file: /usr/local/etc/unbound/runtime/root.key

Update the file `/etc/unbound/unbound.conf.d/dns_setting.conf` to match these settings or adjust them to your needs.  
```
server:
interface: 127.0.0.1
do-ip6: no
directory: \"/etc/unbound\"
username: unbound
harden-below-nxdomain: yes
harden-referral-path: yes
#####not yet available in debian jessie...   harden-algo-downgrade: no # false positives with improperly configured zones
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
# control-interface: 127.0.0.1 ## not used at the moment
```

It is time to restart unbound.  
`systemctl restart unbound`

In the `/etc/resolv.conf` add 127.0.0.1 as a nameserver and all others you might want to add:  
- nameserver 127.0.0.1
- nameserver 8.8.8.8
