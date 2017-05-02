#!/usr/bin/env bash

source /vagrant/environment.sh

$INSTALLER install -y php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-gd php7.0-json php7.0-mysql php7.0-opcache php7.0-readline
$INSTALLER install -y php7.0-redis


#
# create database
#
cat << EOF > /tmp/createdb.sql
CREATE DATABASE IF NOT EXISTS $MYSQL_DB_WORDPRESS;
GRANT ALL PRIVILEGES ON $MYSQL_DB_WORDPRESS.* TO '$MYSQL_WORDPRESS_USER'@'$MYSQL_DB_HOST' IDENTIFIED BY '$MYSQL_WORDPRESS_PASS';
quit
EOF

mysql -uroot -p"$MYSQL_ROOT_PASS" -h"$MYSQL_DB_HOST" < /tmp/createdb.sql

if [ -f /tmp/createdb.sql ]; then
  rm -f /tmp/createdb.sql
fi



useradd --no-create-home "$SERVICE_USER_WORDPRESS"
usermod --lock "$SERVICE_USER_WORDPRESS"


# create www folder
if [ ! -d "$HTML_ROOT_WORDPRESS" ]; then
  mkdir -p "$HTML_ROOT_WORDPRESS"
fi

SOFTWARE_URL=https://wordpress.org/latest.zip
SOFTWARE_ZIP=$(basename $SOFTWARE_URL)

wget $SOFTWARE_URL -O /tmp/"$SOFTWARE_ZIP"
unzip /tmp/"$SOFTWARE_ZIP"
cp -rT wordpress "$HTML_ROOT_WORDPRESS"/

if [ -d /tmp/wordpress ]; then
  rm -rf /tmp/wordpress
fi

if [ -f /tmp/"$SOFTWARE_ZIP" ]; then
  rm -f /tmp/"$SOFTWARE_ZIP"
fi


cp "$HTML_ROOT_WORDPRESS"/wp-config-sample.php "$HTML_ROOT_WORDPRESS"/wp-config.php
sed -i "s/^\$table_prefix.*;/\$table_prefix  = '$TABLE_PREFIX_WORDPRESS';/g" "$HTML_ROOT_WORDPRESS"/wp-config.php
sed -i "s/^define('DB_HOST', '.*');/define('DB_HOST', '$MYSQL_DB_HOST');/g" "$HTML_ROOT_WORDPRESS"/wp-config.php
sed -i "s/^define('DB_USER', '.*');/define('DB_USER', '$MYSQL_DB_WORDPRESS');/g" "$HTML_ROOT_WORDPRESS"/wp-config.php
sed -i "s/^define('DB_NAME', '.*');/define('DB_NAME', '$MYSQL_WORDPRESS_USER');/g" "$HTML_ROOT_WORDPRESS"/wp-config.php
sed -i "s/^define('DB_PASSWORD', '.*');/define('DB_PASSWORD', '$MYSQL_WORDPRESS_PASS');/g" "$HTML_ROOT_WORDPRESS"/wp-config.php

cat << EOF >> "$HTML_ROOT_WORDPRESS"/wp-config.php
/** Disallow theme editor for WordPress. */
define( 'DISALLOW_FILE_EDIT', true );
EOF

cat << EOF >> "$HTML_ROOT_WORDPRESS"/wp-config.php
/** Disallow error reportin for php. */
error_reporting(0);
@ini_set(‘display_errors’, 0);
EOF


