# Install monit
I found monit on the internet while looking for a light alarming tool with capabilities for reacting on an issue. It is doing it quite well as I've seen the last year. Here is the installation I use.


### Install prerequisites

Following components are required. Check other manuals on how to install them.
- nginx  

In case you want to use ssl:  
- ssl (or snakeoil certs)  
- optional but recommended to create a new stronger __dh key__

If you want to use monit ssl enabled you need to combine the key and certificate:  
```bash
cat /etc/ssl/my_ssl.key > /etc/ssl/my_ssl_combined.pem
cat /etc/ssl/my_ssl.crt >> /etc/ssl/my_ssl_combined.pem
chmod 600 /etc/ssl/my_ssl_combined.pem
```

The installation of monit itself is pretty easy:  
`aptitude install monit`


After installing monit create the nginx vhost, adjust it to your needs (ssl keys, hostname, paths..). It is a proxy for monit itself, which runs on port 2812 per default.

```
server {

	listen 80;
	server_name mydomain.com;
	location / {

		return 301 https://\$server_name\$request_uri;
	}
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name mydomain.com;
	root /var/www/html/monit;
	access_log /var/log/nginx/monit-access.log;
	error_log /var/log/nginx/monit-error.log warn;

	ssl on;
	ssl_certificate /etc/ssl/my_ssl.crt;
	ssl_certificate_key /etc/ssl/my_ssl.key;
	ssl_dhparam /etc/ssl/my_dhparams.pem;

	index index.php;

	include global/secure_ssl.conf;
	include global/restrictions.conf;
	client_header_timeout 3m;

	# Configure GEOIP access before enabling this setting
	# if (\$allow_visit = no) { return 403 };

	location / {

		rewrite ^/(.*) /\$1 break;
		proxy_ignore_client_abort on;
		proxy_pass https://127.0.0.1:2812/;
		proxy_redirect https://127.0.0.1:2812/ /;
	}
}
```

Activate the vhost configuration and restart php-fpm and nginx:

`ln -s /etc/nginx/sites-available/monit.conf /etc/nginx/sites-enabled/monit`

```
systemctl restart php7.0-fpm
systemctl restart nginx
```

### monit configuration
In `/etc/monit/monitrc` monit has some settings like the mail recepient for alerts and more.
This is how the block of settings might look like. It sets:  
- alert email receiver
- httpd port
- enables SSL
- sets the pemfile (combined key + crt)
- ssl parameter
- binding and allowing address
- monit admin user
- smtp server

```
set alert admin@test.com # receive all alerts
set httpd port 2812 and
SSL ENABLE
PEMFILE /etc/ssl/my_ssl_combined.pem
ALLOWSELFCERTIFICATION
use address 127.0.0.1
allow 127.0.0.1
allow MONIT_USER:MONIT_PASSWORD
set mailserver SMTP_SERVER
```

### monit checks
The check configurion settings that monit knows what it has to check are located here: `/etc/monit/conf.d`. The following blocks are checks which I use and you can adapt them to your needs.  
```
check process amavisd with pidfile /var/run/amavis/amavisd.pid
every 5 cycles
group mail
start program = \"/etc/init.d/amavis start\"
stop  program = \"/etc/init.d/amavis stop\"
if failed port 10024 protocol smtp then restart
if 5 restarts within 25 cycles then timeout
```

