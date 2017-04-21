#!/usr/bin/env bash

# load variables
source /vagrant/environment.sh

$INSTALLER install -y php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-mcrypt php7.0-gd php7.0-json php7.0-mysql php7.0-opcache php7.0-readline php7.0-mbstring

useradd --no-create-home "$SERVICE_USER_PHPMYADMIN"
usermod --lock "$SERVICE_USER_PHPMYADMIN"

# create www folder
if [ ! -d "$HTML_ROOT_PHPMYADMIN" ]; then
  mkdir -p "$HTML_ROOT_PHPMYADMIN"
fi

SOFTWARE_URL=https://files.phpmyadmin.net/phpMyAdmin/4.7.0/phpMyAdmin-4.7.0-all-languages.zip
SOFTWARE_ZIP=$(basename $SOFTWARE_URL)
SOFTWARE_DIR=$(printf '%s' "$SOFTWARE_ZIP" | sed -e 's/.zip//')

wget $SOFTWARE_URL -O /tmp/"$SOFTWARE_ZIP"
cd /tmp && unzip /tmp/"$SOFTWARE_ZIP"
mkdir -p "$HTML_ROOT_PHPMYADMIN"/phpmyadmin
cp -rT "$SOFTWARE_DIR" "$HTML_ROOT_PHPMYADMIN"/phpmyadmin
if [ -d /tmp/"$SOFTWARE_DIR" ]; then
  rm -rf /tmp/"$SOFTWARE_DIR"
fi
if [ -f "$SOFTWARE_ZIP" ]; then
  rm -f "$SOFTWARE_ZIP"
fi

PHPMYADMIN_CONF="$HTML_ROOT_PHPMYADMIN"/phpmyadmin/config.inc.php
cp "$HTML_ROOT_PHPMYADMIN"/phpmyadmin/config.sample.inc.php "$PHPMYADMIN_CONF"

BLOWFISH_PASS=$(< /dev/urandom tr -dc "a-zA-Z0-9@#*=" | fold -w 32 | head -n 1)
sed -i "s/.*'blowfish_secret'.*/\$cfg['blowfish_secret'] = '$BLOWFISH_PASS';/g" "$PHPMYADMIN_CONF"
sed -i "s/localhost/127.0.0.1/g" "$PHPMYADMIN_CONF"
sed -i "/AllowNoPassword/a \$cfg['ForceSSL'] = 'true';" "$PHPMYADMIN_CONF"

# Set permissions to files and directories
chown -R "$SERVICE_USER_PHPMYADMIN":www-data "$HTML_ROOT_PHPMYADMIN"/
find "$HTML_ROOT_PHPMYADMIN" -type d -exec chmod 750 {} \;
find "$HTML_ROOT_PHPMYADMIN" -type f -exec chmod 640 {} \;

# create basic auth for nginx
htpasswd -b -c /etc/nginx/."${NGINX_BASIC_AUTH_PHPMYADMIN_FILE}" "${NGINX_BASIC_AUTH_PHPMYADMIN_USER}" "${NGINX_BASIC_AUTH_PHPMYADMIN_PW}"

##########################
# Create the php fpm pool
##########################
cat << PHPMYADMIN_POOL > "$POOL_CONF_PATH_PHPMYADMIN"
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

;; $APPNAME_PHPMYADMIN
[$APPNAME_PHPMYADMIN]
env[HOSTNAME] = $HOST_NAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/$PHP_OWNER_PHPMYADMIN.sock
listen.owner = $PHP_OWNER_PHPMYADMIN
listen.group = www-data
listen.mode = 0660
user = $PHP_OWNER_PHPMYADMIN
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/$PHP_OWNER_PHPMYADMIN-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

listen.backlog = 64
pm = ondemand
pm.max_children = 5
pm.max_requests = 200
pm.process_idle_timeout = 10s
PHPMYADMIN_POOL

##########################
# Create the nginx vhost
##########################
cat << PHPMYADMIN_VHOST > "$NGINX_VHOST_PATH_PHPMYADMIN"
upstream phpmyadmin {
server unix:///run/php/$PHP_OWNER_PHPMYADMIN.sock;
}

server {
listen 		80;
server_name     $VHOST_SERVER_NAME_PHPMYADMIN;
location / {
return 301 https://\$server_name\$request_uri;
}
}

server {
listen 					443 ssl http2;
listen          [::]:443 ssl http2;
server_name    	$VHOST_SERVER_NAME_PHPMYADMIN;
root   					$HTML_ROOT_PHPMYADMIN;
access_log     	/var/log/nginx/phpmyadmin-access.log;
error_log      	/var/log/nginx/phpmyadmin-error.log warn;

ssl    									on;
ssl_certificate        	/etc/ssl/${KEY_COMMON_NAME}.crt;
ssl_certificate_key    	/etc/ssl/${KEY_COMMON_NAME}.key;
ssl_dhparam             /etc/ssl/${KEY_COMMON_NAME}_dhparams.pem;

index                   index.php;

include                 global/secure_ssl.conf;
include                 global/restrictions.conf;
client_header_timeout   3m;

# Configure GEOIP access before enabling this setting
# if (\$allow_visit = no) { return 403 };

# Make sure files with the following extensions do not get loaded by nginx because nginx would display the source code, and these files can contain PASSWORDS!
location ~* \.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|tpl(\.php)?|xtmpl)$|^(\..*|Entries.*|Repository|Root|Tag|Template)$|\.php_ {
deny all;
}

location ~*  \.(jpg|jpeg|png|gif|css|js|ico)$ {
expires max;
log_not_found off;
}

location ~ \.php$ {
try_files \$uri =404;
include /etc/nginx/fastcgi_params;
fastcgi_pass phpmyadmin;
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
}

location /phpmyadmin {
auth_basic                    "Restricted";
auth_basic_user_file          /etc/nginx/.${NGINX_BASIC_AUTH_PHPMYADMIN_FILE};
index                         index.php index.html index.htm;

location ~ ^/phpmyadmin/(.+\.php)\$ {
try_files           \$uri =404;
fastcgi_param       HTTPS on;
fastcgi_pass        phpmyadmin;
fastcgi_index       index.php;
fastcgi_param       SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
include             fastcgi_params;
charset             utf8;
client_max_body_size  64m; #change this if ur export is bigger than 64mb.
client_body_buffer_size 128k;
}

location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
}
}

location /phpMyAdmin {
rewrite ^/* /phpmyadmin last;
}
}
PHPMYADMIN_VHOST

ln -s "$NGINX_VHOST_PATH_PHPMYADMIN" /etc/nginx/sites-enabled/"$APPNAME_PHPMYADMIN"

systemctl restart php7.0-fpm && systemctl restart nginx
