#!/bin/bash
# Install wordpress with
# mysql
# install redis
# install nginx
# install php7-fpm

# Check if parameter setup is set
# redis cache
# https://serverpilot.io/community/articles/how-to-install-the-php-redis-extension.html
# https://wordpress.org/plugins/redis-cache/
# apt-get install php7.0-dev
# pecl install redis
if [ "$1" != "" ] && [ "$1" == "setup" ]; then
        echo "start setup"
else
        echo "exit setup:
        REMINDER: adjust setup vars and start with parameter: setup"
        exit 1
fi

export SHUF=$(shuf -i 13-15 -n 1)
export MYSQL_ROOT_PASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
export DB_HOST=localhost
export WEBMASTER_MAIL=webmaster@example.com
export WP_DB_NAME=wp_example
export WP_DB_USER=wp_user
export WP_DB_PASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
export TABLE_PREFIX=wp_tp_
export SCRIPTS=/var/scripts
export HTML=/var/www
export DOMAIN=wordpress.example.com
export POOL_NAME=wpexample
export SSLPATH=$HTML/letsencrypt
export WWWPATHHTML=$HTML/$DOMAIN/public_html
export WWWLOGDIR=$HTML/log
export PERMISSIONFILES=$HTML/permissions
export WPZIPFILEPATH=https://wordpress.org/latest.zip
export WPZIPFILE=latest.zip
export GOTMLSURL=https://downloads.wordpress.org/plugin/gotmls.4.16.17.zip
export GOTMLSFILE=gotmls.4.16.17.zip
export BETTERWPSECURL=https://downloads.wordpress.org/plugin/better-wp-security.5.4.5.zip
export BETTERWPSECFILE=better-wp-security.5.4.5.zip
export REDISCACHEURL=https://downloads.wordpress.org/plugin/redis-cache.1.3.2.zip
export REDISCACHEFILE=redis-cache.1.3.2.zip
export VHOST_CONF_DIR=/etc/nginx/sites-available
export PHP_TIMEZONE=Europe/Berlin
export REDIS_PASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
export VHOST_CONF_FILE=$DOMAIN
export VHOST_CONF_PATH=$VHOST_CONF_DIR/$VHOST_CONF_FILE


echo "Check if you are root"
        if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msu root -c 'bash $SCRIPTS/install_wordpress.sh'"
        echo
        exit 1
fi

cd /tmp

echo "Install aptitude"
apt-get update && apt-get install aptitude wget -y

echo "
deb http://mirrors.linode.com/debian/ jessie main contrib non-free
deb-src http://mirrors.linode.com/debian/ jessie main contrib non-free

deb http://security.debian.org/ jessie/updates main contrib non-free
deb-src http://security.debian.org/ jessie/updates main non-free

# jessie-updates, previously known as 'volatile'
deb http://mirrors.linode.com/debian/ jessie-updates main contrib non-free
deb-src http://mirrors.linode.com/debian/ jessie-updates main contrib non-free

deb http://packages.dotdeb.org jessie all
deb-src http://packages.dotdeb.org jessie all
" >> /etc/apt/sources.list

wget https://www.dotdeb.org/dotdeb.gpg
apt-key add dotdeb.gpg
rm dotdeb.gpg

echo "Update repos"
aptitude update

echo "Set mysql root password"
echo mysql-server mysql-server/root_password password $MYSQL_ROOT_PASS | debconf-set-selections
echo mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASS | debconf-set-selections

echo "Install software"
aptitude install -y unzip \
                    curl \
                    ed  \
                    mysql-server \
                    redis-server \
                    expect \
                    nginx \
                    geoip-database \
                    libgeoip1 \
                    php-common \
                    php-readline \
                    php7.0 \
                    php7.0-cli \
                    php7.0-common \
                    php7.0-gd \
                    php7.0-json \
                    php7.0-mysql \
                    php7.0-opcache \
                    php7.0-redis  \
                    php7.0-readline \
                    php7.0-fpm

