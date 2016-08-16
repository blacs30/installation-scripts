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
        echo "stop setup:
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
export WWWPATH=$HTML/$DOMAIN
export SSLPATH=$HTML/ssl
export WWWPATHHTML=$HTML/$DOMAIN/public_html
export WWWLOGDIR=$HTML/log
export WPZIPFILEPATH=https://wordpress.org/latest.zip
export WPZIPFILE=latest.zip
# Wordpress security plugins
export GOTMLSURL=https://downloads.wordpress.org/plugin/gotmls.4.16.17.zip
export GOTMLSFILE=gotmls.4.16.17.zip
export BETTERWPSECURL=https://downloads.wordpress.org/plugin/better-wp-security.5.4.5.zip
export BETTERWPSECFILE=better-wp-security.5.4.5.zip
export VHOST_CONF_DIR=/etc/nginx/sites-available

# Check if root
        if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msu root -c 'bash $SCRIPTS/install_wordpress.sh'"
        echo
        exit 1
fi

# Install aptitude
echo "Install aptitude"
apt-get update
apt-get install aptitude -y

# Update system
echo "Update aptitude repos"
aptitude update

# Install base software
echo "Install base software"
aptitude install -y wget \
                    unzip \
                    curl \
                    ed

# set mysql password to debconf as prerequisite for the installation
echo "Set mysql root password"
echo mysql-server mysql-server/root_password password $MYSQL_ROOT_PASS | debconf-set-selections
echo mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASS | debconf-set-selections

# Install Mysql
echo "Install mysql"
aptitude install -y mysql-server

# Start mysql server
echo "Start mysql server"
service mysql restart

# install expect
echo "Install expect"
aptitude -y install expect

# mysql_secure_installation
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

apt-get install nginx

sed -i "s,worker_processes.*;,worker_processes 2;," /etc/nginx/nginx.conf
sed -i "s,worker_connections.*,worker_connections 1024;," /etc/nginx/nginx.conf
sed -i "s,# server_tokens off;,server_tokens off;," /etc/nginx/nginx.conf

# Install PHP 7
echo "Install php7"
echo "deb http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list
echo "deb-src http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list
wget https://www.dotdeb.org/dotdeb.gpg
apt-key add dotdeb.gpg
rm dotdeb.gpg
aptitude update
aptitude install -y libapache2-mod-php7.0 \
                    php-common \
                    php-readline \
                    php7.0 \
                    php7.0-cli \
                    php7.0-common \
                    php7.0-gd \
                    php7.0-json \
                    php7.0-mysql \
                    php7.0-opcache \
                    php7.0-readline

# create directory for website and logs for vhost
echo "create directory for application"
mkdir -p $WWWPATHHTML
mkdir -p $WWWLOGDIR
mkdir -p $SSLPATH

# create mysql database and user
echo "create mysql database and user"
echo "CREATE USER '$WP_DB_USER'@'localhost' IDENTIFIED BY '$WP_DB_PASS';
CREATE DATABASE IF NOT EXISTS $WP_DB_NAME;
GRANT ALL PRIVILEGES ON $WP_DB_NAME.* TO '$WP_DB_USER'@'localhost' IDENTIFIED BY '$WP_DB_PASS';
quit" >> /tmp/$DOMAIN-createdb.sql
cat /tmp/$DOMAIN-createdb.sql | mysql -u root -p$MYSQL_ROOT_PASS
if [ $? -eq 0 ]; then
rm -rf /tmp/$DOMAIN-createdb.sql
fi

# Disable default page
echo "Disable nginx default config"
[[ -f /etc/nginx/sites-enabled/default.conf ]] && \
rm -rf /etc/nginx/sites-enabled/default.conf

# count number of available sites
echo "Check if vhost config exists"
siteCount=$(ls -1 /etc/apache2/sites-enabled/ | wc -l)
siteCountIncremented=$(printf "%03d" $((siteCount+1)))
VHOST_CONF_FILE=$siteCountIncremented-$DOMAIN.conf
VHOST_CONF_PATH=$VHOST_CONF_DIR/$VHOST_CONF_FILE

# Check if vhost config already exist for the given domain
CONFIGEXIST=$(find /etc/apache2/sites-available -type f -name "*$DOMAIN*"  | wc -l)

# Generate Nginx directory and vhost config $VHOST_CONF_PATH
# if vhost config does not exist
echo "Create apache vhost config files"
if [ "$CONFIGEXIST" -lt "1" ];
        then
        echo "Virtual Host exists"
      touch "$VHOST_CONF_PATH"
      cat << VHOST_CREATE > "$VHOST_CONF_PATH"
# Forward everything to port 80
<VirtualHost *:80>
  ServerName $DOMAIN
  Redirect permanent / https://$DOMAIN/
  CustomLog $WWWLOGDIR/access.log combined
  ErrorLog $WWWLOGDIR/error.log
