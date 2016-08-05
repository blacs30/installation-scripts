# enable PHP-FPM
# guides from here:
# http://z-issue.com/wp/apache-2-4-the-event-mpm-php-via-mod_proxy_fcgi-and-php-fpm-with-vhosts/
# https://www.linode.com/docs/websites/apache/install-php-fpm-and-apache-on-debian-8
# https://wiki.apache.org/httpd/PHP-FPM#unix_domain_socket_.28UDS.29_approach
# 

APACHECONF=/etc/apache2/sites-available/001-wordpress.example.com.conf
WWWPATHHTML=/var/www/wordpress.example.com/public_html
pool=example_wp
SITE_URL=

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

#echo "error_log = /var/log/php-fpm.log" >> /etc/php/7.0/fpm/php.ini
sed -i 's/;events.mechanism = epoll.*/events.mechanism = epoll/g' /etc/php/7.0/fpm/php-fpm.conf
sed -i 's/;emergency_restart_threshold = 0.*/emergency_restart_threshold = 0/g' /etc/php/7.0/fpm/php-fpm.conf

cat <<EOM > /etc/php/7.0/fpm/pool.d/$pool.conf
;; $SITE_URL
[$pool]
listen = /var/run/php/$pool.sock
listen.owner = $pool
listen.group = www-data
listen.mode = 0660
user = $pool
group = $pool
pm = dynamic
;  The number of PHP-FPM children that should be spawned automatically
pm.start_servers = 3
; The maximum number of children allowed (connection limit)
pm.max_children = 100
; The minimum number of spare idle PHP-FPM servers to have available
pm.min_spare_servers = 2
; The maximum number of spare idle PHP-FPM servers to have available
pm.max_spare_servers = 5
; Maximum number of requests each child should handle before re-spawning
pm.max_requests = 10000
; Maximum amount of time to process a request (similar to max_execution_time in php.ini
request_terminate_timeout = 300
EOM

mkdir /var/run/php
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

service php7.0-fpm restart
server apache2 restart