```
check process nginx with pidfile /var/run/nginx.pid
group www
group nginx
start program = \"/etc/init.d/nginx start\"
stop program = \"/etc/init.d/nginx stop\"
if children > 255 for 5 cycles then alert
if cpu usage > 95% for 3 cycles then alert
check host $MONIT_CHECK_DOMAIN1 with address $MONIT_CHECK_DOMAIN1
if failed port 443 protocol https with timeout 30 seconds then alert
if failed port 80 protocol http with timeout 30 seconds then alert
if 5 restarts within 5 cycles then timeout

depend nginx_bin
depend nginx_rc
check file nginx_bin with path /usr/sbin/nginx
group nginx
include /etc/monit/templates/rootbin

check file nginx_rc with path /etc/init.d/nginx
group nginx
include /etc/monit/templates/rootbin
```
```
check process dovecot with pidfile /var/run/dovecot/master.pid
group mail
start program = \"/etc/init.d/dovecot start\"
stop program = \"/etc/init.d/dovecot stop\"
group mail
# We'd like to use this line, but see:
# http://serverfault.com/questions/610976/monit-failing-to-connect-to-dovecot-over-ssl-imap
if failed port 993 type tcpssl protocol imap for 5 cycles then restart
# if failed port 993 for 5 cycles then restart
if 5 restarts within 25 cycles then timeout
```
```
check process mysqld with pidfile /var/run/mysqld/mysqld.pid
group database
start program = \"/etc/init.d/mysql start\"
stop program = \"/etc/init.d/mysql stop\"
if failed host 127.0.0.1 port 3306 protocol mysql then restart
if 5 restarts within 5 cycles then timeout
" > $MONIT_CONF_DIR/mysql
```
```
check process postfix with pidfile /var/spool/postfix/pid/master.pid
group mail
start program = \"/etc/init.d/postfix start\"
stop  program = \"/etc/init.d/postfix stop\"
if failed port 25 protocol smtp then restart
if failed port 465 type tcpssl protocol smtp for 5 cycles then restart
if 5 restarts within 5 cycles then timeout
```
```
check process spamassassin with pidfile /var/run/spamassassin.pid
group mail
start program = \"service spamassassin start\"
stop  program = \"service spamassassin stop\"
if 5 restarts within 5 cycles then timeout
```
```
check process php-fpm with pidfile /var/run/php/php7.0-fpm.pid
group www-data #change accordingly
start program = \"/etc/init.d/php7.0-fpm start\"
stop program  = \"/etc/init.d/php7.0-fpm stop\"
if failed unixsocket $MONIT_UNIX_SOCKET1 then restart
if 3 restarts within 5 cycles then timeout
```
```
check process sshd with pidfile /var/run/sshd.pid
start program \"/etc/init.d/ssh start\"
stop program \"/etc/init.d/ssh stop\"
if failed host 127.0.0.1 port 22 protocol ssh then restart
if 5 restarts within 5 cycles then timeout
```

##### create config to check the host system
```
check system localhost
if loadavg (1min) > 8 then alert
if loadavg (5min) > 6 for 3 cycles then alert
if memory usage > 90% then alert
if cpu usage (user) > 80% then alert
if cpu usage (system) > 30% then alert
if cpu usage (wait) > 80% for 3 cycles then alert
```

##### create config to check rsyslog service
```
check process syslogd with pidfile /var/run/rsyslogd.pid
start program = \"/etc/init.d/rsyslog start\"
stop program = \"/etc/init.d/rsyslog stop\"
```

```
check file syslogd_file with path /var/log/syslog
if timestamp > 65 minutes then alert # Have you seen "-- MARK --"?
```

##### create config to check postgrey service
```
check process postgrey with pidfile /var/run/postgrey.pid
group postgrey
start program = "/etc/init.d/postgrey start"
stop  program = "/etc/init.d/postgrey stop"
if failed host 127.0.0.1 port 10023 type tcp then restart
if 5 restarts within 5 cycles then timeout
```
##### create config to check opendmarc service
```
check process opendmarc with pidfile /var/run/opendmarc/opendmarc.pid
group opendmarc
start program = "/etc/init.d/opendmarc start"
stop  program = "/etc/init.d/opendmarc stop"
if failed host 127.0.0.1 port 8892 type tcp then restart
if 5 restarts within 5 cycles then timeout
```
##### create config to check opendkim service
```
check process opendkim with pidfile /var/run/opendkim/opendkim.pid
group opendkim
start program = "/etc/init.d/opendkim start"
stop  program = "/etc/init.d/opendkim stop"
if failed host 127.0.0.1 port 8891 type tcp then restart
if 5 restarts within 5 cycles then timeout
```

```
check process cron with pidfile /var/run/crond.pid
start program = "/etc/init.d/cron start"
stop  program = "/etc/init.d/cron stop"
group system
depends cron_init, cron_bin
check file cron_init with path /etc/init.d/cron
group system
check file cron_bin with path /usr/sbin/cron
group system
```
```
check process redis-server
with pidfile "/var/run/redis/redis-server.pid"
start program = "/etc/init.d/redis-server start"
stop program = "/etc/init.d/redis-server stop"
if 2 restarts within 3 cycles then timeout
if totalmem > 100 Mb then alert
if children > 255 for 5 cycles then stop
if cpu usage > 95% for 3 cycles then restart
if 5 restarts within 5 cycles then timeout
```

```
check process clamavd
matching "clamd"
start program = "/etc/init.d/clamav-daemon start"
stop  program = "/etc/init.d/clamav-daemon stop"
if failed unixsocket /var/run/clamav/clamd.ctl then restart
if 5 restarts within 5 cycles then timeout
```
```
check device disk with path /
if SPACE usage > 80% for 8 cycles then alert
check device nfs with path /root/snapshot
if SPACE usage > 80% then alert
```

```
check process unbound with pidfile /var/run/unbound.pid
group unbound
start program = "/etc/init.d/unbound start"
stop  program = "/etc/init.d/unbound stop"
if failed host 127.0.0.1 port 53 type tcp then restart
if 5 restarts within 5 cycles then timeout
```

After writing configs restart monit and check that it is running.
