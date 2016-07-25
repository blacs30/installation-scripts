#!/bin/bash -e
# Clone a WordPress site via Bash script
clear
echo "The following two steps have to be executed on the target host"
echo "ssh-keygen (included in package SSH on debian)"
echo "ssh-copy-id -i ~/.ssh/id_rsa.pub remote-host"
echo ""
echo ""
echo "Press ENTER if you have done the above steps"
echo "And you are ready to start with the cloning"
echo ""
read
clear
echo "==================================================="
echo "Clone WordPress Script"
echo "==================================================="

# Set Default Settings (helpful for testing)
default_server_user_source=$"root"
default_server_ip_source=$"192.168.0.1"
default_mysql_user=$"root"
default_mysql_pass=$"123456"
default_source_domain=$"example.com"
default_target_domain=$"example.com"
default_source_directory=$"/httpdocs/example.com"
default_target_directory=$"/var/www/example.com/public_html"
default_apache_directory=$"/etc/apache2/sites-available"
default_source_dbname=$"wp_db_name"
default_source_dbhost=$"192.168.0.1"
default_source_dbuser=$"wp_db_user"
default_source_dbpass=$"123456"
default_target_dbname=$"wp_db_name_new"
default_target_dbuser=$"wp_db_user_new"
default_target_dbpass=$"123456"
default_target_dbhost=$"localhost"
default_source_dbtableprefix=$"wp_"
default_tmp_dir=$"/tmp"
NOW=$(date +"%Y-%m-%d-%H%M")
WEBMASTER_MAIL=webmaster@example.com


#Request SSH Access
read -p "SSH Username (e.g. "$default_server_user_source"): " server_user_source
server_user_source=${server_user_source:-$default_server_user_source}
echo $server_user_source
read -p "SSH Server IP (e.g. "$default_server_ip_source"): " server_ip_source
server_ip_source=${server_ip_source:-$default_server_ip_source}
echo $server_ip_source

#Request MySQL Admin
read -p "MySQL Master Username (e.g. "$default_mysql_user"): " mysql_user
mysql_user=${mysql_user:-$default_mysql_user}
echo $mysql_user
read -p "MySQL Master Password (e.g. "$default_mysql_pass"): " mysql_pass
mysql_pass=${mysql_pass:-$default_mysql_pass}
echo $mysql_pass

# Request Source Settings
read -p "Source Domain (e.g. "$default_source_domain"): " source_domain
source_domain=${source_domain:-$default_source_domain}
echo $source_domain
read -p "Source Directory (no trailing slash e.g. "$default_source_directory"): " source_directory
source_directory=${source_directory:-$default_source_directory}
echo $source_directory
read -p "Source Database Name (e.g. "$default_source_dbname"): " source_dbname
source_dbname=${source_dbname:-$default_source_dbname}
echo $source_dbname
read -p "Source Database Host (e.g. "$default_source_dbhost"): " source_dbhost
source_dbhost=${source_dbhost:-$default_source_dbhost}
echo $source_dbname
read -p "Source Database User (e.g. "$default_source_dbuser"): " source_dbuser
source_dbuser=${source_dbuser:-$default_source_dbuser}
echo $source_dbuser
read -p "Source Database Pass (e.g. "$default_source_dbpass"): " source_dbpass
source_dbpass=${source_dbpass:-$default_source_dbpass}
echo $source_dbpass
read -p "Source Database Table Prefix (e.g. "$default_source_dbtableprefix"): " source_dbtableprefix
source_dbtableprefix=${source_dbtableprefix:-$default_source_dbtableprefix}
echo $source_dbtableprefix
# Request Target Settings
read -p "Target Domain (e.g. "$default_target_domain"): " target_domain
target_domain=${target_domain:-$default_target_domain}
echo $target_domain
read -p "Target Directory (no trailing slash e.g. "$default_target_directory"): " target_directory
target_directory=${target_directory:-$default_target_directory}
echo $target_directory
read -p "Target Database Name (max 16 char)(e.g. "$default_target_dbname"): " target_dbname
target_dbname=${target_dbname:-$default_target_dbname}
echo $target_dbname
read -p "Target Database User (e.g. "$default_target_dbuser"): " target_dbuser
target_dbuser=${target_dbuser:-$default_target_dbuser}
echo $target_dbuser
read -p "Target Database Pass (e.g. "$default_target_dbpass"): " target_dbpass
target_dbpass=${target_dbpass:-$default_target_dbpass}
echo $target_dbpass
read -p "Target Database Host (e.g. "$default_target_dbhost"): " target_dbhost
target_dbhost=${target_dbhost:-$default_target_dbhost}
echo $target_dbhost

