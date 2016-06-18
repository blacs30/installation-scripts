#!/bin/bash
# Check if parameter setup is set
if [ "$1" != "" ] && [ "$1" == "setup" ]; then
        echo "start setup"
else
        echo "stop setup:
        REMINDER: adjust setup vars and start with parameter: setup"
        exit 1
fi

export SHUF=$(shuf -i 13-15 -n 1)
export MYSQL_ROOT_PASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
export WEBMASTER_MAIL=webmaster@cloud.example.com
export OC_DB_NAME=oc_db_name  # max 16 characters
export OC_DB_USER=oc_db_user
export OC_DB_PASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
export OC_ADMIN_PASS=admin
export SHUF=$(shuf -i 13-15 -n 1)
export SCRIPTS=/var/scripts
export HTML=/var/www
export DOMAIN=cloud.example.com
export WWWPATH=$HTML/$DOMAIN
export SSLPATH=$WWWPATH/ssl
export WWWPATHHTML=$HTML/$DOMAIN/public_html
export WWWLOGDIR=$WWWPATH/log
export OCZIPFILEPATH=https://download.owncloud.org/community/owncloud-9.0.2.tar.bz2
export OCZIPFILE=owncloud-9.0.2.tar.bz2
export SSL_CONF="" # assigned later /etc/apache2/sites-available/XXX-$DOMAIN.conf"

# Check if root
if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msu root -c 'bash $SCRIPTS/install_owncloud.sh'"
        echo
        exit 1
fi

# Check if a redis config file exists and read the password from it
if [ ! -f /etc/redis/redis.conf ]; then
        echo "redis.conf does not exist - generate pass"
        export REDIS_PASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
else
      if grep -Fq '# requirepass' /etc/redis/redis.conf; then
        echo "Requirepass for redis config is not set, generate pass";
        export REDIS_PASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
else
        echo "Load requirepass of redis config, since it is already set"
        export REDIS_PASS=`grep 'requirepass ' /etc/redis/redis.conf | cut -d " " -f 2`
      fi
fi

# Install aptitude
echo "Install aptitude"
apt-get update
apt-get install aptitude -y

# Update system
echo "Update aptitude repos"
aptitude update

# Install Sudo, rsync, vim, bzip2, unzip, wget, cron
echo "Install Sudo, rsync, vim, bzip2, unzip, wget, cron"
aptitude install -y sudo \
                  rsync \
                  vim \
                  bzip2 \
                  unzip \
                  wget \
                  cron

# Install MYSQL
echo "Set mysql root password"
aptitude install debconf-utils -y
echo mysql-server mysql-server/root_password password $MYSQL_ROOT_PASS | debconf-set-selections
echo mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASS | debconf-set-selections
echo "Install mysql"
aptitude install mysql-server -y

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

# Install Apache and activate modules
echo "Install apache and active modules"
aptitude install apache2 -y

# Activate apache modules
echo "Active apache modules"
a2enmod rewrite \
        headers \
        env \
        dir \
        mime \
        ssl \
        setenvif

# Install PHP 7
echo "Install php7"
echo "deb http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list
echo "deb-src http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list
wget https://www.dotdeb.org/dotdeb.gpg
apt-key add dotdeb.gpg
rm dotdeb.gpg
aptitude update
aptitude install -y \
        software-properties-common \
	php7.0 \
        php7.0-common \
        php7.0-mysql \
        php7.0-intl \
        php7.0-mcrypt \
        php7.0-ldap \
        php7.0-imap \
        php7.0-cli \
        php7.0-gd \
        php7.0-pgsql \
        php7.0-json \
        php7.0-sqlite3 \
        php7.0-curl \
        php7.0-xmlrpc \
        php7.0-redis \
	libsm6 \
        libsmbclient

# Restart services
echo "Restart services"
service apache2 restart
service mysql restart