echo "Configure redis-server for using socket end set password"
sed -i 's/^port .*/port 0/' /etc/redis/redis.conf
echo 'unixsocket /var/run/redis/redis.sock' >> /etc/redis/redis.conf
echo 'unixsocketperm 770' >> /etc/redis/redis.conf
sed -i "/requirepass .*/c\requirepass $REDIS_PASS" /etc/redis/redis.conf

[[ ! -d /var/run/redis  ]] && mkdir /var/run/redis
chown redis:redis /var/run/redis
chmod 755 /var/run/redis

echo "Configure php fpm"
mv /etc/php/7.0/fpm/pool.d/www.conf /etc/php/7.0/fpm/pool.d/www.off
sed -i "s,.*date.timezone =.*,date.timezone = $PHP_TIMEZONE,g" /etc/php/7.0/fpm/php.ini
sed -i 's/;opcache.enable=0/opcache.enable=1/g' /etc/php/7.0/fpm/php.ini
sed -i 's;pid =.*;pid = /var/run/php/php7.0-fpm.pid;g' /etc/php/7.0/fpm/php-fpm.conf
sed -i 's/;events.mechanism = epoll.*/events.mechanism = epoll/g' /etc/php/7.0/fpm/php-fpm.conf
sed -i 's/;emergency_restart_threshold.*/emergency_restart_threshold = 10/g' /etc/php/7.0/fpm/php-fpm.conf
sed -i 's/;emergency_restart_interval.*/emergency_restart_interval = 1m/g' /etc/php/7.0/fpm/php-fpm.conf
sed -i 's/;process_control_timeout.*/process_control_timeout = 10s/g' /etc/php/7.0/fpm/php-fpm.conf
sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo = 0/g' /etc/php/7.0/fpm/php.ini
sed -i 's,error_log =.*,error_log = /var/log/php/php7.0-fpm.log,g' /etc/php/7.0/fpm/php-fpm.conf

echo "create separate service user"
groupadd $POOL_NAME
useradd -g $POOL_NAME $POOL_NAME

echo "Add redis to webserver group"
usermod -aG redis www-data
usermod -aG redis $POOL_NAME

echo "download latest geoip database"
mv /usr/share/GeoIP/GeoIP.dat /usr/share/GeoIP/GeoIP.dat_bak
cd /usr/share/GeoIP/
wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
gunzip GeoIP.dat.gz
cd /tmp

echo "Start mysql server"
service mysql restart

echo "Run expect for mysql_secure_installation"
export SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root:\"
send \"$MYSQL_ROOT_PASS\r\"
expect \"Would you like to setup VALIDATE PASSWORD plugin?\"
send \"n\r\"
expect \"Change the password for root ?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
echo "$SECURE_MYSQL"
unset SECURE_MYSQL
echo "Remove expect and config files"
aptitude -y purge expect

echo "Configure nginx"
sed -i "/http {/a include \/etc\/nginx\/global\/geoip_settings.conf;"        /etc/nginx/nginx.conf
sed -i "s,worker_processes.*;,worker_processes 2;," /etc/nginx/nginx.conf
sed -i "s,worker_connections.*,worker_connections 1024;," /etc/nginx/nginx.conf
sed -i "s,# server_tokens off;,server_tokens off;," /etc/nginx/nginx.conf
[[ ! -d /etc/nginx/global ]] && mkdir /etc/nginx/global
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/geoip_settings.conf -O /etc/nginx/global/geoip_settings.conf
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/restrictions.conf -O /etc/nginx/global/restrictions.conf
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/secure_ssl.conf -O /etc/nginx/global/secure_ssl.conf
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/wordpress.conf -O /etc/nginx/global/wordpress.conf

echo "create directory for application"
[[ ! -d $WWWPATHHTML ]] && mkdir -p $WWWPATHHTML
[[ ! -d $WWWLOGDIR ]] && mkdir -p $WWWLOGDIR
[[ ! -d $SSLPATH ]] && mkdir -p $SSLPATH
[[ ! -d $PERMISSIONFILES ]] && mkdir -p $PERMISSIONFILES
[[ ! -d /var/run/php ]] && mkdir -p /var/run/php
[[ ! -d /var/log/php ]] && mkdir -p /var/log/php

