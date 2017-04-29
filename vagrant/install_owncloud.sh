#!/usr/bin/env bash

source /vagrant/environment.sh

$INSTALLER install -y software-properties-common php7.0 php7.0-common php7.0-mbstring php7.0-xmlwriter php7.0-mysql php7.0-intl php7.0-mcrypt php7.0-ldap php7.0-imap php7.0-cli php7.0-gd php7.0-json php7.0-curl php7.0-xmlrpc php7.0-zip libsm6 libsmbclient
$INSTALLER install -y php7.0-redis



#
# create database
#
cat << EOF > /tmp/createdb.sql
CREATE DATABASE IF NOT EXISTS $MYSQL_DB_OWNCLOUD;
GRANT ALL PRIVILEGES ON $MYSQL_DB_OWNCLOUD.* TO '$MYSQL_OWNCLOUD_USER'@'$MYSQL_DB_HOST' IDENTIFIED BY '$MYSQL_OWNCLOUD_PASS';
quit
EOF

mysql -uroot -p"$MYSQL_ROOT_PASS" -h"$MYSQL_DB_HOST" < /tmp/createdb.sql

if [ -f /tmp/createdb.sql ]; then
  rm -f /tmp/createdb.sql
fi


useradd --no-create-home "$SERVICE_USER_OWNCLOUD"
usermod --lock "$SERVICE_USER_OWNCLOUD"


# create www folder
if [ ! -d "$HTML_ROOT_OWNCLOUD" ]; then
  mkdir -p "$HTML_ROOT_OWNCLOUD"
fi

SOFTWARE_URL=https://download.owncloud.org/community/owncloud-9.1.5.tar.bz2
SOFTWARE_ZIP=$(basename $SOFTWARE_URL)


cd /tmp
wget $SOFTWARE_URL -O /tmp/"$SOFTWARE_ZIP"
tar -xjf  /tmp/"$SOFTWARE_ZIP"
cp -rT owncloud "$HTML_ROOT_OWNCLOUD"
if [ -f  /tmp/"$SOFTWARE_ZIP" ]; then
  rm -f /tmp/"$SOFTWARE_ZIP"
fi
if [ -d /tmp/owncloud ]; then
  rm -rf /tmp/owncloud
fi

chown -R $PHP_OWNER_OWNCLOUD:www-data "$HTML_ROOT_OWNCLOUD"
find "$HTML_ROOT_OWNCLOUD" -type d -exec chmod 750 {} \;
find "$HTML_ROOT_OWNCLOUD" -type f -exec chmod 640 {} \;



