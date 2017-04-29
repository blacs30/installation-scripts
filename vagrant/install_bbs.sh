#!/usr/bin/env bash

# load variables
source /vagrant/environment.sh

$INSTALLER install -y php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-gd php7.0-intl php7.0-json php7.0-mcrypt php7.0-opcache php7.0-sqlite3 php7.0-xml

useradd --no-create-home "$SERVICE_USER_BBS"
usermod --lock "$SERVICE_USER_BBS"


# create www folder
if [ ! -d "$HTML_ROOT_BBS" ]; then
  mkdir -p "$HTML_ROOT_BBS"
fi


BBSZIPFILEPATH=https://github.com/rvolz/BicBucStriim/archive/v1.3.6.zip
BBSZIPFILE=$(basename $BBSZIPFILEPATH)
BBSUNZIPNAME=BicBucStriim-$(echo "$BBSZIPFILE" | sed -r 's/v([0-9].[0-9].[0-9].?[0-9]?).zip/\1/')


cd /tmp
wget $BBSZIPFILEPATH
unzip "$BBSZIPFILE"
rm "$BBSZIPFILE"

cp -rT "$BBSUNZIPNAME" "$HTML_ROOT_BBS"
if [ -f /tmp/"$BBSUNZIPNAME" ]; then
  rm -f /tmp/"$BBSUNZIPNAME"
fi


# Set permissions to files and directories
chown -R "$SERVICE_USER_BBS":www-data "$HTML_ROOT_BBS"/
find "$HTML_ROOT_BBS" -type d -exec chmod 750 {} \;
find "$HTML_ROOT_BBS" -type f -exec chmod 640 {} \;


##########################
# Create the php fpm pool
##########################
cat << BBS_POOL > "$POOL_CONF_PATH_BBS"
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

;; $APPNAME_BBS
[$APPNAME_BBS]
env[HOSTNAME] = $HOST_NAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/$PHP_OWNER_BBS.sock
listen.owner = $PHP_OWNER_BBS
listen.group = www-data
listen.mode = 0660
user = $PHP_OWNER_BBS
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/$PHP_OWNER_BBS-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

listen.backlog = 64
pm = ondemand
pm.max_children = 5
pm.max_requests = 200
pm.process_idle_timeout = 10s
BBS_POOL



##########################
# Create the nginx vhost
##########################
cat << BBS_VHOST > "$NGINX_VHOST_PATH_BBS"
upstream bbs {

	server unix:///run/php/$PHP_OWNER_BBS.sock;
}

server {

	listen 80;
	server_name $VHOST_SERVER_NAME_BBS;
	location / {

		return 301 https://\$server_name\$request_uri;
	}
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name $VHOST_SERVER_NAME_BBS;
	root $HTML_ROOT_BBS;
	access_log /var/log/nginx/${PHP_OWNER_BBS}-access.log;
	error_log /var/log/nginx/${PHP_OWNER_BBS}-error.log warn;

	ssl on;
	ssl_certificate $TLS_CERT_FILE;
	ssl_certificate_key $TLS_KEY_FILE;
	ssl_dhparam $DH_PARAMS_FILE;

	index index.php;

	include global/secure_ssl.conf;
	include global/restrictions.conf;

	# if (\$allow_visit = no) { return 403 };

	location / {

		rewrite ^/(img/.*)$ /\$1 break;
		rewrite ^/(js/.*)$ /\$1 break;
		rewrite ^/(style/.*)$ /\$1 break;
		rewrite ^/$ /index.php last;
		rewrite ^/(admin|authors|authorslist|login|logout|metadata|search|series|serieslist|tags|tagslist|titles|titleslist|opds)/.*$ /index.php last;
	}

	location ~* \.(?:ico|css|js|gif|jpe?g|png|ttf|woff|svg|eot)$ {

		# Some basic cache-control for static files to be sent to the browser
		expires max;
		add_header Pragma public;
		add_header Cache-Control "public, must-revalidate, proxy-revalidate";
	}

	location ~ \.php$ {

		try_files \$uri \$uri/ /index.php;
		include fastcgi.conf;
		fastcgi_pass bbs;
	}
}

BBS_VHOST

ln -s "$NGINX_VHOST_PATH_BBS" /etc/nginx/sites-enabled/"$APPNAME_BBS"


systemctl restart php7.0-fpm && systemctl restart nginx
