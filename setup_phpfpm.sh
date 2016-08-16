#!/bin/bash
# enable PHP-FPM
# guides from here:
# http://z-issue.com/wp/apache-2-4-the-event-mpm-php-via-mod_proxy_fcgi-and-php-fpm-with-vhosts/
# https://www.linode.com/docs/websites/apache/install-php-fpm-and-apache-on-debian-8
# https://wiki.apache.org/httpd/PHP-FPM#unix_domain_socket_.28UDS.29_approach
#
# php values
# http://php.net/manual/en/install.fpm.configuration.php
#

PHP_TIMEZONE=Europe/Berlin

a2enmod proxy_fcgi proxy actions

echo "
deb http://mirrors.linode.com/debian/ jessie main contrib non-free
deb-src http://mirrors.linode.com/debian/ jessie main contrib non-free

deb http://security.debian.org/ jessie/updates main contrib non-free
deb-src http://security.debian.org/ jessie/updates main non-free

# jessie-updates, previously known as 'volatile'
deb http://mirrors.linode.com/debian/ jessie-updates main contrib non-free
deb-src http://mirrors.linode.com/debian/ jessie-updates main contrib non-free
" >> /etc/apt/sources.list

apt-get update && apt-get install libapache2-mod-fastcgi php7.0-fpm

sed -i 's,;date.timezone =.*,date.timezone = $PHP_TIMEZONE,g' /etc/php/7.0/fpm/php.ini
sed -i 's/;opcache.enable=0/opcache.enable=1/g' /etc/php/7.0/fpm/php.ini
sed -i 's/;events.mechanism = epoll.*/events.mechanism = epoll/g' /etc/php/7.0/fpm/php-fpm.conf
sed -i 's/;emergency_restart_threshold.*/emergency_restart_threshold = 10/g' /etc/php/7.0/fpm/php-fpm.conf
sed -i 's/;emergency_restart.*/emergency_restart = 1m/g' /etc/php/7.0/fpm/php-fpm.conf
sed -i 's/;process_control_timeout.*/process_control_timeout = 10s/g' /etc/php/7.0/fpm/php-fpm.conf
sed -i 's/;cgi.fix_pathinfo =.*/cgi.fix_pathinfo = 0/g' /etc/php/7.0/fpm/php-fpm.conf
sed -i 's,error_log =.*,error_log = /var/log/php/php7.0-fpm.log,g' /etc/php/7.0/fpm/php-fpm.conf


mkdir /var/run/php
mkdir /var/log/php

SITE_URL=wordpress.example.com
pool=example_wp
APACHECONFFILE=001-wordpress.example.com.conf
APACHECONFDIR=/etc/apache2/sites-available
APACHECONF=$APACHECONFDIR/$APACHECONFFILE
# WWWPATHHTML=/var/www/wordpress.example.com/public_html

# wordpress config
cat <<EOM > /etc/php/7.0/fpm/pool.d/$pool.conf
;; $SITE_URL
[$pool]
env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
listen = /var/run/php/$pool.sock
listen.owner = $pool
listen.group = www-data
listen.mode = 0660
user = $pool
group = $pool
request_slowlog_timeout = 5s
slowlog = /var/log/php/slowlog-$pool.log
listen.backlog = -1

pm = dynamic
;  The number of PHP-FPM children that should be spawned automatically
pm.start_servers = 3
; The maximum number of children allowed (connection limit)
pm.max_children = 9
; The minimum number of spare idle PHP-FPM servers to have available
pm.min_spare_servers = 2
; The maximum number of spare idle PHP-FPM servers to have available
pm.max_spare_servers = 4
; Maximum number of requests each child should handle before re-spawning
pm.max_requests = 200
; Maximum amount of time to process a request (similar to max_execution_time in php.ini
request_terminate_timeout = 300

php_value[memory_limit] = 96M
php_value[max_execution_time] = 120
php_value[max_input_time] = 300
php_value[php_post_max_size] = 25M
php_value[upload_max_filesize] = 25M
EOM


## big sites with owncloud
pm = dynamic
pm.max_children = 30
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 6
pm.max_requests = 300
pm.process_idle_timeout = 300s
request_terminate_timeout = 300
php_value[max_execution_time] = 300
php_value[max_input_time] = 300
php_value[memory_limit] = 4096M
php_value[post_max_size] = 4096M
php_value[upload_max_filesize] = 4096M

## big sites with wordpress
pm = dynamic
pm.max_children = 40
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 10
pm.max_requests = 1000
pm.process_idle_timeout = 120s
request_terminate_timeout = 120
php_value[max_input_time] = 120
php_value[max_execution_time] = 120
php_value[memory_limit] = 50M
php_value[post_max_size] = 40M
php_value[upload_max_filesize] = 40M

## normal sites
pm = dynamic
pm.max_children = 16
pm.process_idle_timeout = 60s
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 2
pm.max_requests = 500

## small sites
pm = ondemand
pm.max_children = 5
pm.process_idle_timeout = 10s
pm.max_requests = 200


groupadd $pool
useradd -g $pool $pool

# apache config
sed -i '$ d' $APACHECONF

cat <<EOM >> $APACHECONF

  <FilesMatch "\.php$">
    SetHandler "proxy:unix:///var/run/php/$pool.sock|fcgi://$pool/"
  </FilesMatch>

  # if apache 2.4.11 otherwise without enablereuse=on
  # <Proxy fcgi://$pool/ enablereuse=on max=10>
  <Proxy fcgi://$pool/ max=10>
  </Proxy>
</VirtualHost>
EOM

mv /etc/apache2/mods-available/php7.0.conf /etc/apache2/mods-available/php7.0.conf.bkp

cat <<EOM > /etc/apache2/mods-available/php7.0.conf
# <FilesMatch ".+\.ph(p[3457]?|t|tml)$">
#    SetHandler application/x-httpd-php
# </FilesMatch>
#<FilesMatch ".+\.phps$">
#    SetHandler application/x-httpd-php-source
    # Deny access to raw php sources by default
    # To re-enable it's recommended to enable access to the files
    # only in specific virtual host or directory
#    Require all denied
#</FilesMatch>
# Deny access to files without filename (e.g. '.php')
<FilesMatch "^\.ph(p[3457]?|t|tml|ps)$">
    Require all denied
</FilesMatch>

<IfModule mod_mime.c>
   AddHandler application/x-httpd-php .php .php5 .php7 .phtml
   AddHandler application/x-httpd-php-source .phps
 </IfModule>

# Running PHP scripts in user directories is disabled by default
#
# To re-enable PHP in user directories comment the following lines
# (from <IfModule ...> to </IfModule>.) Do NOT set it to On as it
# prevents .htaccess files from disabling it.
<IfModule mod_userdir.c>
    <Directory /home/*/public_html>
        php_admin_flag engine Off
    </Directory>
</IfModule>
EOM

service php7.0-fpm restart
service apache2 restart