read -p "Tmp directory should exist on both servers (e.g. "$default_tmp_dir"): " tmp_dir
tmp_dir=${tmp_dir:-$default_tmp_dir}
echo $tmp_dir


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
echo mysql-server mysql-server/root_password password $mysql_pass | debconf-set-selections
echo mysql-server mysql-server/root_password_again password $mysql_pass | debconf-set-selections

# Install Mysql
echo "Install mysql"
aptitude install -y mysql-server

# Start mysql server
echo "Start mysql server"
service mysql restart

# create directory for website and logs for vhost
echo "create directory for application"
mkdir -p $target_directory
mkdir -p $target_directory/../log
mkdir -p $target_directory/../ssl

echo "Clone now? (y/n)"
read -e run
if [ "$run" == n ] ; then
exit
else
echo "==================================================="
echo "WordPress Cloning is Beginning"
echo "==================================================="

#backup source_directory
cd $tmp_dir
# add -v option to these if you want to see verbose file listings
ssh $server_user_source@$server_ip_source "cd $source_directory && tar -cvf /tmp/source_clone_$NOW.tar ."
scp $server_user_source@$server_ip_source:/tmp/source_clone_$NOW.tar .

#unzip clone in target directory
tar -xvf source_clone_$NOW.tar -C $target_directory
#remove tarball of source
rm source_clone_$NOW.tar

# create user for wordpress in Linux
echo "create separate service user"
useradd -M $target_dbuser
usermod -L $target_dbuser

# add wordpress user to www-data group
echo "Add to $target_dbuser to webserver group"
usermod -aG $target_dbuser www-data

# Set Directory Permissions
echo "set full write permissions to wordpress data"
chown -R www-data:www-data $target_directory
find $target_directory -type d -exec chmod 755 {} \;
find $target_directory -type f -exec chmod 644 {} \;

#set database details with sed find and replace
echo "Backup wp-config.php and change values to target values"
cp $target_directory/wp-config.php $target_directory/wp-config.php.orig
cp $target_directory/wp-config-sample.php $target_directory/wp-config.php
sed -i "s/^\$table_prefix.*;/\$table_prefix  = '$source_dbtableprefix';/g" $target_directory/wp-config.php
sed -i "s/^define('DB_HOST', '.*');/define('DB_HOST', '$target_dbhost:3306');/g" $target_directory/wp-config.php
sed -i "s/^define('DB_USER', '.*');/define('DB_USER', '$target_dbuser');/g" $target_directory/wp-config.php
sed -i "s/^define('DB_NAME', '.*');/define('DB_NAME', '$target_dbname');/g" $target_directory/wp-config.php
sed -i "s/^define('DB_PASSWORD', '.*');/define('DB_PASSWORD', '$target_dbpass');/g" $target_directory/wp-config.php

# echo "define('RELOCATE',true);" | tee -a wp-config.php
#echo "define('WP_HOME','http://$target_domain');" | tee -a wp-config.php
#echo "define('WP_SITEURL','http://$target_domain');" | tee -a wp-config.php

# update salt secrets
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s $target_directory/wp-config.php

echo "================================"
echo "Directory duplicated"
echo "================================"

# Begin Database Duplication
# Export the database
cd $tmp_dir
ssh $server_user_source@$server_ip_source "mysqldump -h$source_dbhost -P3306 -u$source_dbuser -p$source_dbpass $source_dbname > $tmp_dir/clone_$NOW.sql"
scp $server_user_source@$server_ip_source:/tmp/clone_$NOW.sql .
# Create the target database and permissions
mysql -u$mysql_user -p$mysql_pass -e "create database IF NOT EXISTS $target_dbname; GRANT ALL PRIVILEGES ON $target_dbname.* TO '$target_dbuser'@'localhost' IDENTIFIED BY '$target_dbpass'"
# Import the source database into the target
mysql -u$mysql_user -p$mysql_pass $target_dbname < $tmp_dir/clone_$NOW.sql
echo "================================"
echo "Database duplicated"
echo "================================"


# install expect
echo "Install expect"
aptitude -y install expect