# Create folder for owncloud and log files
# and download owncloud
echo "Download and install owncloud"
cd /tmp
mkdir -p $WWWPATHHTML
mkdir -p $WWWLOGDIR
mkdir -p $SSLPATH
wget $OCZIPFILEPATH
tar -xjf $OCZIPFILE
cp -rT owncloud $WWWPATHHTML
rm -rf /tmp/$OCZIPFILE
rm -rf /tmp/owncloud

# give full permission for installing owncloud
echo "Give full permission for duration of owncloud installation"
chown -R www-data:www-data $WWWPATHHTML/
chmod -R 777 $WWWPATHHTML/

# create mysql owncloud database and owncloud user
echo "create mysql owncloud database and user"
echo "CREATE USER '$OC_DB_USER'@'localhost' IDENTIFIED BY '$OC_DB_PASS';
CREATE DATABASE IF NOT EXISTS $OC_DB_NAME;
GRANT ALL PRIVILEGES ON $OC_DB_NAME.* TO '$OC_DB_USER'@'localhost' IDENTIFIED BY '$OC_DB_PASS';
quit" >> $WWWPATH/$DOMAIN-createdb.sql
cat $WWWPATH/$DOMAIN-createdb.sql | mysql -u root -p$MYSQL_ROOT_PASS


# Download Secure permissions
echo "Download secure permission file from github"
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/setup_secure_permissions_owncloud.sh -P $SCRIPTS
mv $SCRIPTS/setup_secure_permissions_owncloud.sh $SCRIPTS/$DOMAIN-secure-permission.sh
sed -i "s,OWNCLOUDPATH,$WWWPATHHTML," $SCRIPTS/$DOMAIN-secure-permission.sh
chmod +x $SCRIPTS/$DOMAIN-secure-permission.sh

# Download Update permissions
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/update_set_permission.sh -P $SCRIPTS
mv $SCRIPTS/update_set_permission.sh $SCRIPTS/$DOMAIN-permission_update.sh
sed -i "s,OWNCLOUDPATH,$WWWPATHHTML," $SCRIPTS/$DOMAIN-permission_update.sh
chmod +x $SCRIPTS/$DOMAIN-permission_update.sh

# install owncloud from command line
echo "install owncloud"
su www-data -s /bin/bash -c 'php $WWWPATHHTML/occ maintenance:install -vvv --database "mysql" --database-name "$OC_DB_NAME" --database-table-prefix "$OC_DB_NAME\_" --database-user "$OC_DB_USER" --database-pass "$OC_DB_PASS" --admin-user "admin" --admin-pass "$OC_ADMIN_PASS"'

# owncloud config for filesize and timeout
echo "change upload size"
cp $WWWPATHHTML/.htaccess $WWWPATHHTML/htaccess.orig_$(date +%F-%T)
sed -i 's/upload_max_filesize.*/upload_max_filesize 16G/g' $WWWPATHHTML/.htaccess
sed -i 's/post_max_size.*/post_max_size 16G/g' $WWWPATHHTML/.htaccess
sed -i 's/memory_limit.*/memory_limit 2G/g' $WWWPATHHTML/.htaccess
echo "append timeout settings"
if grep -Fq "max_input_time" $WWWPATHHTML/.htaccess
  then
    echo "Max input time already exists in htaccess"
  else
    echo "Add max input time to htaccess"
    sed -i "/memory_limit.*/a php_value max_input_time 14400" $WWWPATHHTML/.htaccess
fi
if grep -Fq "max_execution_time" $WWWPATHHTML/.htaccess
  then
      echo "max execution time already exists in htaccess"
  else
    echo "add max execution time to htaccess"
    sed -i "/max_input_time.*/a php_value max_execution_time 14400" $WWWPATHHTML/.htaccess
fi

# add owncloud trusted domain
if grep -Fq "'$DOMAIN'" $WWWPATHHTML/config/config.php; then
        echo "Domain is already in trusted domains"
else
        su www-data -s /bin/bash -c 'php $WWWPATHHTML/occ config:system:set trusted_domains 2 --value="$DOMAIN"'
        echo "Domain added to trusted domains"
fi

