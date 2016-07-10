#!/bin/bash
export DOMAIN=example.com
export PASSWORD=user
export USER=user
# the PEMFILE should be a chain of the public key and cert use cat >>  to achive this
export PEMFILE=/var/www/mail.example.com/ssl/mail.example.com.crt
export MAILSERVER=localhost

# install monit as monitoring software
echo "install monit"
apt-get update
apt-get upgrade
apt-get install --assume-yes monit

echo "
check process amavisd with pidfile /var/run/amavis/amavisd.pid
  every 5 cycles
  group mail
  start program = \"/etc/init.d/amavis start\"
  stop  program = \"/etc/init.d/amavis stop\"
  if failed port 10024 protocol smtp then restart
  if 5 restarts within 25 cycles then timeout
" > /etc/monit/conf.d/amavis

echo "
check process apache2 with pidfile /var/run/apache2/apache2.pid
  group www
  start program = \"/etc/init.d/apache2 start\"
  stop program = \"/etc/init.d/apache2 stop\"
  if children > 255 for 5 cycles then alert
  if cpu usage > 95% for 3 cycles then alert
  if failed host localhost port 80 protocol http
    with timeout 10 seconds
    then restart
  if 5 restarts within 5 cycles then timeout
" > /etc/monit/conf.d/apache2

echo "
check process dovecot with pidfile /var/run/dovecot/master.pid
  group mail
  start program = \"/etc/init.d/dovecot start\"
  stop program = \"/etc/init.d/dovecot stop\"
  group mail
  # We'd like to use this line, but see:
  # http://serverfault.com/questions/610976/monit-failing-to-connect-to-dovecot-over-ssl-imap
  #if failed port 993 type tcpssl sslauto protocol imap for 5 cycles then restart
  if failed port 993 for 5 cycles then restart
  if 5 restarts within 25 cycles then timeout
" > /etc/monit/conf.d/dovecot

echo "
check process mysqld with pidfile /var/run/mysqld/mysqld.pid
  group database
  start program = \"/etc/init.d/mysql start\"
  stop program = \"/etc/init.d/mysql stop\"
  if failed host localhost port 3306 protocol mysql then restart
  if 5 restarts within 5 cycles then timeout
" > /etc/monit/conf.d/mysql

echo "
check process postfix with pidfile /var/spool/postfix/pid/master.pid
  group mail
  start program = \"/etc/init.d/postfix start\"
  stop  program = \"/etc/init.d/postfix stop\"
  if failed port 25 protocol smtp then restart
  if 5 restarts within 5 cycles then timeout
" > /etc/monit/conf.d/postfix

echo "
check process spamassassin with pidfile /var/run/spamd.pid
  group mail
  start program = \"/etc/init.d/spamassassin start\"
  stop  program = \"/etc/init.d/spamassassin stop\"
  if 5 restarts within 5 cycles then timeout
" > /etc/monit/conf.d/spamassassin

echo "
check process sshd with pidfile /var/run/sshd.pid
  start program \"/etc/init.d/ssh start\"
  stop program \"/etc/init.d/ssh stop\"
  if failed host 127.0.0.1 port 22 protocol ssh then restart
   if 5 restarts within 5 cycles then timeout
" > /etc/monit/conf.d/sshd

echo "create config to check the host system"
echo "
check system \$HOST
    if loadavg (5min) > 3 then alert
    if loadavg (15min) > 1 then alert
    if memory usage > 80% for 4 cycles then alert
    if swap usage > 20% for 4 cycles then alert
    # Test the user part of CPU usage
    if cpu usage (user) > 80% for 2 cycles then alert
    # Test the system part of CPU usage
    if cpu usage (system) > 20% for 2 cycles then alert
    # Test the i/o wait part of CPU usage
    if cpu usage (wait) > 80% for 2 cycles then alert
    # Test CPU usage including user, system and wait. Note that
    # multi-core systems can generate 100% per core
    # so total CPU usage can be more than 100%
" > /etc/monit/conf.d/system

