#!/usr/bin/env bash
#
# defines variables which are used by multiple scripts
#


#
# Global variables
# used by multiple install files
#
INSTALLER=aptitude
HOST_NAME=testserver
SMTP_SERVER=localhost
IMAP_SERVER=localhost
MYSQL_ROOT_PASS=123456
MYSQL_DB_HOST=localhost

#
# used by:
# - base installation
#
apticron_mail=noreply@test.com
SSH_USER=testuser

#
# used by:
# - base installation
#
MONIT_MAIL=$apticron_mail
MONIT_USER=testuser
MONIT_PASSWORD=123456
MONIT_UNIX_SOCKET1=/run/php/php7.0-fpm.sock
MONIT_CHECK_DOMAIN1=testorg.com
APPNAME_MONIT=monit
SERVICE_USER_MONIT=monit
PHP_OWNER_MONIT=$SERVICE_USER_MONIT
NGINX_VHOST_PATH_MONIT="/etc/nginx/sites-available/monit.conf"
VHOST_SERVER_NAME_MONIT=testorg.com

#
# used by:
# - unbound
#
# space separated name server
NAMESERVER="8.8.8.8 8.26.56.26"
UNBOUND_TRUST_FILE=/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf
UNBOUND_NEW_ROOT_KEY=/usr/local/etc/unbound/runtime/root.key

#
# used by:
# - csf
#
CSF_CONFIG_FILE=/etc/csf/csf.conf

#
# used by:
# - phpfpm
#
PHP_CONFIG_FILE=/etc/php/7.0/fpm/php.ini
PHPFPM_CONFIG_FILE=/etc/php/7.0/fpm/php-fpm.conf
PHP_TIMEZONE=Europe/Berlin

#
# used by:
# - nginx
#
NGINX_DIR=/etc/nginx
NGINX_CONF=$NGINX_DIR/nginx.conf
#
# used by:
# - snakeoil cert
# - dh key
COUNTRYNAME=DE
PROVINCENAME=Hamburg
KEY_LOCATION=Hamburg
KEY_ORGANIZATION=Organisation
KEY_OUN=IT
KEY_MAIL=webmaster@testorg.com
KEY_COMMON_NAME=testorg.com
#TODO:alternateDNS lists and generate it for snakeoil certs

#
# used by:
# - phpmyadmin
#
APPNAME_PHPMYADMIN=phpmyadmin
SERVICE_USER_PHPMYADMIN=phpmyadmin
PHP_OWNER_PHPMYADMIN=$SERVICE_USER_PHPMYADMIN
POOL_CONF_PATH_PHPMYADMIN="/etc/php/7.0/fpm/pool.d/phpmyadmin.conf"
NGINX_VHOST_PATH_PHPMYADMIN="/etc/nginx/sites-available/phpmyadmin.conf"
VHOST_SERVER_NAME_PHPMYADMIN=testorg.com
HTML_ROOT_PHPMYADMIN=/var/www/phpmyadmin
NGINX_BASIC_AUTH_PHPMYADMIN_FILE=phpmyadmin
NGINX_BASIC_AUTH_PHPMYADMIN_USER=phpmyadmin
NGINX_BASIC_AUTH_PHPMYADMIN_PW=123456


#
# used by:
# - webmail
#
MYSQL_DB_WEBMAIL=webmail
MYSQL_WEBMAIL_USER=webmail
MYSQL_WEBMAIL_PASS=123456
SERVICE_USER_WEBMAIL=webmail
HTML_ROOT_WEBMAIL=/var/www/webmail
APPNAME_WEBMAIL=webmail
PHP_OWNER_WEBMAIL=$SERVICE_USER_WEBMAIL
VHOST_SERVER_NAME_WEBMAIL=testorg.com
POOL_CONF_PATH_WEBMAIL="/etc/php/7.0/fpm/pool.d/webmail.conf"
NGINX_VHOST_PATH_WEBMAIL="/etc/nginx/sites-available/webmail.conf"
NGINX_BASIC_AUTH_WEBMAIL_FILE=webmail
NGINX_BASIC_AUTH_WEBMAIL_USER=webmail
NGINX_BASIC_AUTH_WEBMAIL_PW=123456
WEBMAIL_SITENAME="Lisowski Dev Webmail"
TABLE_PREFIX_WEBMAIL=alwm1_