#
# write fpm pool
#
cat << OWNCLOUD_POOL > "$POOL_CONF_PATH_OWNCLOUD"
; ***********************************************************
; Explanations
; The number of PHP-FPM children that should be spawned automatically
; pm.start_servers =
; The maximum number of children allowed (connection limit)
; pm.max_children =
; The minimum number of spare idle PHP-FPM servers to have available
; pm.min_spare_servers =
; The maximum number of spare idle PHP-FPM servers to have available
; pm.max_spare_servers =
; Maximum number of requests each child should handle before re-spawning
; pm.max_requests =
; Maximum amount of time to process a request (similar to max_execution_time in php.ini
; request_terminate_timeout =
; ***********************************************************

;; $APPNAME_OWNCLOUD
[$APPNAME_OWNCLOUD]
env[HOSTNAME] = $HOST_NAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/$PHP_OWNER_OWNCLOUD.sock
listen.owner = $PHP_OWNER_OWNCLOUD
listen.group = www-data
listen.mode = 0660
user = $PHP_OWNER_OWNCLOUD
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/$PHP_OWNER_OWNCLOUD-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

;; middle sized owncloud / nextcloud pool
listen.backlog = 1024
pm = dynamic
pm.max_children = 30
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 6
pm.max_requests = 500
pm.process_idle_timeout = 150s
request_terminate_timeout = 150
php_value[max_input_time] = 150
php_value[max_execution_time] = 150
php_value[memory_limit] = 1512M
php_value[post_max_size] = 1512M
php_value[upload_max_filesize] = 1512M
OWNCLOUD_POOL


#
# write nginx vhost
#
cat << OWNCLOUD_VHOST > "$NGINX_VHOST_PATH_OWNCLOUD"
upstream owncloud {

	server unix:///run/php/$PHP_OWNER_OWNCLOUD.sock;
}

server {

	listen 80;
	server_name $VHOST_SERVER_NAME_OWNCLOUD;
	location / {

		return 301 https://\$server_name\$request_uri;
	}
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name $VHOST_SERVER_NAME_OWNCLOUD;
	root $HTML_ROOT_OWNCLOUD;
	access_log /var/log/nginx/$PHP_OWNER_OWNCLOUD-access.log;
	error_log /var/log/nginx/$PHP_OWNER_OWNCLOUD-error.log warn;

	ssl on;
	ssl_certificate $TLS_CERT_FILE;
	ssl_certificate_key $TLS_KEY_FILE;
	ssl_dhparam $DH_PARAMS_FILE;

	index index.php;

	include global/secure_ssl.conf;
	include global/restrictions.conf;


	# Additional rules go here.

	# if (\$allow_visit = no) { return 403 };

	add_header X-Content-Type-Options nosniff;
	add_header X-Frame-Options "SAMEORIGIN";
	add_header X-XSS-Protection "1; mode=block";
	add_header X-Robots-Tag none;
	add_header X-Download-Options noopen;
	add_header X-Permitted-Cross-Domain-Policies none;


	# The following 2 rules are only needed for the user_webfinger app.
	# Uncomment it if you're planning to use this app.
	#rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
	#rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json last;

	location = /.well-known/carddav {

		return 301 \$scheme://\$host/remote.php/dav;
	}

	location = /.well-known/caldav {

		return 301 \$scheme://\$host/remote.php/dav;
	}

	# set max upload size
	client_max_body_size 4096M;
	fastcgi_buffers 64 4K;

	# Disable gzip to avoid the removal of the ETag header
	gzip off;

	# Uncomment if your server is build with the ngx_pagespeed module
	# This module is currently not supported.
	# pagespeed off;
	error_page 403 /core/templates/403.php;
	error_page 404 /core/templates/404.php;

	location / {

		rewrite ^ /index.php\$uri;
	}

	location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {

		deny all;
	}

	location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {

		deny all;
	}

	location ~ ^/(?:index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|ocs-provider/.+|core/templates/40[34])\.php(?:$|/) {

		fastcgi_split_path_info ^(.+\.php)(/.*)$;
		include fastcgi_params;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		fastcgi_param PATH_INFO \$fastcgi_path_info;
		fastcgi_param HTTPS on;
		#Avoid sending the security headers twice
		fastcgi_param modHeadersAvailable true;
		fastcgi_param front_controller_active true;
		fastcgi_pass owncloud;
		fastcgi_intercept_errors on;
		fastcgi_request_buffering off;
	}

	location ~ ^/(?:updater|ocs-provider)(?:$|/) {

		try_files \$uri/ =404;
		index index.php;
	}

	# Adding the cache control header for js and css files
	# Make sure it is BELOW the PHP block
	location ~* \.(?:css|js)$ {

		try_files \$uri /index.php\$uri\$is_args\$args;
		add_header Cache-Control "public, max-age=7200";
		# Add headers to serve security related headers (It is intended to have those duplicated to the ones above)
		add_header X-Content-Type-Options nosniff;
		add_header X-Frame-Options "SAMEORIGIN";
		add_header X-XSS-Protection "1; mode=block";
		add_header X-Robots-Tag none;
		add_header X-Download-Options noopen;
		add_header X-Permitted-Cross-Domain-Policies none;
		# Optional: Don't log access to assets
		access_log off;
	}

	location ~* \.(?:svg|gif|png|html|ttf|woff|ico|jpg|jpeg)$ {

		try_files \$uri /index.php\$uri\$is_args\$args;
		# Optional: Don't log access to other assets
		access_log off;
	}
}
OWNCLOUD_VHOST


ln -s "$NGINX_VHOST_PATH_OWNCLOUD" /etc/nginx/sites-enabled/"$APPNAME_OWNCLOUD"


systemctl restart php7.0-fpm && systemctl restart nginx

# download files which can set permissions
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/setup_secure_permissions_owncloud.sh --no-check-certificate -O "$HTML_ROOT_OWNCLOUD"/set-secure-permission.sh
sed -i "s,OWNCLOUDPATH,$HTML_ROOT_OWNCLOUD," "$HTML_ROOT_OWNCLOUD"/set-secure-permission.sh
sed -i "s,HTUSER,$PHP_OWNER_OWNCLOUD," "$HTML_ROOT_OWNCLOUD"/set-secure-permission.sh
chmod +x "$HTML_ROOT_OWNCLOUD"/set-secure-permission.sh

wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/update_set_permission.sh --no-check-certificate -O "$HTML_ROOT_OWNCLOUD"/set-permission_update.sh
sed -i "s,OWNCLOUDPATH,$HTML_ROOT_OWNCLOUD," "$HTML_ROOT_OWNCLOUD"/set-permission_update.sh
chmod +x "$HTML_ROOT_OWNCLOUD"/set-permission_update.sh


# run the setup
su $PHP_OWNER_OWNCLOUD -s /bin/bash -c "php $HTML_ROOT_OWNCLOUD/occ maintenance:install -vvv --database mysql --database-name $MYSQL_DB_OWNCLOUD --database-table-prefix $TABLE_PREFIX_OWNCLOUD --database-user $MYSQL_OWNCLOUD_USER --database-pass $MYSQL_OWNCLOUD_PASS --admin-user admin --admin-pass admin"

# configuration
su $PHP_OWNER_OWNCLOUD -s /bin/bash -c "php $HTML_ROOT_OWNCLOUD/occ config:system:set trusted_domains 2 --value=$VHOST_SERVER_NAME_OWNCLOUD"
su $PHP_OWNER_OWNCLOUD -s /bin/bash -c "php $HTML_ROOT_OWNCLOUD/occ config:system:set overwrite.cli.url --value=https://$VHOST_SERVER_NAME_OWNCLOUD"

sed -i "s,UTC,$OWNCLOUD_TIMEZONE,"  "$HTML_ROOT_OWNCLOUD"/config/config.php

su $PHP_OWNER_OWNCLOUD -s /bin/bash -c "php $HTML_ROOT_OWNCLOUD/occ background:cron"

(crontab -l -u "$PHP_OWNER_OWNCLOUD"  2>/dev/null; echo "*/15 * * * * php $HTML_ROOT_OWNCLOUD/cron.php") | crontab -u "$PHP_OWNER_OWNCLOUD" -

sed -i '$ d' "$HTML_ROOT_OWNCLOUD"/config/config.php
{
echo "'filelocking.enabled' => true,
'memcache.local' => '\OC\Memcache\Redis',
'memcache.locking' => '\OC\Memcache\Redis',
'redis' => array(
   'host' => '$OWNCLOUD_REDIS_SOCKET',
   'port' => 0,
   'timeout' => 0.0,
   'password' => '$OWNCLOUD_REDIS_PASS',
    ),
);"
} >> "$HTML_ROOT_OWNCLOUD"/config/config.php

usermod --append --groups redis $SERVICE_USER_OWNCLOUD

bash "$HTML_ROOT_OWNCLOUD"/set-secure-permission.sh

systemctl restart php7.0-fpm

# TODO Default mail server
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpmode --value="smtp"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpauth --value="1"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpport --value="465"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtphost --value="smtp.gmail.com"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpauthtype --value="LOGIN"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_from_address --value="www.en0ch.se"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_domain --value="gmail.com"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpsecure --value="ssl"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpname --value="www.en0ch.se@gmail.com"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtppassword --value="techandme_se"' www-data