# add owncloud overwrite cli url
if grep -Fq "'https://$DOMAIN'" $WWWPATHHTML/config/config.php
then
    echo "Domain is already overwrite cli url"
else
  su www-data -s /bin/bash -c 'php $WWWPATHHTML/occ config:system:set overwrite.cli.url --value="https://$DOMAIN"'
  echo "Domain added to  overwrite cli url"
fi

# owncloud configuration for redis cache
echo "Backup owncloud config.php"
cp $WWWPATHHTML/config/config.php $WWWPATHHTML/config/config.php.orig_$(date +%F-%T)
sed -i '$ d' $WWWPATHHTML/config/config.php
echo -e "'filelocking.enabled' => 'true', \
  \n'memcache.local' => '\OC\Memcache\Redis', \
  \n'memcache.locking' => '\OC\Memcache\Redis', \
  \n'redis' => array( \
  \n   'host' => '/var/run/redis/redis.sock', \
  \n   'port' => 0, \
  \n   'timeout' => 0.0, \
  \n   'password' => '$REDIS_PASS', \
  \n    ), \
\n \
\n);" >> $WWWPATHHTML/config/config.php

# change owncloud to cron background refresh
echo "Change owncloud background refresh to cron"
su www-data -s /bin/bash -c 'php $WWWPATHHTML/occ background:cron'

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

# Add crontab for owncloud
echo "add owncloud background crontab entry for www-data user"
(crontab -l -u www-data  2>/dev/null; echo "*/15 * * * * php $WWWPATHHTML/cron.php") | crontab -u www-data -

# install redis config to use socket
echo "Install redis server"
apt-get install -y redis-server php5-redis

# Configure redis for using sockets
echo "Configure redis-server for using socket end set password"
cp /etc/redis/redis.conf /etc/redis/redis.conf.orig_$(date +%F-%T)
sed -i 's/^port .*/port 0/' /etc/redis/redis.conf
if grep -Fq "^unixsocket /var/run/redis/redis.sock" /etc/redis/redis.conf
  then
    echo "unixsocket exists already in redis.conf"
  else
    echo "add unixsocket /var/run/redis/redis.sock to redis.conf"
    echo 'unixsocket /var/run/redis/redis.sock' >> /etc/redis/redis.conf
fi
if grep -Fq "^unixsocketperm 770" /etc/redis/redis.conf
  then
    echo "unixsocketperm 770 exists already in redis.conf"
  else
    echo "add unixsocketperm 770 to redis.conf"
    echo 'unixsocketperm 770' >> /etc/redis/redis.conf
fi

sed -i "/requirepass .*/c\requirepass $REDIS_PASS" /etc/redis/redis.conf

[[ -d /var/run/redis  ]] && echo "directory /var/run/redis exists already" || mkdir /var/run/redis
chown redis:redis /var/run/redis
chmod 755 /var/run/redis
if [ -d /etc/tmpfiles.d ]
  then
    echo 'd  /var/run/redis  0755  redis  redis  10d  -' >> /etc/tmpfiles.d/redis.conf
fi

# Add user redis www-data group
echo "Add redis to webserver group"
usermod -aG redis www-data

# and disable default page
echo "Disable apache default config"
[[ -f /etc/apache2/sites-enabled/000-default.conf ]] && \
a2dissite 000-default.conf

# count number of available sites
echo "Create apache vhost config files"
export siteCount=$(ls -1 /etc/apache2/sites-enabled/ | wc -l)
export siteCountIncremented=$(printf "%03d" $((siteCount+1)))
export SSL_CONF_FILE=$siteCountIncremented-$DOMAIN.conf
export SSL_CONF=/etc/apache2/sites-available/$SSL_CONF_FILE

# count number of apache vhost configs which mitach the $DOMAIN
export CONFIGEXIST=$(find /etc/apache2/sites-available -type f -name "*$DOMAIN*"  | wc -l)

# Generate Apache directory and vhost config $SSL_CONF
if [ "$CONFIGEXIST" -ge "1" ];
        then
        echo "Virtual Host exists"
