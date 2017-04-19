#!/usr/bin/env bash

INSTALLER=aptitude
SERVICE_USER=phpmyadmin
PHPOWNER=phpmyadmin
POOL_CONF_PATH="/etc/php/7.0/fpm/pool.d/phpmyadmin.conf"
NGINX_VHOST_PATH="/etc/sites-available/phpmyadmin.conf"

$INSTALLER install -y php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-mcrypt php7.0-gd php7.0-json php7.0-mysql php7.0-opcache php7.0-readline php7.0-mbstring

useradd --no-create-home "$SERVICE_USER"
usermod --lock "$SERVICE_USER"

cat << PHPMYADMIN_POOL > "$POOL_CONF_PATH"
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

;; $PHPOWNER
[$PHPOWNER]
env[HOSTNAME] = \$(hostname)
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = unix:///run/php/$PHPOWNER.sock
listen.owner = $PHPOWNER
listen.group = www-data
listen.mode = 0660
user = $PHPOWNER
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/slowlog-$PHPOWNER.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

listen.backlog = 64
pm = ondemand
pm.max_children = 5
pm.max_requests = 200
pm.process_idle_timeout = 10s
PHPMYADMIN_POOL


cat << PHPMYADMIN_VHOST > "$NGINX_VHOST_PATH"
upstream $pool_name {
server $listen_pool;
}

server {
listen 		80;
# enforce https
server_name     $ALL_DOMAINS;
location ~ .well-known/acme-challenge/ {
root 						$LE_KNOWN_DIR;
default_type 		text/plain;
}
location / {
return 301 https://\$server_name\$request_uri;
}
}

server {
listen 					443 ssl http2;
listen          [::]:443 ssl http2;
server_name    	$ALL_DOMAINS;
root   					$WWWPATHHTML;
access_log     	$WWWLOGDIR/$DOMAIN_PART-access.log;
error_log      	$WWWLOGDIR/$DOMAIN_PART-error.log warn;

ssl    									on;
ssl_certificate        	$SSL_CERT;
#ssl_certificate        $CERTS_PATH/www.$DOMAIN_PART/fullchain.pem;
ssl_certificate_key    	$SSL_KEY;
#ssl_certificate_key    $CERTS_PATH/www.$DOMAIN_PART/privkey.pem;
ssl_dhparam    		      $CERTS_PATH/${DOMAIN_PART}_dhparams.pem;

include			            global/secure_ssl.conf;

# Additional rules go here.
include        		      global/restrictions.conf;
index                   index.php;

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
fastcgi_pass $pool_name;
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
}
}
PHPMYADMIN_VHOST