# mysql_secure_installation
echo "Run expect for mysql_secure_installation"
export SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root:\"
send \"$mysql_pass\r\"
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
                    php7.0-json \
                    php7.0-mysql \
                    php7.0-opcache \
                    php7.0-readline

# Disable default page
echo "Disable apache default config"
[[ -f /etc/apache2/sites-enabled/000-default.conf ]] && \
a2dissite 000-default.conf

# count number of available sites
echo "Check if vhost config exists"
export siteCount=$(ls -1 /etc/apache2/sites-enabled/ | wc -l)
export siteCountIncremented=$(printf "%03d" $((siteCount+1)))
export apacheConfigFile=$siteCountIncremented-$target_domain.conf
export SSL_CONF=/etc/apache2/sites-available/$apacheConfigFile

# Check if vhost config already exist for the given domain
export CONFIGEXIST=$(find /etc/apache2/sites-available -type f -name "*$target_domain*"  | wc -l)

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
  ServerName $target_domain
  Redirect permanent / https://$target_domain/
  CustomLog $target_directory/../log/access.log combined
  ErrorLog $target_directory/../log/error.log
</VirtualHost>

<VirtualHost *:443>
<IfModule mod_headers.c>
   Header always set Strict-Transport-Security "max-age=15768000; includeSubDomains; preload"
 </IfModule>
   SSLEngine on
   # settings for self signed certificates
   SSLCipherSuite HIGH:MEDIUM
   SSLCertificateFile $target_directory/../ssl/$target_domain.crt
   SSLCertificateKeyFile  $target_directory/../ssl/$target_domain.key

   # settings for letsencrypt certificates
   # SSLCertificateFile /etc/letsencrypt/live/$target_domain/fullchain.pem
   # SSLCertificateKeyFile /etc/letsencrypt/live/$target_domain/privkey.pem
   # SSLCertificateChainFile /etc/letsencrypt/live/$target_domain/chain.pem
   # Include /etc/letsencrypt/options-ssl-apache.conf

   # Protect against Logjam attacks. See: https://weakdh.org
   # Not yet in Jessie 8.4 openssl 1.0.1t available
   # SSLOpenSSLConfCmd DHParameters "$target_directory/../ssl/dhparams.pem"

   ### YOUR SERVER ADDRESS ###
       ServerAdmin $WEBMASTER_MAIL
       ServerName $target_domain
   #    ServerAlias $target_domain
   ### SETTINGS ###
    DocumentRoot  $target_directory/

    <Directory "$target_directory">
      Options Indexes FollowSymLinks MultiViews
      AllowOverride All
    </Directory>

     <IfModule mod_dav.c>
     Dav off
     </IfModule>

    SetEnv HOME $target_directory
    SetEnv HTTP_HOME $target_directory

    # Possible values include: debug, info, notice, warn, error, crit,
    # alert, emerg.
    LogLevel warn

    CustomLog $target_directory/../log/access-ssl.log combined
    ErrorLog $target_directory/../log/error-ssl.log
 </VirtualHost>
SSL_CREATE
echo "$SSL_CONF was successfully created"
sleep 3
fi

# activate ssl config file
echo "enable vhost"
a2ensite "$apacheConfigFile"

# create self signed certs
echo "Create self signed certificates"
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096  \
    -subj "/C=DE/ST=Hamburg/L=NS/O=Local/OU=Development/CN=$target_domain/emailAddress=$WEBMASTER_MAIL" \
    -keyout $target_directory/../ssl/$target_domain.key \
    -out $target_directory/../ssl/$target_domain.crt

# create diffie-helman group
echo "Create diffie-helman group"
openssl dhparam -out $target_directory/../ssl/dhparams.pem 2048

# Set secure permissions to certificate key
echo "Set secure permissions for certificate key"
chmod 600 $target_directory/../ssl/$target_domain.key
chmod 600 $target_directory/../ssl/dhparams.pem

# Restart apache and mysql
echo "restart apache and mysql"
service mysql restart
service apache2 restart

echo "================================"
echo "Web configuration added"
echo "================================"
echo "Clone is complete."
echo "Test at https://"$target_domain
echo "================================"

echo "Installation succeded...
Continue with the installation of wordpress in the browser
Then set the permalinks first and after that run

chmod 600 $target_directory/.htaccess

Press ENTER to finish"
read
fi