echo "create mysql database and user"
echo "CREATE USER '$WP_DB_USER'@'localhost' IDENTIFIED BY '$WP_DB_PASS';
CREATE DATABASE IF NOT EXISTS $WP_DB_NAME;
GRANT ALL PRIVILEGES ON $WP_DB_NAME.* TO '$WP_DB_USER'@'localhost' IDENTIFIED BY '$WP_DB_PASS';
quit" >> /tmp/$DOMAIN-createdb.sql
cat /tmp/$DOMAIN-createdb.sql | mysql -u root -p$MYSQL_ROOT_PASS
if [ $? -eq 0 ]; then
rm -rf /tmp/$DOMAIN-createdb.sql
fi

echo "Disable nginx default config"
[[ -f /etc/nginx/sites-enabled/default ]] && rm -rf /etc/nginx/sites-enabled/default

echo "Check if vhost alreay exists otherwise create it"
CONFIGEXIST=$(find $VHOST_CONF_DIR -type f -name "*$DOMAIN*"  | wc -l)
if [ "$CONFIGEXIST" -lt "1" ];
        then
        echo "Virtual Host exists"
      touch "$VHOST_CONF_PATH"
      cat << VHOST_CREATE > "$VHOST_CONF_PATH"

upstream $POOL_NAME {
        server unix:///var/run/php/$POOL_NAME.sock;
}

server {
        listen 		80;
        # enforce https
        server_name     $DOMAIN www.$DOMAIN;
        location ~ .well-known/acme-challenge/ {
          root /var/www/letsencrypt;
          default_type text/plain;
        }
        location / {
            return301 https://\$server_name\$request_uri;
        }
}

server {
       	listen 		443 ssl http2;
       	listen          [::]:443 ssl http2;
       	server_name    	$DOMAIN www.$DOMAIN;
       	root   		$WWWPATHHTML;
        access_log     	$WWWLOGDIR/$POOL_NAME-access.log;
        error_log      	$WWWLOGDIR/$POOL_NAME-error.log warn;

        ssl    			on;
       	ssl_certificate        	$SSLPATH/$DOMAIN.crt;
       	#ssl_certificate        	/etc/letsencrypt/live/www.$DOMAIN/fullchain.pem;
       	ssl_certificate_key    	$SSLPATH/$DOMAIN.key;
       	#ssl_certificate_key    	/etc/letsencrypt/live/www.$DOMAIN/privkey.pem;
       	ssl_dhparam    		      $SSLPATH/$POOL_NAME-dhparams.pem;
        include			            global/secure_ssl.conf;
       	include        		      global/restrictions.conf;

       	index  			index.php;

       	# Additional rules go here.

location = /xmlrpc.php {
       	deny all;
       	access_log off;
       	log_not_found off;
}

       	include        	global/wordpress.conf;

# Pass all .php files onto a php-fpm/php-fcgi server.
location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        try_files \$uri \$uri/ /index.php?args;
       	include fastcgi.conf;
        fastcgi_index index.php;
 #      fastcgi_intercept_errors on;
        fastcgi_pass $POOL_NAME;
}

       	# Secure wp-login.php requests
       	location = /wp-login.php {
        if (\$allow_visit = no) {
                return 403;
        }
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        try_files \$uri \$uri/ /index.php?args;
        include fastcgi.conf;
        fastcgi_index index.php;
 #      fastcgi_intercept_errors on;
        fastcgi_pass $POOL_NAME;
        }

       	# Secure /wp-admin requests
       	location ~ ^wp-admin {
       	if (\$allow_visit = no) {
       		return 403;
       	}
       	}

       	# Secure /wp-admin requests (allow admin-ajax.php)
       	location ~* ^/wp-admin/admin-ajax.php$ {

       	fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        try_files \$uri \$uri/ /index.php?args;
        include fastcgi.conf;
        fastcgi_index index.php;
 #      fastcgi_intercept_errors on;
        fastcgi_pass $POOL_NAME;
       	}

       	# Secure /wp-admin requests (.php files)
       	location ~* ^/wp-admin/.*\.php {

        if (\$allow_visit = no) {
             return 403;
        }
       	fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        try_files \$uri \$uri/ /index.php?args;
        include fastcgi.conf;
        fastcgi_index index.php;
 #      fastcgi_intercept_errors on;
        fastcgi_pass $POOL_NAME;
        }
}
VHOST_CREATE
echo "$VHOST_CONF_PATH was successfully created"
sleep 3
fi

