#!/usr/bin/env bash
#
# defines variables which are used by multiple scripts
#


#
# Global variables
# used by multiple install files
#
INSTALLER=aptitude
HOST_NAME=mail.testorg.com
DOMAIN_NAME=testorg.com
DOMAIN_NAME2=
SMTP_SERVER=127.0.0.1
IMAP_SERVER=127.0.0.1
MYSQL_ROOT_PASS=123456
MYSQL_DB_HOST=127.0.0.1
MYSQL_BIND_NAME_IP=$MYSQL_DB_HOST
ARTIFACT_DIR=/vagrant

#
# used by:
# - base installation
#
APTICRON_MAIL=admin@$DOMAIN_NAME
SSH_USER=testuser

#
# used by:
# - base installation
#
MONIT_MAIL=admin@$DOMAIN_NAME
MONIT_USER=monit
MONIT_PASSWORD=monit123456
MONIT_UNIX_SOCKET1=/run/php/php7.0-fpm.sock
MONIT_CHECK_DOMAIN1=testorg.com
APPNAME_MONIT=monit
SERVICE_USER_MONIT=monit
PHP_OWNER_MONIT=$SERVICE_USER_MONIT
NGINX_VHOST_PATH_MONIT="/etc/nginx/sites-available/monit.conf"
VHOST_SERVER_NAME_MONIT=monit.testorg.com

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
# - phpmyadmin
#
APPNAME_PHPMYADMIN=phpmyadmin
SERVICE_USER_PHPMYADMIN=phpmyadmin
PHP_OWNER_PHPMYADMIN=$SERVICE_USER_PHPMYADMIN
POOL_CONF_PATH_PHPMYADMIN="/etc/php/7.0/fpm/pool.d/phpmyadmin.conf"
NGINX_VHOST_PATH_PHPMYADMIN="/etc/nginx/sites-available/phpmyadmin.conf"
VHOST_SERVER_NAME_PHPMYADMIN=pma.testorg.com
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
VHOST_SERVER_NAME_WEBMAIL=wm.testorg.com
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
VHOST_SERVER_NAME_WORDPRESS=wordpress.testorg.com
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
VHOST_SERVER_NAME_OWNCLOUD=oc.testorg.com
POOL_CONF_PATH_OWNCLOUD="/etc/php/7.0/fpm/pool.d/owncloud.conf"
NGINX_VHOST_PATH_OWNCLOUD="/etc/nginx/sites-available/owncloud.conf"
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
VHOST_SERVER_NAME_NEXTCLOUD=nc.testorg.com
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
APPNAME_BBS=bbs
PHP_OWNER_BBS=$SERVICE_USER_BBS
NGINX_VHOST_PATH_BBS="/etc/nginx/sites-available/bbs.conf"
POOL_CONF_PATH_BBS="/etc/php/7.0/fpm/pool.d/bbs.conf"
VHOST_SERVER_NAME_BBS=bbs.testorg.com


#
# used by:
# - cops
#
SERVICE_USER_COPS=cops
HTML_ROOT_COPS=/var/www/cops
APPNAME_COPS=cops
PHP_OWNER_COPS=$SERVICE_USER_COPS
NGINX_VHOST_PATH_COPS="/etc/nginx/sites-available/cops.conf"
POOL_CONF_PATH_COPS="/etc/php/7.0/fpm/pool.d/cops.conf"
VHOST_SERVER_NAME_COPS=cops.testorg.com
CALIBRE_LIBRARY=/vagrant/calibre
NGINX_BASIC_AUTH_COPS_FILE=cops
NGINX_BASIC_AUTH_COPS_USER=cops
NGINX_BASIC_AUTH_COPS_PW=123456

