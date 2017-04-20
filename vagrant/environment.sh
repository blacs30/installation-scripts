#!/usr/bin/env bash
#
# defines variables which are used by multiple scripts
#


#
# Global variable
#
INSTALLER=aptitude


#
# used by:
# - base installation
#
HOST_NAME=testserver
apticron_mail=noreply@test.com
SSH_USER=testuser

#
# used by:
# - csf
#
CSF_CONFIG_FILE=/etc/csf/csf.conf


#
# used by:
# - mysql
#
# Define the mysql root password as this is an unattended installation
MYSQL_ROOT_PASS=123456


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
PHP_OWNER_PHPMYADMIN=phpmyadmin
POOL_CONF_PATH_PHPMYADMIN="/etc/php/7.0/fpm/pool.d/phpmyadmin.conf"
NGINX_VHOST_PATH_PHPMYADMIN="/etc/nginx/sites-available/phpmyadmin.conf"
VHOST_SERVER_NAME_PHPMYADMIN=testorg.com
WWW_PATH_HTML_PHPMYADMIN=/var/ww/phpmyadmin
NGINX_BASIC_AUTH_PHPMYADMIN_FILE=phpmyadmin
NGINX_BASIC_AUTH_PHPMYADMIN_USER=phpmyadmin
NGINX_BASIC_AUTH_PHPMYADMIN_PW=123456







DATA_PATH_NEXTCLOUD=