echo "enable vhost"
ln -s $VHOST_CONF_PATH /etc/nginx/sites-enabled/$DOMAIN

echo "Create php fpm pool"
pool=$POOL_NAME
cat <<EOM > /etc/php/7.0/fpm/pool.d/$pool.conf
;; $DOMAIN
[$pool]
env[HOSTNAME] = \$HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
listen = /var/run/php/$pool.sock
listen.owner = $pool
listen.group = www-data
listen.mode = 0660
user = $pool
group = $pool
request_slowlog_timeout = 5s
slowlog = /var/log/php/slowlog-$pool.log
listen.backlog = -1

pm = dynamic
;  The number of PHP-FPM children that should be spawned automatically
pm.start_servers = 3
; The maximum number of children allowed (connection limit)
pm.max_children = 9
; The minimum number of spare idle PHP-FPM servers to have available
pm.min_spare_servers = 2
; The maximum number of spare idle PHP-FPM servers to have available
pm.max_spare_servers = 4
; Maximum number of requests each child should handle before re-spawning
pm.max_requests = 200
; Maximum amount of time to process a request (similar to max_execution_time in php.ini
request_terminate_timeout = 300

php_value[memory_limit] = 96M
php_value[max_execution_time] = 120
php_value[max_input_time] = 300
php_value[php_post_max_size] = 25M
php_value[upload_max_filesize] = 25M
EOM

#########
### start
#########
## big sites with owncloud
#-- pm = dynamic
#-- pm.max_children = 30
#-- pm.start_servers = 2
#-- pm.min_spare_servers = 2
#-- pm.max_spare_servers = 6
#-- pm.max_requests = 300
#-- pm.process_idle_timeout = 300s
#-- request_terminate_timeout = 300
#-- php_value[max_execution_time] = 300
#-- php_value[max_input_time] = 300
#-- php_value[memory_limit] = 4096M
#-- php_value[post_max_size] = 4096M
#-- php_value[upload_max_filesize] = 4096M

## big sites with wordpress
#-- pm = dynamic
#-- pm.max_children = 40
#-- pm.start_servers = 10
#-- pm.min_spare_servers = 5
#-- pm.max_spare_servers = 10
#-- pm.max_requests = 1000
#-- pm.process_idle_timeout = 120s
#-- request_terminate_timeout = 120
#-- php_value[max_input_time] = 120
#-- php_value[max_execution_time] = 120
#-- php_value[memory_limit] = 50M
#-- php_value[post_max_size] = 40M
#-- php_value[upload_max_filesize] = 40M

## normal sites
#-- pm = dynamic
#-- pm.max_children = 16
#-- pm.process_idle_timeout = 60s
#-- pm.start_servers = 2
#-- pm.min_spare_servers = 2
#-- pm.max_spare_servers = 2
#-- pm.max_requests = 500

## small sites
#-- pm = ondemand
#-- pm.max_children = 5
#-- pm.process_idle_timeout = 10s
#-- pm.max_requests = 200
#-- ########
##  end
########

echo "Download and unzip application"
cd /tmp
wget $WPZIPFILEPATH
unzip $WPZIPFILE
rm -rf $WPZIPFILE

echo "copy wordpress to target location"
cp -rT wordpress $WWWPATHHTML/

echo "Adjust wordpress config file"
cp $WWWPATHHTML/wp-config-sample.php $WWWPATHHTML/wp-config.php
sed -i "s/^\$table_prefix.*;/\$table_prefix  = '$TABLE_PREFIX';/g" $WWWPATHHTML/wp-config.php
sed -i "s/^define('DB_HOST', '.*');/define('DB_HOST', '$DB_HOST');/g" $WWWPATHHTML/wp-config.php
sed -i "s/^define('DB_USER', '.*');/define('DB_USER', '$WP_DB_USER');/g" $WWWPATHHTML/wp-config.php
sed -i "s/^define('DB_NAME', '.*');/define('DB_NAME', '$WP_DB_NAME');/g" $WWWPATHHTML/wp-config.php
sed -i "s/^define('DB_PASSWORD', '.*');/define('DB_PASSWORD', '$WP_DB_PASS');/g" $WWWPATHHTML/wp-config.php
echo "
/** Disallow theme editor for WordPress. */
define( 'DISALLOW_FILE_EDIT', true );" >> $WWWPATHHTML/wp-config.php

echo "
/** Disallow error reportin for php. */
error_reporting(0);
@ini_set(‘display_errors’, 0);" >> $WWWPATHHTML/wp-config.php

SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s $WWWPATHHTML/wp-config.php

echo "Download and install security plugins"
cd /tmp
wget $BETTERWPSECURL
wget $GOTMLSURL
wget $REDISCACHEURL
unzip -q $REDISCACHEFILE -d $WWWPATHHTML/wp-content/plugins
unzip -q $BETTERWPSECFILE -d $WWWPATHHTML/wp-content/plugins
unzip -q $GOTMLSFILE -d $WWWPATHHTML/wp-content/plugins

echo "Install redis object cache plugin for wordpress"
sed -i "/^\$table_prefix.*/ a\\
\\
/** Redis config */ \\
define( 'WP_REDIS_CLIENT', 'pecl'); \\
define( 'WP_REDIS_SCHEME', 'unix'); \\
define( 'WP_REDIS_PATH', '/var/run/redis/redis.sock'); \\
define( 'WP_REDIS_DATABASE', '0'); \\
define( 'WP_REDIS_PASSWORD', '$REDIS_PASS'); \\
define( 'WP_REDIS_KEY_SALT', '${POOL_NAME}_');" $WWWPATHHTML/wp-config.php

echo "write permission file for wordpress permissions"
echo "
[[ ! -d $WWWPATHHTML/wp-content/uploads ]] && \
mkdir -p $WWWPATHHTML/wp-content/uploads
chown -R $POOL_NAME:www-data $WWWPATHHTML/
find $WWWPATHHTML -type d -exec chmod 755 {} \;
find $WWWPATHHTML -type f -exec chmod 644 {} \;
" > $PERMISSIONFILES/$DOMAIN-permission.sh

echo "set permissions for wordpress"
bash $PERMISSIONFILES/$DOMAIN-permission.sh

# create self signed certs
echo "create self signed certificates"
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096  \
    -subj "/C=DE/ST=Hamburg/L=NS/O=Local/OU=Development/CN=$DOMAIN/emailAddress=$WEBMASTER_MAIL" \
    -keyout $SSLPATH/$DOMAIN.key \
    -out $SSLPATH/$DOMAIN.crt

# create diffie-helman group
echo "Create diffie-helman group"
openssl dhparam -out $SSLPATH/$POOL_NAME-dhparams.pem 2048

# Set secure permissions to certificate key
echo "Set secure permissions for certificate key"
chmod 600 $SSLPATH/$DOMAIN.key
chmod 600 $SSLPATH/$POOL_NAME-dhparams.pem

# Restart apache and mysql
echo "restart apache and mysql"
service mysql restart
service nginx start
service php7.0-fpm start
service redis-server start

# Write mysql root password to file - keep it save
echo "Write root password into file /var/scripts/m-r-pass.txt, keep it safe"
echo $MYSQL_ROOT_PASS >> $SCRIPTS/$DOMAIN-pass.txt
echo $REDIS_PASS >> $SCRIPTS/$DOMAIN-pass.txt
echo $WP_DB_PASS >> $SCRIPTS/$DOMAIN-pass.txt
chmod 600 $SCRIPTS/$DOMAIN-pass.txt

echo "Installation succeded.."

# remove wordpress downloaded file after the last installation
rm -rf /tmp/wordpress