#
# used by:
# - postifxadmin
# - mailserver (dovecot, amavis)
MYSQL_DB_PFA=pfa
MYSQL_PFA_USER=pfa
MYSQL_PFA_PASS=123456
SERVICE_USER_PFA=pfa
HTML_ROOT_PFA=/var/www/pfa
APPNAME_PFA=postfixadmin
PHP_OWNER_PFA=$SERVICE_USER_PFA
NGINX_VHOST_PATH_PFA="/etc/nginx/sites-available/pfa.conf"
POOL_CONF_PATH_PFA="/etc/php/7.0/fpm/pool.d/pfa.conf"
VHOST_SERVER_NAME_PFA=pfa.testorg.com
CALIBRE_LIBRARY=/vagrant
NGINX_BASIC_AUTH_PFA_FILE=pfa
NGINX_BASIC_AUTH_PFA_USER=pfa
NGINX_BASIC_AUTH_PFA_PW=123456
PFA_POSTMASTER=admin@$DOMAIN_NAME
PFA_POSTMASTER_PASSWORD=QAWS123
PFA_DOMAIN_NAME=$DOMAIN_NAME
PFA_DOMAIN_DESCRIPTION="$DOMAIN_NAME"
MAIL_ADMIN_PASSWORD=QAWS123

#
# used by:
# - mailserver
#
POSTMASTER_EMAIL=postmaster@$DOMAIN_NAME #will be used by $POSTMASTER_EMAIL and $POSTMASTER_AMAVIS
POSTFIX_MAILNAME=$HOST_NAME
POSTMASTER_DOVECOT=$POSTMASTER_EMAIL
# dovecot settings
DOVECOT_CONF=/etc/dovecot/dovecot-sql.conf.ext
DOVECOT_AUTH_CONF=/etc/dovecot/conf.d/10-auth.conf
DOVECOT_VMAIL_CONF=/etc/dovecot/conf.d/10-mail.conf
DOVECOT_SSL_CONF=/etc/dovecot/conf.d/10-ssl.conf
DOVECOT_MASTER_CONF=/etc/dovecot/conf.d/10-master.conf
DOVECOT_MAILBOXES_CONF=/etc/dovecot/conf.d/15-mailboxes.conf
DOVECOT_LDA_CONF=/etc/dovecot/conf.d/15-lda.conf
#amavis settings
AMAVIS_CONF=/etc/amavis/conf.d/15-content_filter_mode
AMAVIS_DEFAULTS_CONF=/etc/amavis/conf.d/20-debian_defaults
AMAVIS_USER_ACCESS_CONF=/etc/amavis/conf.d/50-user
POSTMASTER_AMAVIS=postmaster@$DOMAIN_NAME
AMAVIS_DOMAIN=$HOST_NAME


# spamassassin and postgrey settings
AMAVIS_LOCAL_DOMAINS_ACL="\"$DOMAIN_NAME\", \"$DOMAIN_NAME2\", \"localhost\"" # escape double quotes
SPAMASSASSIN_DOMAIN=$DOMAIN_NAME
SAPMASSASSIN_DEFAULT=/etc/default/spamassassin
SPAMASSASSIN_LOCAL=/etc/spamassassin/local.cf
POSTGREY_DEFAULT=/etc/default/postgrey
POSTGREY_BIND_HOST=127.0.0.1

#postifx configuration
POSTFIX_MYSQL_VIRTUAL_ALIAS_DOMAIN=/etc/postfix/mysql_virtual_alias_domainaliases_maps.cf
POSTIFX_MYSQL_VIRTUAL_ALIAS=/etc/postfix/mysql_virtual_alias_maps.cf
POSTIFX_MYSQL_VIRTUAL_DOMAINS=/etc/postfix/mysql_virtual_domains_maps.cf
POSTFIX_VIRTUAL_MAILBOX_DOMAIN_ALIAS=/etc/postfix/mysql_virtual_mailbox_domainaliases_maps.cf
POSTFIX_VIRTUAL_MAILBOX=/etc/postfix/mysql_virtual_mailbox_maps.cf
POSTFIX_VIRTUAL_SENDER=/etc/postfix/mysql_virtual_sender_login_maps.cf
POSTIFX_HEADERS=/etc/postfix/header_checks
POSTFIX_MAIN=/etc/postfix/main.cf
POSTFIX_MASTER=/etc/postfix/master.cf