else
      touch "$SSL_CONF"
      cat << SSL_CREATE > "$SSL_CONF"
#Forward everything to port 80
<VirtualHost *:80>
  ServerName $DOMAIN
  Redirect permanent / https://$DOMAIN
  CustomLog $WWWLOGDIR/access.log combined
  ErrorLog $WWWLOGDIR/error.log
</VirtualHost>

<IfModule mod_ssl.c>
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
   # put into mods-enabled/ssl.conf
   # SSLOpenSSLConfCmd DHParameters "$SSLPATH/dhparams.pem"

   ### YOUR SERVER ADDRESS ###
       ServerAdmin $WEBMASTER_MAIL
       ServerName $DOMAIN
   #    ServerAlias $DOMAIN
   ### SETTINGS ###
   DocumentRoot  $WWWPATHHTML/

   <Directory "$WWWPATHHTML">
   Options Indexes FollowSymLinks
   AllowOverride All
   Allow from all
   Require all granted
   Satisfy Any
   </Directory>

   <IfModule mod_dav.c>
   Dav off
   </IfModule>

   # You will probably need to change this next Directory directive as well
   # in order to match the earlier one.
   <Directory "$WWWPATHHTML">
     SSLOptions +StdEnvVars
   </Directory>

   <Directory "$WWWPATHHTML/data">
   # just in case if .htaccess gets disabled
   Require all denied
   </Directory>

   SetEnv HOME $WWWPATHHTML
   SetEnv HTTP_HOME $WWWPATHHTML

   # Possible values include: debug, info, notice, warn, error, crit,
   # alert, emerg.
   LogLevel warn

   CustomLog $WWWLOGDIR/access-ssl.log combined
   ErrorLog $WWWLOGDIR/error-ssl.log
</VirtualHost>
</IfModule>
SSL_CREATE
echo "$SSL_CONF was successfully created"
sleep 3
fi

# activate owncloud-ssl config file
echo "enable vhost"
a2ensite "$SSL_CONF_FILE"

# self signed certs
echo "create self signed certificates"
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096  \
    -subj "/C=DE/ST=Hamburg/L=NS/O=Local/OU=Development/CN=$DOMAIN/emailAddress=$WEBMASTER_MAIL" \
    -keyout $SSLPATH/$DOMAIN.key \
    -out $SSLPATH/$DOMAIN.crt

# create diffie-helman group
openssl dhparam -out $SSLPATH/dhparams.pem 2048

# Set secure permissions to certificate key
chmod 600 $SSLPATH/$DOMAIN.key
chmod 600 $SSLPATH/dhparams.pem

# install and create ssl script with lets encrypt
echo "Download and create certificates from letsencrypt"
apt-get install -y git
[[ -d /opt/letsencrypt ]] && cd /opt/letsencrypt && git pull || git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt
# cd /opt/letsencrypt && ./certbot-auto certonly --non-interactive --agree-tos --email webmaster@cloud.example.com --apache -d example.com -d www.example.com -d blog.example.com -d cloud.example.com -d rss.example.com -d webmail.example.com

# add letsencrypt cron script
# Check if an entry already exists then skip otherwise create one
if crontab -l | grep -Fq 'letsencrypt-auto renew'
  then
    echo "letsencrypt-auto is already in crontabs";
  else
    echo "add letsencrypt-auto renewal to crontab"
    (crontab -l 2>/dev/null; echo "30 2 * * 1 bash /opt/letsencrypt/letsencrypt-auto renew >> /var/log/le-renew.log") | crontab -
fi

echo "set permissions for the installed owncloud environment\n\n"
bash $SCRIPTS/$DOMAIN-secure-permission.sh

# Restart all services
echo "Restart Services"
service redis-server restart
service apache2 restart
service cron restart
service mysql restart


# Write mysql root password to file - keep it save
echo "Write root password into file /var/scripts/m-r-pass.txt, keep it safe"
echo $MYSQL_ROOT_PASS >> $SCRIPTS/m-r-pass.txt

echo "Installation succeded...
Press ENTER to finish"
read
