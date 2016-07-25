#!/bin/bash
# mailserver
# https://www.exratione.com/2016/05/a-mailserver-on-ubuntu-16-04-postfix-dovecot-mysql/

export SHUF=$(shuf -i 13-15 -n 1)
export MYSQL_ROOT_PASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
export SCRIPTS=/var/scripts
export HTML=/var/www
export DOMAIN=webmail.example.com
export WWWPATH=$HTML/$DOMAIN
export SSLPATH=$WWWPATH/ssl
export WWWPATHHTML=$HTML/$DOMAIN/public_html
export WWWLOGDIR=$WWWPATH/log
export WEBMASTER_MAIL=admin@example.com
export WEBMAIL_DB_PASS=webmailpass
export WEBMAIL_DB_USER=webmail
export WEBMAIL_DB_NAME=webmail

# Check if root
if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msu root -c 'bash $SCRIPTS/$0'"
        echo
        exit 1
fi

# Install aptitude
echo "Install aptitude"
apt-get update
apt-get upgrade
apt-get install aptitude --assume-yes

# Install Sudo, vim, unzip, wget
echo "Install Sudo, vim, unzip, wget"
aptitude install --assume-yes sudo \
                  vim \
                  unzip \
                  wget \
                  cron \
                  rsyslog

command -v mysql >/dev/null 2>&1 || { echo >&2
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
}

# Install Apache and activate modules
echo "Install apache and active modules"
aptitude install apache2 -y

# Activate apache modules
echo "Active apache modules"
a2enmod rewrite \
        headers \
        deflate \
        expires \
        ssl

Install PHP 7
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
        php7.0-mcrypt \
        php7.0-curl \
        php7.0-gd \
        php7.0-mbstring \
        php-xml-parser \
        php7.0-common \
        php7.0-cli \
        php7.0-json \
        php7.0-readline \
        php7.0-mysql

# Restart services
echo "Restart services"
service apache2 restart
service mysql restart

# Create folders
echo "Create folders"
mkdir -p $WWWPATHHTML
mkdir -p $WWWLOGDIR
mkdir -p $SSLPATH

# self signed certs
echo "create self signed certificates"
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096  \
    -subj "/C=DE/ST=Hamburg/L=NS/O=Local/OU=Development/CN=$DOMAIN/emailAddress=$WEBMASTER_MAIL" \
    -keyout $SSLPATH/$DOMAIN.key \
    -out $SSLPATH/$DOMAIN.crt

# create diffie-helman group
openssl dhparam -out $SSLPATH/dhparams.pem 2048

# Set secure permissions to certificate key
chmod 600 $SSLPATH/*

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

# Configure Apache
sed -i 's/^ServerTokens.*/ServerTokens Prod/' /etc/apache2/conf-enabled/security.conf
sed -i 's/^ServerSignature.*/ServerSignature Off/' /etc/apache2/conf-enabled/security.conf

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
  Redirect permanent / https://$DOMAIN/
  CustomLog $WWWLOGDIR/access.log combined
  ErrorLog $WWWLOGDIR/error.log
</VirtualHost>

<IfModule mod_ssl.c>
<VirtualHost *:443>
<IfModule mod_headers.c>
   Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
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
   SSLOptions +StdEnvVars
   Options FollowSymLinks
   AllowOverride All
   Order deny,allow
   Deny from all
   allow from env=AllowCountry
 </Directory>


   <IfModule mod_dav.c>
   Dav off
   </IfModule>

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

# activate ssl config file
echo "enable vhost"
a2ensite "$SSL_CONF_FILE"

# create mysql database and user
echo "create mysql database and user"
echo "CREATE USER '$WEBMAIL_DB_USER'@'localhost' IDENTIFIED BY '$WEBMAIL_DB_PASS';
CREATE DATABASE IF NOT EXISTS $WEBMAIL_DB_NAME;
GRANT ALL PRIVILEGES ON $WEBMAIL_DB_NAME.* TO '$WEBMAIL_DB_USER'@'localhost' IDENTIFIED BY '$WEBMAIL_DB_PASS';
quit" >> $WWWPATH/$DOMAIN-createdb.sql
cat $WWWPATH/$DOMAIN-createdb.sql | mysql -u root -p$MYSQL_ROOT_PASS

# Copy webmail to target location
echo "copy application"
wget http://www.afterlogic.org/download/webmail_php.zip -O /tmp/webmail_php.zip
unzip /tmp/webmail_php.zip
cp -rT webmail $WWWPATHHTML/
rm -rf /tmp/webmail

chown www-data:www-data -R $WWWPATHHTML/
find $WWWPATHHTML/ -type d -exec chmod 755 {} \;
find $WWWPATHHTML/ -type f -exec chmod 644 {} \;

service apache2 restart

echo "open to install https://$DOMAIN/install/
later delete the install directory

ADMINPanel: https://$DOMAIN/adminpanel/
Users:      https://$DOMAIN/index.php
"

# Write mysql root password to file - keep it save
echo "Write root password into file /var/scripts/m-r-pass.txt, keep it safe"
echo $MYSQL_ROOT_PASS >> $SCRIPTS/m-r-pass.txt
echo $WEBMAIL_DB_PASS >> $SCRIPTS/m-r-pass.txt

echo "Installation succeded...
Press ENTER to finish"
read