#
# used by:
# - redis
# - wordpress
# - owncloud
# - nextcloud
REDIS_CONF=/etc/redis/redis.conf
REDIS_PASS=$(< /dev/urandom tr -dc "a-zA-Z0-9@#*=" | fold -w "$(shuf -i 13-15 -n 1)" | head -n 1)
REDIS_SOCKET=/run/redis/redis.sock
declare -a PLUGINS_URLS=( "https://downloads.wordpress.org/plugin/gotmls.4.16.53.zip"
"https://downloads.wordpress.org/plugin/better-wp-security.6.2.1.zip"
"https://downloads.wordpress.org/plugin/redis-cache.1.3.5.zip"
"https://downloads.wordpress.org/plugin/two-factor-authentication.1.2.21.zip" )


#
# used by:
# - wordpress
#
MYSQL_DB_WORDPRESS=wordpress
MYSQL_WORDPRESS_USER=wordpress
MYSQL_WORDPRESS_PASS=123456
SERVICE_USER_WORDPRESS=wordpress
HTML_ROOT_WORDPRESS=/var/www/wordpress
APPNAME_WORDPRESS=wordpress
PHP_OWNER_WORDPRESS=$SERVICE_USER_WORDPRESS
VHOST_SERVER_NAME_WORDPRESS=testorg.com
POOL_CONF_PATH_WORDPRESS="/etc/php/7.0/fpm/pool.d/wordpress.conf"
NGINX_VHOST_PATH_WORDPRESS="/etc/nginx/sites-available/wordpress.conf"
NGINX_BASIC_AUTH_WORDPRESS_FILE=wordpress
NGINX_BASIC_AUTH_WORDPRESS_USER=wordpress
NGINX_BASIC_AUTH_WORDPRESS_PW=123456
WORDPRESS_SITENAME="Lisowski Dev Wordpress"
TABLE_PREFIX_WORDPRESS=wp1_
if [ -f $REDIS_CONF ]; then
  WORDPRESS_REDIS_PASS=$(grep 'requirepass ' $REDIS_CONF | cut -d " " -f 2)
fi
WORDPRESS_REDIS_SOCKET=/run/redis/redis.sock

#
# used by:
# - owncloud
#
MYSQL_DB_OWNCLOUD=owncloud
MYSQL_OWNCLOUD_USER=owncloud
MYSQL_OWNCLOUD_PASS=123456
SERVICE_USER_OWNCLOUD=owncloud
HTML_ROOT_OWNCLOUD=/var/www/owncloud
APPNAME_OWNCLOUD=owncloud
PHP_OWNER_OWNCLOUD=$SERVICE_USER_OWNCLOUD
VHOST_SERVER_NAME_OWNCLOUD=testorg.com
POOL_CONF_PATH_OWNCLOUD="/etc/php/7.0/fpm/pool.d/owncloud.conf"
NGINX_VHOST_PATH_OWNCLOUD="/etc/nginx/sites-available/owncloud.conf"
NGINX_BASIC_AUTH_OWNCLOUD_FILE=owncloud
NGINX_BASIC_AUTH_OWNCLOUD_USER=owncloud
NGINX_BASIC_AUTH_OWNCLOUD_PW=123456
TABLE_PREFIX_OWNCLOUD=oc1_
OWNCLOUD_TIMEZONE=Europe/Berlin

if [ -f $REDIS_CONF ]; then
  OWNCLOUD_REDIS_PASS=$(grep 'requirepass ' $REDIS_CONF | cut -d " " -f 2)