perl -i -ne '
    BEGIN {
        $keysalts = qx(curl -sS https://api.wordpress.org/secret-key/1.1/salt)
    }
    if ( $flipflop = ( m/AUTH_KEY/ .. m/NONCE_SALT/ ) ) {
        if ( $flipflop =~ /E0$/ ) {
            printf qq|%s|, $keysalts;
        }
        next;
    }
    printf qq|%s|, $_;
' "$HTML_ROOT_WORDPRESS"/wp-config.php

sed -i "/^\$table_prefix.*/ a\\
\\
/** Redis config */ \\
define( 'WP_REDIS_CLIENT', 'pecl'); \\
define( 'WP_REDIS_SCHEME', 'unix'); \\
define( 'WP_REDIS_PATH', '$WORDPRESS_REDIS_SOCKET'); \\
define( 'WP_REDIS_DATABASE', '0'); \\
define( 'WP_REDIS_PASSWORD', '$WORDPRESS_REDIS_PASS'); \\
define( 'WP_REDIS_KEY_SALT', '${SERVICE_USER_WORDPRESS}_');" "$HTML_ROOT_WORDPRESS"/wp-config.php


# install plugins
for PLUGIN_URL in "${PLUGINS_URLS[@]}"
do
PLUGIN_ZIP=$(basename $PLUGIN_URL)
cd /tmp
wget $PLUGIN_URL
unzip -q /tmp/"$PLUGIN_ZIP" -d "$HTML_ROOT_WORDPRESS"/wp-content/plugins
if [ -f /tmp/"$PLUGIN_ZIP" ]; then
  rm -f /tmp/"$PLUGIN_ZIP"
fi
done



usermod --append --groups redis $SERVICE_USER_WORDPRESS

# create the uploads directory if it does not exist
if [ ! -d $HTML_ROOT_WORDPRESS/wp-content/uploads ]; then
  mkdir -p $HTML_ROOT_WORDPRESS/wp-content/uploads
fi

chown -R $SERVICE_USER_WORDPRESS:www-data $HTML_ROOT_WORDPRESS
find $HTML_ROOT_WORDPRESS -type d -exec chmod 750 {} \;
find $HTML_ROOT_WORDPRESS -type f -exec chmod 640 {} \;
chmod 600 $HTML_ROOT_WORDPRESS/wp-config.php


#
# write fpm pool
#
cat << WORDPRESS_POOL > "$POOL_CONF_PATH_WORDPRESS"
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

;; $APPNAME_WORDPRESS
[$APPNAME_WORDPRESS]
env[HOSTNAME] = $HOST_NAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/$PHP_OWNER_WORDPRESS.sock
listen.owner = $PHP_OWNER_WORDPRESS
listen.group = www-data
listen.mode = 0660
user = $PHP_OWNER_WORDPRESS
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/$PHP_OWNER_WORDPRESS-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

;; middle sized pool
listen.backlog = 512
pm = dynamic
pm.max_children = 30
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 6
pm.max_requests = 500
pm.process_idle_timeout = 60s
php_value[max_input_time] = 120
php_value[max_execution_time] = 120
php_value[memory_limit] = 50M
php_value[php_post_max_size] = 25M
php_value[upload_max_filesize] = 25M
WORDPRESS_POOL


#
# write nginx vhost
#
cat << WORDORESS_VHOST > "$NGINX_VHOST_PATH_WORDPRESS"
upstream wordpress {

	server unix:///run/php/$PHP_OWNER_WORDPRESS.sock;
}

server {

	listen 80;
	server_name $VHOST_SERVER_NAME_WORDPRESS;
	location / {

		return 301 https://\$server_name\$request_uri;
	}
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name $VHOST_SERVER_NAME_WORDPRESS;
	root $HTML_ROOT_WORDPRESS;
	access_log /var/log/nginx/${APPNAME_WORDPRESS}-access.log;
	error_log /var/log/nginx/${APPNAME_WORDPRESS}-error.log warn;

	ssl on;
	ssl_certificate $TLS_CERT_FILE;
	ssl_certificate_key $TLS_KEY_FILE;
	ssl_dhparam $DH_PARAMS_FILE;

	index index.php;

	include global/secure_ssl.conf;
	include global/restrictions.conf;
	include global/wordpress.conf;

	client_max_body_size 40M;
	index index.php;

	location = /xmlrpc.php {

		deny all;
		access_log off;
		log_not_found off;
	}

	# Pass all .php files onto a php-fpm/php-fcgi server.
	location ~ [^/]\.php(/|$) {

		fastcgi_split_path_info ^(.+?\.php)(/.*)$;
		try_files \$uri \$uri/ /index.php?args;
		include fastcgi.conf;
		fastcgi_index index.php;
		# fastcgi_intercept_errors on;
		fastcgi_pass wordpress;
	}


	# Secure wp-login.php requests
	location = /wp-login.php {

		# if (\$allow_visit = no) { return 403 };

		fastcgi_split_path_info ^(.+?\.php)(/.*)$;
		try_files \$uri \$uri/ /index.php?args;
		include fastcgi.conf;
		fastcgi_index index.php;
		# fastcgi_intercept_errors on;
		fastcgi_pass wordpress;
	}

	# Secure /wp-admin requests
	location ~ ^wp-admin {

		# if (\$allow_visit = no) { return 403 };
	}

	# Secure /wp-admin requests (allow admin-ajax.php)
	location ~* ^/wp-admin/admin-ajax.php$ {

		fastcgi_split_path_info ^(.+?\.php)(/.*)$;
		try_files \$uri \$uri/ /index.php?args;
		include fastcgi.conf;
		fastcgi_index index.php;
		# fastcgi_intercept_errors on;
		fastcgi_pass wordpress;
	}

	# Secure /wp-admin requests (.php files)
	location ~* ^/wp-admin/.*\.php {

	# if (\$allow_visit = no) { return 403 };

		fastcgi_split_path_info ^(.+?\.php)(/.*)$;
		try_files \$uri \$uri/ /index.php?args;
		include fastcgi.conf;
		fastcgi_index index.php;
		# fastcgi_intercept_errors on;
		fastcgi_pass wordpress;
	}
}
WORDORESS_VHOST


ln -s "$NGINX_VHOST_PATH_WORDPRESS" /etc/nginx/sites-enabled/"$APPNAME_WORDPRESS"


systemctl restart php7.0-fpm && systemctl restart nginx