</VirtualHost>

<VirtualHost *:443>
<IfModule mod_headers.c>
   Header always set Strict-Transport-Security "max-age=15768000; includeSubDomains; preload"
 </IfModule>
   SSLEngine on
   # settings for self signed certificates
   SSLCipherSuite HIGH:MEDIUM
   SSLCertificateFile $SSLPATH/$DOMAIN.crt
   SSLCertificateKeyFile  $SSLPATH/$DOMAIN.key

   # settings for letsencrypt certificates
   # SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem
   # SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem
   # SSLCertificateChainFile /etc/letsencrypt/live/$DOMAIN/chain.pem
   # Include /etc/letsencrypt/options-ssl-apache.conf

   # Protect against Logjam attacks. See: https://weakdh.org
   # Not yet in Jessie 8.4 openssl 1.0.1t available
   # SSLOpenSSLConfCmd DHParameters "$SSLPATH/dhparams.pem"

   ### YOUR SERVER ADDRESS ###
       ServerAdmin $WEBMASTER_MAIL
       ServerName $DOMAIN
   #    ServerAlias $DOMAIN
   ### SETTINGS ###
    DocumentRoot  $WWWPATHHTML/

    <Directory "$WWWPATHHTML">
      Options Indexes FollowSymLinks MultiViews
      AllowOverride All
    </Directory>

     <IfModule mod_dav.c>
     Dav off
     </IfModule>

     <Directory "$WWWPATHHTML/wp-admin">
       Order deny,allow
       Deny from all
       allow from env=AllowCountry
     </Directory>

     <Location "/wp-login.php">
       Order deny,allow
       Deny from all
       allow from env=AllowCountry
     </Location>

    SetEnv HOME $WWWPATHHTML
    SetEnv HTTP_HOME $WWWPATHHTML

    # Possible values include: debug, info, notice, warn, error, crit,
    # alert, emerg.
    LogLevel warn

    CustomLog $WWWLOGDIR/access-ssl.log combined
    ErrorLog $WWWLOGDIR/error-ssl.log
 </VirtualHost>
VHOST_CREATE
echo "$VHOST_CONF_PATH was successfully created"
sleep 3
fi

# activate ssl config file
echo "enable vhost"
ln -s $VHOST_CONF_PATH /etc/nginx/sites-available/$DOMAIN

# Download and unzip wordpress application
echo "Download and unzip application"
cd /tmp
wget $WPZIPFILEPATH
unzip $WPZIPFILE
rm -rf $WPZIPFILE

# Copy wordpress to target location
echo "copy application"
cp -rT wordpress $WWWPATHHTML/
echo "remove wordpress downloaded file after the last installation"
# remove wordpress downloaded file after the last installation
rm -rf /tmp/wordpress

# Adjust wordpress config file
echo "Write config file"
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

# Download security plugins for wordpress
echo "Download and install security plugins"
cd /tmp
wget $BETTERWPSECURL
wget $GOTMLSURL
unzip -q $BETTERWPSECFILE -d $WWWPATHHTML/wp-content/plugins
unzip -q $GOTMLSFILE -d $WWWPATHHTML/wp-content/plugins

# create user for wordpress in Linux
echo "create separate service user"
useradd -M $WP_DB_USER
usermod -L $WP_DB_USER

# add wordpress user to www-data group
echo "Add to $WP_DB_USER to webserver group"
usermod -aG $WP_DB_USER www-data

# set permissions for wordpress
echo "set full write permissions to wordpress data"
mkdir -p $WWWPATHHTML/wp-content/uploads
chown -R www-data:www-data $WWWPATHHTML/
find $WWWPATHHTML -type d -exec chmod 755 {} \;
find $WWWPATHHTML -type f -exec chmod 644 {} \;

# create self signed certs
echo "create self signed certificates"
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096  \
    -subj "/C=DE/ST=Hamburg/L=NS/O=Local/OU=Development/CN=$DOMAIN/emailAddress=$WEBMASTER_MAIL" \
    -keyout $SSLPATH/$DOMAIN.key \
    -out $SSLPATH/$DOMAIN.crt

# create diffie-helman group
echo "Create diffie-helman group"
openssl dhparam -out $SSLPATH/dhparams.pem 2048

# Set secure permissions to certificate key
echo "Set secure permissions for certificate key"
chmod 600 $SSLPATH/$DOMAIN.key
chmod 600 $SSLPATH/$POOL_NAME_dhparams.pem

# Restart apache and mysql
echo "restart apache and mysql"
service mysql restart
service nginx restart

# Write mysql root password to file - keep it save
echo "Write root password into file /var/scripts/m-r-pass.txt, keep it safe"
echo $MYSQL_ROOT_PASS >> $SCRIPTS/m-r-pass.txt

echo "Installation succeded.."