fi
OWNCLOUD_REDIS_SOCKET=/run/redis/redis.sock


#
# used by:
# - nextcloud
#
MYSQL_DB_NEXTCLOUD=nextcloud
MYSQL_NEXTCLOUD_USER=nextcloud
MYSQL_NEXTCLOUD_PASS=123456
SERVICE_USER_NEXTCLOUD=nextcloud
HTML_ROOT_NEXTCLOUD=/var/www/nextcloud
APPNAME_NEXTCLOUD=nextcloud
PHP_OWNER_NEXTCLOUD=$SERVICE_USER_NEXTCLOUD
VHOST_SERVER_NAME_NEXTCLOUD=testorg.com
POOL_CONF_PATH_NEXTCLOUD="/etc/php/7.0/fpm/pool.d/nextcloud.conf"
NGINX_VHOST_PATH_NEXTCLOUD="/etc/nginx/sites-available/nextcloud.conf"
NGINX_BASIC_AUTH_NEXTCLOUD_FILE=nextcloud
NGINX_BASIC_AUTH_NEXTCLOUD_USER=nextcloud
NGINX_BASIC_AUTH_NEXTCLOUD_PW=123456
TABLE_PREFIX_NEXTCLOUD=nc1_
NEXTCLOUD_TIMEZONE=Europe/Berlin

if [ -f $REDIS_CONF ]; then
  NEXTCLOUD_REDIS_PASS=$(grep 'requirepass ' $REDIS_CONF | cut -d " " -f 2)
fi
NEXTCLOUD_REDIS_SOCKET=/run/redis/redis.sock


#
# used by:
# - bbs
#
# initial user and password are:
# admin:admin
SERVICE_USER_BBS=bbs
HTML_ROOT_BBS=/var/www/bbs
APPNAME_BBS=BBS
PHP_OWNER_BBS=$SERVICE_USER_BBS
NGINX_VHOST_PATH_BBS="/etc/nginx/sites-available/bbs.conf"
POOL_CONF_PATH_BBS="/etc/php/7.0/fpm/pool.d/bbs.conf"
VHOST_SERVER_NAME_BBS=testorg.com


#
# used by:
# - cops
#
SERVICE_USER_COPS=cops
HTML_ROOT_COPS=/var/www/cops
APPNAME_COPS=COPS
PHP_OWNER_COPS=$SERVICE_USER_COPS
NGINX_VHOST_PATH_COPS="/etc/nginx/sites-available/cops.conf"
POOL_CONF_PATH_COPS="/etc/php/7.0/fpm/pool.d/cops.conf"
VHOST_SERVER_NAME_COPS=testorg.com
CALIBRE_LIBRARY=/vagrant/calibre
NGINX_BASIC_AUTH_COPS_FILE=cops
NGINX_BASIC_AUTH_COPS_USER=cops
NGINX_BASIC_AUTH_COPS_PW=123456

#
# used by:
# - postifxadmin
#
MYSQL_DB_PFA=pfa
MYSQL_PFA_USER=pfa
MYSQL_PFA_PASS=123456
SERVICE_USER_PFA=pfa
HTML_ROOT_PFA=/var/www/pfa
APPNAME_PFA=POSTFIXADMIN
PHP_OWNER_PFA=$SERVICE_USER_PFA
NGINX_VHOST_PATH_PFA="/etc/nginx/sites-available/pfa.conf"
POOL_CONF_PATH_PFA="/etc/php/7.0/fpm/pool.d/pfa.conf"
VHOST_SERVER_NAME_PFA=testorg.com
CALIBRE_LIBRARY=/vagrant
NGINX_BASIC_AUTH_PFA_FILE=pfa
NGINX_BASIC_AUTH_PFA_USER=pfa
NGINX_BASIC_AUTH_PFA_PW=123456
PFA_POSTMASTER=webmaster@testorg.com
POSTMASTER_PASSWORD=QAWS123
