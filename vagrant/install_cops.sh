#!/usr/bin/env bash

# load variables
source /vagrant/environment.sh

$INSTALLER install -y php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-gd php7.0-intl php7.0-json php7.0-mcrypt php7.0-opcache php7.0-sqlite3 php7.0-xml php7.0-mbstring

useradd --no-create-home "$SERVICE_USER_COPS"
usermod --lock "$SERVICE_USER_COPS"


# create www folder
if [ ! -d "$HTML_ROOT_COPS" ]; then
  mkdir -p "$HTML_ROOT_COPS"
fi


COPSZIPFILEPATH=https://github.com/seblucas/cops/releases/download/1.1.0/cops-1.1.0.zip
COPSZIPFILE=$(basename $COPSZIPFILEPATH)


cd /tmp
wget $COPSZIPFILEPATH
unzip "$COPSZIPFILE" -d "$HTML_ROOT_COPS"
if [ -f "$COPSZIPFILE" ]; then
  rm "$COPSZIPFILE"
fi

# set the calibre directory
cp "$HTML_ROOT_COPS"/config_local.php.example "$HTML_ROOT_COPS"/config_local.php
sed -i "s,.*config\['calibre_directory'\] =.*;,\$config['calibre_directory'] = '$CALIBRE_LIBRARY/';," "$HTML_ROOT_COPS"/config_local.php

# Set permissions to files and directories
chown -R "$SERVICE_USER_COPS":www-data "$HTML_ROOT_COPS"/
find "$HTML_ROOT_COPS" -type d -exec chmod 750 {} \;
find "$HTML_ROOT_COPS" -type f -exec chmod 640 {} \;


##########################
# Create the php fpm pool
##########################
cat << COPS_POOL > "$POOL_CONF_PATH_COPS"
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

;; $APPNAME_COPS
[$APPNAME_COPS]
env[HOSTNAME] = $HOST_NAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/$PHP_OWNER_COPS.sock
listen.owner = $PHP_OWNER_COPS
listen.group = www-data
listen.mode = 0660
user = $PHP_OWNER_COPS
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/$PHP_OWNER_COPS-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

listen.backlog = 64
pm = ondemand
pm.max_children = 5
pm.max_requests = 200
pm.process_idle_timeout = 10s
COPS_POOL


# create basic auth for nginx
htpasswd -b -c /etc/nginx/."${NGINX_BASIC_AUTH_COPS_FILE}" "${NGINX_BASIC_AUTH_COPS_USER}" "${NGINX_BASIC_AUTH_COPS_PW}"


##########################
# Create the nginx vhost
##########################
cat << COPS_VHOST > "$NGINX_VHOST_PATH_COPS"
upstream cops {
server unix:///run/php/$PHP_OWNER_COPS.sock;
}

server {
listen 		80;
server_name     $VHOST_SERVER_NAME_COPS;
location / {
return 301 https://\$server_name\$request_uri;
}
}

server {
listen 					443 ssl http2;
listen          [::]:443 ssl http2;
server_name    	$VHOST_SERVER_NAME_COPS;
root   					$HTML_ROOT_COPS;
access_log     	/var/log/nginx/$PHP_OWNER_COPS-access.log;
error_log      	/var/log/nginx/$PHP_OWNER_COPS-error.log warn;

ssl    									on;
ssl_certificate        	/etc/ssl/${KEY_COMMON_NAME}.crt;
ssl_certificate_key    	/etc/ssl/${KEY_COMMON_NAME}.key;
ssl_dhparam             /etc/ssl/${KEY_COMMON_NAME}_dhparams.pem;

include                 global/secure_ssl.conf;
include                 global/restrictions.conf;
index 									feed.php;

# if (\$allow_visit = no) { return 403 };

location ~* \.(?:ico|css|js|gif|jpe?g|png|ttf|woff|svg|eot)$ {
# Some basic cache-control for static files to be sent to the browser
expires max;
add_header Pragma public;
add_header Cache-Control "public, must-revalidate, proxy-revalidate";
}

location ~ \.php$ {
auth_basic                    "Restricted";
auth_basic_user_file          /etc/nginx/.${NGINX_BASIC_AUTH_COPS_FILE};
try_files \$uri \$uri/ /index.php;
include fastcgi.conf;
fastcgi_pass   cops;
}

location /Calibre {
root $CALIBRE_LIBRARY;
internal;
}
}
COPS_VHOST

ln -s "$NGINX_VHOST_PATH_COPS" /etc/nginx/sites-enabled/"$APPNAME_COPS"


systemctl restart php7.0-fpm && systemctl restart nginx