echo "create config to check rsyslog service"
echo "
check process syslogd with pidfile /var/run/rsyslogd.pid
   start program = \"/etc/init.d/rsyslog start\"
   stop program = \"/etc/init.d/rsyslog stop\"

 check file syslogd_file with path /var/log/syslog
   if timestamp > 65 minutes then alert # Have you seen "-- MARK --"?
"  > /etc/monit/conf.d/rsyslog

echo "create config to check postgrey service"
echo '
check process postgrey with pidfile /var/run/postgrey.pid
   group postgrey
   start program = "/etc/init.d/postgrey start"
   stop  program = "/etc/init.d/postgrey stop"
   if failed host 127.0.0.1 port 10023 type tcp then restart
   if 5 restarts within 5 cycles then timeout
' > /etc/monit/conf.d/postgrey

echo "create config to check opendmarc service"
echo '
check process opendkim with pidfile /var/run/opendmarc/opendmarc.pid
   group opendmarc
   start program = "/etc/init.d/opendmarc start"
   stop  program = "/etc/init.d/opendmarc stop"
   if failed host localhost port 8892 type tcp then restart
   if 5 restarts within 5 cycles then timeout
' > /etc/monit/conf.d/opendmarc

echo "create config to check opendkim service"
echo '
check process opendkim with pidfile /var/run/opendkim/opendkim.pid
   group opendkim
   start program = "/etc/init.d/opendkim start"
   stop  program = "/etc/init.d/opendkim stop"
   if failed host localhost port 8891 type tcp then restart
   if 5 restarts within 5 cycles then timeout
' > /etc/monit/conf.d/opendkim

echo "create config to check cron"
echo '
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
' > /etc/monit/conf.d/cron

echo "create config to check redis"
echo '
check process redis-server
    with pidfile "/var/run/redis/redis-server.pid"
    start program = "/etc/init.d/redis-server start"
    stop program = "/etc/init.d/redis-server stop"
    if 2 restarts within 3 cycles then timeout
    if totalmem > 100 Mb then alert
    if children > 255 for 5 cycles then stop
    if cpu usage > 95% for 3 cycles then restart
    if 5 restarts within 5 cycles then timeout
' > /etc/monit/conf.d/redis

echo "create config to check free hard drive"
echo '
check device disk with path /
    if SPACE usage > 80% then alert
check device nfs with path /root/snapshot
    if SPACE usage > 80% then alert
' > /etc/monit/conf.d/disk-space

MONITRC=/etc/monit/monitrc
sed -i "s/# set alert sysadm@foo.*/set alert admin@$DOMAIN # receive all alerts/" $MONITRC
sed -i "s/# set httpd port 2812 and/set httpd port 2812 and/" $MONITRC
sed -i 's/httpd port 2812 and/& \
     SSL ENABLE \
     PEMFILE  PEMFILE_REPLACE \
     ALLOWSELFCERTIFICATION/' $MONITRC
sed -i "s,PEMFILE_REPLACE,$PEMFILE," $MONITRC
sed -i "s/#    use address localhost/use address localhost/" $MONITRC
sed -i "s/#    allow localhost/allow localhost/" $MONITRC
sed -i "s/#    allow admin:monit/allow $USER:$PASSWORD/" $MONITRC
sed -i "s/.*set mailserver.*/set mailserver $MAILSERVER/" $MONITRC

service monit restart

a2enmod proxy \
        proxy_http

service apache2 restart

echo " add following lines to vhost but check the SSLProxy checks if needed with valid certs

SSLProxyEngine on
SSLProxyVerify none
SSLProxyCheckPeerCN off
SSLProxyCheckPeerName off
SSLProxyCheckPeerExpire off

ProxyPass /monit/  https://127.0.0.1:2812/
ProxyPassReverse /monit/  https://127.0.0.1:2812/
  <Location /monit/>
    Order deny,allow
    Allow from all
  </Location>
"

# Write mysql root password to file - keep it save
echo "Write root password into file /var/scripts/m-a-pass.txt, keep it safe"
echo $PASSWORD >> $SCRIPTS/m-a-pass.txt

echo "Installation succeded...
Press ENTER to finish"
read
