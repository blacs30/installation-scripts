#!/usr/bin/env bash

# load variables
source /vagrant/environment.sh

$INSTALLER install -y monit

##########################
# Create the nginx vhost
##########################
cat << MONIT_VHOST > "$NGINX_VHOST_PATH_MONIT"
server {

	listen 		80;
	server_name     $VHOST_SERVER_NAME_MONIT;
	location / {

		return 301 https://\$server_name\$request_uri;
	}
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name $VHOST_SERVER_NAME_MONIT;

	access_log /var/log/nginx/${APPNAME_MONIT}-access.log;
	error_log /var/log/nginx/${APPNAME_MONIT}-error.log warn;

	ssl on;
	ssl_certificate $TLS_CERT_FILE;
	ssl_certificate_key $TLS_KEY_FILE;
	ssl_dhparam $DH_PARAMS_FILE;

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
MONIT_VHOST

ln -s "$NGINX_VHOST_PATH_MONIT" /etc/nginx/sites-enabled/"$APPNAME_MONIT"



# monit configuration
MONITRC=/etc/monit/monitrc
sed -i -r -e "s/# set alert sysadm@foo.*/set alert $MONIT_MAIL # receive all alerts/" $MONITRC
sed -i -r -e "s/# set httpd port 2812 and/set httpd port 2812 and/" $MONITRC
sed -i "/httpd port 2812 and/aSSL ENABLE\nPEMFILE PEMFILE_REPLACE\nALLOWSELFCERTIFICATION" $MONITRC
sed -i -r -e "s,PEMFILE_REPLACE,${TLS_COMBINED}," $MONITRC
sed -i -r -e "s/#    use address localhost/use address 127.0.0.1/" $MONITRC
sed -i -r -e "s/#    allow localhost/allow 127.0.0.1/" $MONITRC
sed -i -r -e "s/#    allow admin:monit/allow $MONIT_USER:$MONIT_PASSWORD/" $MONITRC
sed -i -r -e "s/.*set mailserver.*/set mailserver $SMTP_SERVER/" $MONITRC

# writing monit check configuration
MONIT_CONF_DIR=/etc/monit/conf.d
cat << EOF > $MONIT_CONF_DIR/amavis
check process amavisd with pidfile /var/run/amavis/amavisd.pid
every 5 cycles
group mail
start program = "/etc/init.d/amavis start"
stop  program = "/etc/init.d/amavis stop"
if failed port 10024 protocol smtp then restart
if 5 restarts within 25 cycles then timeout
EOF

cat << EOF > $MONIT_CONF_DIR/nginx
check process nginx with pidfile /var/run/nginx.pid
group www
group nginx
start program = "/etc/init.d/nginx start"
stop program = "/etc/init.d/nginx stop"
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
EOF

cat << EOF > $MONIT_CONF_DIR/dovecot
check process dovecot with pidfile /var/run/dovecot/master.pid
group mail
start program = "/etc/init.d/dovecot start"
stop program = "/etc/init.d/dovecot stop"
group mail
# We'd like to use this line, but see:
# http://serverfault.com/questions/610976/monit-failing-to-connect-to-dovecot-over-ssl-imap
if failed port 993 type tcpssl protocol imap for 5 cycles then restart
# if failed port 993 for 5 cycles then restart
if 5 restarts within 25 cycles then timeout
EOF

cat << EOF > $MONIT_CONF_DIR/mysql
check process mysqld with pidfile /var/run/mysqld/mysqld.pid
group database
start program = "/etc/init.d/mysql start"
stop program = "/etc/init.d/mysql stop"
if failed host 127.0.0.1 port 3306 protocol mysql then restart
if 5 restarts within 5 cycles then timeout
EOF

cat << EOF > $MONIT_CONF_DIR/postfix
check process postfix with pidfile /var/spool/postfix/pid/master.pid
group mail
start program = "/etc/init.d/postfix start"
stop  program = "/etc/init.d/postfix stop"
if failed port 25 protocol smtp then restart
if failed port 465 type tcpssl protocol smtp for 5 cycles then restart
if 5 restarts within 5 cycles then timeout
EOF

cat << EOF > $MONIT_CONF_DIR/spamassassin
check process spamassassin with pidfile /var/run/spamassassin.pid
group mail
start program = "service spamassassin start"
stop  program = "service spamassassin stop"
if 5 restarts within 5 cycles then timeout
EOF

cat << EOF > $MONIT_CONF_DIR/php-fpm
check process php-fpm with pidfile /var/run/php/php7.0-fpm.pid
group www-data #change accordingly
start program = "/etc/init.d/php7.0-fpm start"
stop program  = "/etc/init.d/php7.0-fpm stop"
if failed unixsocket $MONIT_UNIX_SOCKET1 then restart
if 3 restarts within 5 cycles then timeout
EOF

cat << EOF > $MONIT_CONF_DIR/sshd
check process sshd with pidfile /var/run/sshd.pid
start program "/etc/init.d/ssh start"
stop program "/etc/init.d/ssh stop"
if failed host 127.0.0.1 port 22 protocol ssh then restart
if 5 restarts within 5 cycles then timeout
EOF

#create config to check the host system
cat << EOF > $MONIT_CONF_DIR/system
check system localhost
if loadavg (1min) > 8 then alert
if loadavg (5min) > 6 for 3 cycles then alert
if memory usage > 90% then alert
if cpu usage (user) > 80% then alert
if cpu usage (system) > 30% then alert
if cpu usage (wait) > 80% for 3 cycles then alert
EOF

#create config to check rsyslog service
cat << EOF > $MONIT_CONF_DIR/rsyslog
check process syslogd with pidfile /var/run/rsyslogd.pid
start program = "/etc/init.d/rsyslog start"
stop program = "/etc/init.d/rsyslog stop"

check file syslogd_file with path /var/log/syslog
if timestamp > 65 minutes then alert # Have you seen "-- MARK --"?
EOF

#create config to check postgrey service
cat << EOF > $MONIT_CONF_DIR/postgrey
check process postgrey with pidfile /var/run/postgrey.pid
group postgrey
start program = "/etc/init.d/postgrey start"
stop  program = "/etc/init.d/postgrey stop"
if failed host 127.0.0.1 port 10023 type tcp then restart
if 5 restarts within 5 cycles then timeout
EOF

#create config to check opendmarc service
cat << EOF > $MONIT_CONF_DIR/opendmarc
check process opendmarc with pidfile /var/run/opendmarc/opendmarc.pid
group opendmarc
start program = "/etc/init.d/opendmarc start"
stop  program = "/etc/init.d/opendmarc stop"
if failed host 127.0.0.1 port 8892 type tcp then restart
if 5 restarts within 5 cycles then timeout
EOF

#create config to check opendkim service
cat << EOF > $MONIT_CONF_DIR/opendkim
check process opendkim with pidfile /var/run/opendkim/opendkim.pid
group opendkim
start program = "/etc/init.d/opendkim start"
stop  program = "/etc/init.d/opendkim stop"
if failed host 127.0.0.1 port 8891 type tcp then restart
if 5 restarts within 5 cycles then timeout
EOF

#create config to check cron
cat << EOF > $MONIT_CONF_DIR/cron
# Cron
check process cron with pidfile /var/run/crond.pid
start program = "/etc/init.d/cron start"
stop  program = "/etc/init.d/cron stop"
group system
depends cron_init, cron_bin
check file cron_init with path /etc/init.d/cron
group system
check file cron_bin with path /usr/sbin/cron
group system
EOF

#create config to check redis
cat << EOF > $MONIT_CONF_DIR/redis
check process redis-server
with pidfile "/var/run/redis/redis-server.pid"
start program = "/etc/init.d/redis-server start"
stop program = "/etc/init.d/redis-server stop"
if 2 restarts within 3 cycles then timeout
if totalmem > 100 Mb then alert
if children > 255 for 5 cycles then stop
if cpu usage > 95% for 3 cycles then restart
if 5 restarts within 5 cycles then timeout
EOF

#create config to check clamav
cat << EOF > $MONIT_CONF_DIR/clamav
check process clamavd
matching "clamd"
start program = "/etc/init.d/clamav-daemon start"
stop  program = "/etc/init.d/clamav-daemon stop"
if failed unixsocket /var/run/clamav/clamd.ctl then restart
if 5 restarts within 5 cycles then timeout
EOF

#create config to check free hard drive
cat << EOF > $MONIT_CONF_DIR/disk-space
check device disk with path /
if SPACE usage > 80% for 8 cycles then alert
check device nfs with path /root/snapshot
if SPACE usage > 80% then alert
EOF

#create config to check clamav
cat << EOF > $MONIT_CONF_DIR/unbound
check process unbound with pidfile /var/run/unbound.pid
group unbound
start program = "/etc/init.d/unbound start"
stop  program = "/etc/init.d/unbound stop"
if failed host 127.0.0.1 port 53 type tcp then restart
if 5 restarts within 5 cycles then timeout
EOF

nginx -t && systemctl restart nginx && systemctl restart monit
