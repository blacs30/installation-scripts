#!/bin/bash
# didn't work for me with nginx and phpfpm and ssl
if [ "$1" != "" ] && [ "$1" == "setup" ]
  then
    echo "start setup"
  else
    echo "stop setup - adjust setup vars and start with parameter setup"
    exit 1
fi

export SCRIPTS=/var/scripts
export WEBMASTER_MAIL=webmaster@lisowski-development.com
export DOMAIN=ebooks.example.com
export HTML=/var/www
export WWWPATH=$HTML/$DOMAIN
export SSLPATH=$WWWPATH/ssl
export WWWPATHHTML=$HTML/$DOMAIN/public_html
export WWWLOGDIR=$WWWPATH/log
export BBSZIPFILEPATH=https://github.com/rvolz/BicBucStriim/archive/v1.3.6.zip
export BBSZIPFILE=v1.3.6.zip
export BBSUNZIPNAME=BicBucStriim-1.3.6
export BBS_USER=bbs-user
export SSL_CONF="" # assigned later /etc/apache2/sites-available/XXX-$DOMAIN.conf"

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

# create directory for website and logs for vhost
echo "create directory for application"
mkdir -p $WWWPATHHTML
mkdir -p $WWWLOGDIR
mkdir -p $SSLPATH

# Install apache2
echo "Install apache2"
aptitude install -y apache2

# Enable apache rewrite and ssl
echo "Enable apache rewrite and ssl"
a2enmod rewrite \
        ssl

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
                    php7.0-intl \
                    php7.0-json \
                    php7.0-mcrypt \
                    php7.0-opcache \
                    php7.0-sqlite3 \
                    php7.0-xml

# Disable default page
echo "Disable apache default config"
[[ -f /etc/apache2/sites-enabled/000-default.conf ]] && \
a2dissite 000-default.conf

# count number of available sites
echo "Check if vhost config exists"
export siteCount=$(ls -1 /etc/apache2/sites-enabled/ | wc -l)
export siteCountIncremented=$(printf "%03d" $((siteCount+1)))
export SSL_CONF_FILE=$siteCountIncremented-$DOMAIN.conf
export SSL_CONF=/etc/apache2/sites-available/$SSL_CONF_FILE

# Check if vhost config already exist for the given domain
export CONFIGEXIST=$(find /etc/apache2/sites-available -type f -name "*$DOMAIN*"  | wc -l)

# Generate Apache directory and vhost config $SSL_CONF
# if vhost config does not exist
echo "Create apache vhost config files"
if [ "$CONFIGEXIST" -ge "1" ];
        then
        echo "Virtual Host exists"
else
      touch "$SSL_CONF"
      cat << SSL_CREATE > "$SSL_CONF"
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

    SetEnv HOME $WWWPATHHTML
    SetEnv HTTP_HOME $WWWPATHHTML

    # Possible values include: debug, info, notice, warn, error, crit,
    # alert, emerg.
    LogLevel warn

    CustomLog $WWWLOGDIR/access-ssl.log combined
    ErrorLog $WWWLOGDIR/error-ssl.log
 </VirtualHost>
SSL_CREATE
echo "$SSL_CONF was successfully created"
sleep 3
fi

# activate ssl config file
echo "Enable vhost"
a2ensite "$SSL_CONF_FILE"

# Download and unzip bbs
echo "Download and unzip bbs"
cd /tmp
wget $BBSZIPFILEPATH
unzip $BBSZIPFILE
rm $BBSZIPFILE

# copy bbs to target directory
echo "Copy bbs"
cp -rT $BBSUNZIPNAME $WWWPATHHTML
rm -rf /tmp/$BBSUNZIPNAME

# create user for wordpress in Linux
echo "create separate service user"
useradd -M $BBS_USER
usermod -L $BBS_USER

# add wordpress user to www-data group
echo "Add to $BBS_USER to webserver group"
usermod -aG $BBS_USER www-data
# Set permissions to www directory
echo "Set full write permissions to data"
chown -R www-data:www-data $WWWPATHHTML/
find $WWWPATHHTML -type d -exec chmod 755 {} \;
find $WWWPATHHTML -type f -exec chmod 644 {} \;

# self signed certs
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
chmod 600 $SSLPATH/dhparams.pem

# set secure permission to htaccess
echo "Set secure permission to htaccess"
chmod 600 $WWWPATHHTML/.htaccess

# Restart apache2
service apache2 restart

# Write mysql root password to file - keep it save
echo "Installation succeded...
Press ENTER to finish"
read