#spf configuration
SPF_POLICY=/etc/postfix-policyd-spf-python/policyd-spf.conf


#dkim configuration
OPENDKIM_CONF=/etc/opendkim.conf
OPENDKIM_DOMAIN=$DOMAIN_NAME
OPENDKIM_DEFAULTS=/etc/default/opendkim


#dmarc configuration
DMARC_CONF=/etc/opendmarc.conf
DMARC_EMAIL=$POSTMASTER_EMAIL
DMARC_ID=$HOST_NAME
#fixed name by opendmarc sql scripts
MYSQL_DB_DMARC=opendmarc
MYSQL_DMARC_USER=dmarc
MYSQL_DMARC_PASS=123456
DMARC_IGNORE_DOMAINS=$DOMAIN_NAME,${DOMAIN_NAME2}
DMARC_IGNORE_HOSTS=/etc/opendmarc/ignore.hosts
DMARC_DEFAULTS=/etc/default/opendmarc
DMARC_REPORT_SCRIPT=/etc/opendmarc/report_script


#sieve configuration
DOVECOT_SIEVE=/etc/dovecot/conf.d/90-sieve.conf
SIEVE_VMAIL_DIR=/var/vmail/sieve


#
# used by:
# - gitlab
#
GITLAB_CONFIG=/etc/gitlab/gitlab.rb
NGINX_VHOST_PATH_GITLAB="/etc/nginx/sites-available/gitlab.conf"
VHOST_SERVER_NAME_GITLAB=git.testorg.com
APPNAME_GITLAB=gitlab
GITLAB_URL=https://$VHOST_SERVER_NAME_GITLAB/



#
# used by:
# - draw.io
#
SERVICE_USER_DRAW=drawio
HTML_ROOT_DRAW=/var/www/drawio
NGINX_VHOST_PATH_DRAW="/etc/nginx/sites-available/drawio.conf"
VHOST_SERVER_NAME_DRAW=draw.testorg.com
APPNAME_DRAW=drawio

#
# used by:
# - snakeoil cert
# - dh key
# - mailserver (dovecot)
COUNTRYNAME=DE
PROVINCENAME=Hamburg
KEY_LOCATION=Hamburg
KEY_ORGANIZATION=Organisation
KEY_OUN=IT
KEY_MAIL=webmaster@$DOMAIN_NAME
KEY_COMMON_NAME=$DOMAIN_NAME
SSL_PATH=/etc/ssl
CA_PASS=123456
SERVER_CERT_PASS=123456
SSL_CA_WITH_CRL_FULLCHAIN=${SSL_PATH}/servers/${KEY_COMMON_NAME}/fullchain.pem
TLS_KEY_FILE=${SSL_PATH}/servers/${KEY_COMMON_NAME}/privkey.pem
TLS_CERT_FILE=${SSL_PATH}/servers/${KEY_COMMON_NAME}/cert.pem
TLS_COMBINED=${SSL_PATH}/servers/${KEY_COMMON_NAME}/combined.pem
DH_PARAMS_FILE=${SSL_PATH}/servers/${KEY_COMMON_NAME}/dhparams.pem
KEY_SUBJ_ALT_NAME=(${VHOST_SERVER_NAME_MONIT} \
${VHOST_SERVER_NAME_PHPMYADMIN} \
${VHOST_SERVER_NAME_WEBMAIL} \
${VHOST_SERVER_NAME_WORDPRESS} \
${VHOST_SERVER_NAME_OWNCLOUD} \
${VHOST_SERVER_NAME_NEXTCLOUD} \
${VHOST_SERVER_NAME_BBS} \
${VHOST_SERVER_NAME_COPS} \
${VHOST_SERVER_NAME_PFA} \
${VHOST_SERVER_NAME_GITLAB} \
${VHOST_SERVER_NAME_DRAW})
