#!/bin/bash
# mailserver
# https://www.exratione.com/2016/05/a-mailserver-on-ubuntu-16-04-postfix-dovecot-mysql/

export HOSTNAME=mail.example.com
export SHUF=$(shuf -i 13-15 -n 1)
export MYSQL_ROOT_PASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
export SCRIPTS=/var/scripts
export HTML=/var/www
export DOMAIN=mail.example.com
export WWWPATH=$HTML/$DOMAIN
export SSLPATH=$WWWPATH/ssl
export WWWPATHHTML=$HTML/$DOMAIN/public_html
export WWWLOGDIR=$WWWPATH/log
export WEBMASTER_MAIL=admin@example.com
export PFA_DB_PASS=mailpass
export PFA_DB_USER=mail
export PFA_DB_NAME=mail
export POSTFIXADM=postfixadmin-2.93
export POSTMASTER=postmaster@example.com

echo "in CFS or UFW etc open following ports:
22 (SSH)
25 (SMTP)
80 (HTTP)
110 (POP3)
143 (IMAP)
443 (HTTPS)
465 (SMTPS)
993 (IMAPS)
995 (POP3S)"

# Check if root
if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msu root -c 'bash $SCRIPTS/install_owncloud.sh'"
        echo
        exit 1
fi

# set the hostname of the server
echo "$HOSTNAME" > /etc/hostname

# And add your hostname to the first line of /etc/hosts:
vi /etc/hosts # add 127.0.0.1 mail.example.com localhost

# Install aptitude
echo "Install aptitude"
apt-get update
apt-get upgrade
apt-get install aptitude --assume-yes

# Update system
echo "Update aptitude repos"
aptitude update

# Install Sudo, rsync, vim, bzip2, unzip, wget, cron
echo "Install Sudo, rsync, vim, bzip2, unzip, wget, cron"
aptitude install --assume-yes sudo \
                  rsync \
                  vim \
                  bzip2 \
                  unzip \
                  wget \
                  cron \
                  rsyslog

# start rsyslog
echo "Start rsyslog"
service rsyslog restart

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
  Redirect permanent / https://$DOMAIN
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
       ServerAlias imap.$DOMAIN
       ServerAlias smtp.$DOMAIN
   ### SETTINGS ###
   DocumentRoot  $WWWPATHHTML/

   # You will probably need to change this next Directory directive as well
   # in order to match the earlier one.
   <Directory "$WWWPATHHTML">
    SSLOptions +StdEnvVars
    Options FollowSymLinks
    AllowOverride All
    AuthType Basic
    AuthName "Restricted Content"
    AuthUserFile /etc/apache2/.htpasswd
    Require valid-user
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

# activate owncloud-ssl config file
echo "enable vhost"
a2ensite "$SSL_CONF_FILE"

# Install base mailserver components
debconf-set-selections <<< "postfix postfix/mailname string $HOSTNAME"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
echo "Install base mailserver components"
aptitude install --assume-yes mutt \
                  postfix \
                  libexttextcat-data \
                  liblockfile-bin \
                  gnupg-agent \
                  libksba8 \
                  libexttextcat-2.0-0 \
                  libgpgme11 \
                  libwrap0 \
                  dovecot-imapd \
                  libassuan0 \
                  ssl-cert \
                  dovecot-pop3d \
                  dirmngr \
                  ntpdate \
                  dovecot-core \
                  tcpd \
                  gnupg2 \
                  liblockfile1 \
                  pinentry-curses \
                  libnpth0 \
                  procmail \
                  libtokyocabinet9 \
                  bsd-mailx

# Install additional components for virtual users for mail server
echo "Install additional components for mail server"
apt-get install --assume-yes \
                  postfix-mysql \
                  dovecot-mysql \
                  postgrey \
                  amavis \
                  clamav \
                  clamav-daemon \
                  spamassassin \
                  libdbi-perl \
                  libdbd-mysql-perl \
                  php7.0-imap

# Install tools for virus and spam detctions
echo "Install tools for virus and spam detctions"
apt-get install --assume-yes \
                  pyzor \
                  razor \
                  arj \
                  cabextract \
                  lzop \
                  nomarch \
                  p7zip-full \
                  ripole \
                  rpm2cpio \
                  tnef \
                  unzip \
                  unrar-free \
                  zip \
                  zoo

# restart apache
echo "Restart Apache2"
service apache2 restart

if grep -Fq "sql_mode" /etc/mysql/my.cnf
  then
    echo "sql_mode was already added to mysql config"
  else
    echo "Add max input time to htaccess"
    echo "sql_mode=ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION" >> /etc/mysql/my.cnf
fi

# create mysql database and user
echo "create mysql database and user"
echo "CREATE USER '$PFA_DB_USER'@'localhost' IDENTIFIED BY '$PFA_DB_PASS';
CREATE DATABASE IF NOT EXISTS $PFA_DB_NAME;
GRANT ALL PRIVILEGES ON $PFA_DB_NAME.* TO '$PFA_DB_USER'@'localhost' IDENTIFIED BY '$PFA_DB_PASS';
quit" >> $WWWPATH/$DOMAIN-createdb.sql
cat $WWWPATH/$DOMAIN-createdb.sql | mysql -u root -p$MYSQL_ROOT_PASS

# download postfixadmin
wget http://downloads.sourceforge.net/project/postfixadmin/postfixadmin/$POSTFIXADM/$POSTFIXADM.tar.gz
tar -xf $POSTFIXADM.tar.gz
rm -f $POSTFIXADM.tar.gz
mv $POSTFIXADM $WWWPATHHTML/postfixadmin
chown -R www-data:www-data $WWWPATHHTML/postfixadmin

# create new empty postfix local config file
echo "create new empty postfix local config file"
POSTFIXADM_CONF_FILE=$WWWPATHHTML/postfixadmin/config.local.php
touch $POSTFIXADM_CONF_FILE
chown www-data:www-data $POSTFIXADM_CONF_FILE

# download postfixadmin config template
echo "download postfixadmin template"
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/postfixadmin.config.local.php -O $POSTFIXADM_CONF_FILE

# replace postfixadmin template values with real values
echo "adjust postfixadmin template config"
sed -i "s,.*'postfix_admin_url'.*,\$CONF['postfix_admin_url'] = 'https://$DOMAIN/postfixadmin';," $POSTFIXADM_CONF_FILE
sed -i "s,.*'database_user'.*,\$CONF['database_user'] = '$PFA_DB_USER';," $POSTFIXADM_CONF_FILE
sed -i "s,.*'database_password'.*,\$CONF['database_password'] = '$PFA_DB_PASS';," $POSTFIXADM_CONF_FILE
sed -i "s,.*'database_name'.*,\$CONF['database_name'] = '$PFA_DB_NAME';," $POSTFIXADM_CONF_FILE
sed -i "s,.*'admin_email'.*,\$CONF['admin_email'] = '$WEBMASTER_MAIL';," $POSTFIXADM_CONF_FILE
sed -i "s,'admin@example.com','$WEBMASTER_MAIL'," $POSTFIXADM_CONF_FILE
sed -i "s,.*'footer_text'.*,\$CONF['footer_text'] = 'Return to $DOMAIN';," $POSTFIXADM_CONF_FILE
sed -i "s,.*'footer_link'.*,\$CONF['footer_link'] = 'https://$DOMAIN';," $POSTFIXADM_CONF_FILE

# Read website setup generate hash
echo "visit https://$DOMAIN/postfixadmin/setup.php enter the password and copy the generated has here and press RETURN"
read SETUP_HASH
echo "
// In order to setup Postfixadmin, you MUST specify a hashed password here.
// To create the hash, visit setup.php in a browser and type a password into the field,
// on submission it will be echoed out to you as a hashed value.
\$CONF['setup_password'] = '$SETUP_HASH';
" >> $POSTFIXADM_CONF_FILE
unset SETUP_HASH

echo "Continue to create postfixadmin superuser on https://$DOMAIN/postfixadmin/setup.php and press RETURN when you finished
the page will be protected via .htaccess after that."
read
echo "
<Files "setup.php">
deny from all
</Files>
" >> $WWWPATHHTML/postfixadmin/.htaccess

# add virtual mail user
echo "Add vmail user"
useradd -r -u 150 -g mail -d /var/vmail -s /sbin/nologin -c "Virtual maildir handler" vmail
mkdir /var/vmail
chmod 770 /var/vmail
chown vmail:mail /var/vmail

# adjust dovecot sql connection
DOVECOT_CONF=/etc/dovecot/dovecot-sql.conf.ext
sed -i "s,#driver =.*,driver = mysql," $DOVECOT_CONF
sed -i "s,#connect =.*,connect = host=localhost dbname=$PFA_DB_NAME user=$PFA_DB_USER password=$PFA_DB_PASS," $DOVECOT_CONF
sed -i "s,#default_pass_scheme =.*,default_pass_scheme = MD5-CRYPT," $DOVECOT_CONF

# add sql query to tell dovecot how to obtain a user password
echo "
# Define the query to obtain a user password.
#
# Note that uid 150 is the \"vmail\" user and gid 8 is the \"mail\" group.
#
password_query = \\
  SELECT username as user, password, '/var/vmail/%d/%n' as userdb_home, \\
  'maildir:/var/vmail/%d/%n' as userdb_mail, 150 as userdb_uid, 8 as userdb_gid \\
  FROM mailbox WHERE username = '%u' AND active = '1'
" >> $DOVECOT_CONF

# add sql query to tell dovecot how to obtain user information
echo "
# Define the query to obtain user information.
#
# Note that uid 150 is the "vmail" user and gid 8 is the "mail" group.
#
user_query = \\
  SELECT '/var/vmail/%d/%n' as home, 'maildir:/var/vmail/%d/%n' as mail, \\
  150 AS uid, 8 AS gid, concat('dirsize:storage=', quota) AS quota \\
  FROM mailbox WHERE username = '%u' AND active = '1'
" >> $DOVECOT_CONF
unset DOVECOT_CONF

# set where Dovecot will read the SQL configuration files
echo "set where Dovecot will read the SQL configuration files"
DOVECOT_AUTH_CONF=/etc/dovecot/conf.d/10-auth.conf
sed -i "s,#disable_plaintext_auth =.*,disable_plaintext_auth = yes," $DOVECOT_AUTH_CONF
sed -i "s,auth_mechanisms =.*,auth_mechanisms = plain login," $DOVECOT_AUTH_CONF
sed -i 's,!include auth-system.conf.ext.*,#!include auth-system.conf.ext,' $DOVECOT_AUTH_CONF
sed -i 's,#!include auth-sql.conf.ext.*,!include auth-sql.conf.ext,' $DOVECOT_AUTH_CONF
unset DOVECOT_AUTH_CONF

# tell Dovecot where to put the virtual user mail directories.
echo "tell Dovecot where to put the virtual user mail directories."
DOVECOT_VMAIL_CONF=/etc/dovecot/conf.d/10-mail.conf
sed -i "s,^mail_location =.*,mail_location = maildir:/var/vmail/%d/%n," $DOVECOT_VMAIL_CONF
sed -i "s,^mail_location =.*,mail_location = maildir:/var/vmail/%d/%n," $DOVECOT_VMAIL_CONF
sed -i "s,#mail_uid =.*,mail_uid = vmail," $DOVECOT_VMAIL_CONF
sed -i "s,#mail_gid =.*,mail_gid = mail," $DOVECOT_VMAIL_CONF
sed -i "s,#last_valid_uid =.*,last_valid_uid = 150," $DOVECOT_VMAIL_CONF
sed -i "s,#first_valid_uid =.*,first_valid_uid = 150," $DOVECOT_VMAIL_CONF
unset DOVECOT_VMAIL_CONF

# ensure that some SSL protocols that are no longer secure are not used
echo "ensure that some SSL protocols that are no longer secure are not used"
DOVECOT_SSL_CONF=/etc/dovecot/conf.d/10-ssl.conf
sed -i "s,ssl = no.*,ssl = yes," $DOVECOT_SSL_CONF
sed -i "s,#ssl_cert =.*,ssl_cert = <$SSLPATH/$DOMAIN.crt," $DOVECOT_SSL_CONF
sed -i "s,#ssl_key =.*,ssl_key = <$SSLPATH/$DOMAIN.key," $DOVECOT_SSL_CONF
echo "set the ssl_ca = when using lets encrypt in $DOVECOT_SSL_CONF"
sed -i "s,#ssl_dh_parameters_length =.*,ssl_dh_parameters_length = 2048," $DOVECOT_SSL_CONF
sed -i 's,#ssl_protocols =.*,ssl_protocols = !SSLv2 !SSLv3,' $DOVECOT_SSL_CONF
sed -i "s,#ssl_prefer_server_ciphers =.*,ssl_prefer_server_ciphers = yes," $DOVECOT_SSL_CONF
sed -i 's,#ssl_cipher_list =.*,ssl_cipher_list = ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA,' $DOVECOT_SSL_CONF
unset DOVECOT_SSL_CONF

# add the Postfix option
echo "add the Postfix option"
DOVECOT_MASTER_CONF=/etc/dovecot/conf.d/10-master.conf
perl -i -p0e 's/unix_listener auth-userdb {.*?}/unix_listener auth-userdb {
    mode = 0666
    user = vmail
    group = mail
  }/s' $DOVECOT_MASTER_CONF

perl -i -p0e 's/#unix_listener \/var\/spool\/postfix\/private\/auth {.*?}/unix_listener \/var\/spool\/postfix\/private\/auth {
    mode = 0666
    # Assuming the default Postfix user and group
    user = postfix
    group = postfix
}/s' $DOVECOT_MASTER_CONF
unset DOVECOT_MASTER_CONF

# in case of error message "Invalid settings: postmaster_address setting not given" this might help
echo "
# Address to use when sending rejection mails.
# Default is postmaster@<your domain>.
postmaster_address = $POSTMASTER
" >> /etc/dovecot/conf.d/15-lda.conf

# set permissions for dovecot configuration
echo "set permissions for dovecot configuration"
chown -R vmail:dovecot /etc/dovecot
chmod -R o-rwx /etc/dovecot

# add clamav and amavis user to each others groups
echo "add clamav and amavis user to each others groups"
adduser clamav amavis
adduser amavis clamav

# not compatible with latest version clamvav
echo "AllowSupplementaryGroups was removed from clamav"
# adjust clamav config
# echo "adjust clamav config"
# echo "
# # Needed to allow things to work with Amavis, when both amavis and clamav
# # users are added to one another's groups.
# AllowSupplementaryGroups true
# " >> /etc/clamav/clamd.conf

# adtivate amavis
echo "activate amavis"
AMAVIS_CONF=/etc/amavis/conf.d/15-content_filter_mode
sed -i "s,#@bypass_virus_checks_maps,@bypass_virus_checks_maps," $AMAVIS_CONF
sed -i 's,#   \\%bypass_virus_checks,   \\%bypass_virus_checks,' $AMAVIS_CONF
sed -i "s,#@bypass_spam_checks_maps,@bypass_spam_checks_maps," $AMAVIS_CONF
sed -i 's,#   \\%bypass_spam_checks,   \\%bypass_spam_checks,' $AMAVIS_CONF
unset AMAVIS_CONF

# adtivate amavis
echo "activate amavis"
SAPMASSASSIN_CONF=/etc/default/spamassassin
sed -i 's,ENABLED=0,ENABLED=1,' $SAPMASSASSIN_CONF
sed -i 's,CRON=0,CRON=1,' $SAPMASSASSIN_CONF
unset SAPMASSASSIN_CONF

# amavis database connection to check for new mails
echo "amavis database connection to check for new mails"
AMAVIS_USER_ACCESS_CONF=/etc/amavis/conf.d/50-user
sed -i "s,#@bypass_virus_checks_maps,@bypass_virus_checks_maps," $AMAVIS_USER_ACCESS_CONF
sed -i -e '12,13d' $AMAVIS_USER_ACCESS_CONF
echo "
# Three concurrent processes. This should fit into the RAM available on an
# AWS micro instance. This has to match the number of processes specified
# for Amavis in /etc/postfix/master.cf.
\$max_servers  = 3;

# Add spam info headers if at or above that level - this ensures they
# are always added.
\$sa_tag_level_deflt  = -9999;

# Check the database to see if mail is for local delivery, and thus
# should be spam checked.
@lookup_sql_dsn = (
   ['DBI:mysql:database=$PFA_DB_NAME;host=127.0.0.1;port=3306',
    '$PFA_DB_USER',
    '$PFA_DB_PASS']);
\$sql_select_policy = 'SELECT domain from domain WHERE CONCAT("@",domain) IN (%k)';

# Uncomment to bump up the log level when testing.
# \$log_level = 2;

#------------ Do not modify anything below this line -------------
1;  # ensure a defined return
" >> $AMAVIS_USER_ACCESS_CONF

# ClamAV database is up to database
echo "ClamAV database is up to dat"
freshclam

# restart services for spam and virus
echo "restart services for spam and virus"
service clamav-daemon restart
service amavis restart
service spamassassin restart

# add information for postfix where to find database
echo "
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_NAME
query = SELECT goto FROM alias,alias_domain
  WHERE alias_domain.alias_domain = '%d'
  AND alias.address=concat('%u', '@', alias_domain.target_domain)
  AND alias.active = 1
" >> /etc/postfix/mysql_virtual_alias_domainaliases_maps.cf

echo "
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_NAME
table = alias
select_field = goto
where_field = address
additional_conditions = and active = '1'
" >> /etc/postfix/mysql_virtual_alias_maps.cf

echo "
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_NAME
table = domain
select_field = domain
where_field = domain
additional_conditions = and backupmx = '0' and active = '1'
" >> /etc/postfix/mysql_virtual_domains_maps.cf

echo "
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_NAME
query = SELECT maildir FROM mailbox, alias_domain
  WHERE alias_domain.alias_domain = '%d'
  AND mailbox.username=concat('%u', '@', alias_domain.target_domain )
  AND mailbox.active = 1
" >> /etc/postfix/mysql_virtual_mailbox_domainaliases_maps.cf

echo "
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_NAME
table = mailbox
select_field = CONCAT(domain, '/', local_part)
where_field = username
additional_conditions = and active = '1'
" >> /etc/postfix/mysql_virtual_mailbox_maps.cf

echo "
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_NAME
query = SELECT goto FROM alias WHERE address='%s'
" >> /etc/postfix/mysql_virtual_sender_login_maps.cf

# contains some directives to remove certain headers when relaying mail.
echo "contains some directives to remove certain headers when relaying mail."
echo "
/^Received:/                 IGNORE
/^User-Agent:/               IGNORE
/^X-Mailer:/                 IGNORE
/^X-Originating-IP:/         IGNORE
/^x-cr-[a-z]*:/              IGNORE
/^Thread-Index:/             IGNORE
" >> /etc/postfix/header_checks

# recommendation regarding postfix configuration file
echo "I strongly suggest that you spend some time reading up on Postfix configuration,"
read

# download main.cf fro postfix from github
mv /etc/postfix/main.cf /etc/postfix/main.cf.orig
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/template_main.cf -O /etc/postfix/main.cf
sed -i "s,myhostname = mail.example.com,myhostname = $DOMAIN," /etc/postfix/main.cf
sed -i "s,^smtpd_tls_cert_file=.*,smtpd_tls_cert_file=$SSLPATH/$DOMAIN.crt," /etc/postfix/main.cf
sed -i "s,^smtpd_tls_key_file=.*,smtpd_tls_key_file=$SSLPATH/$DOMAIN.key," /etc/postfix/main.cf
sed -i "s,# smtpd_tls_cert_file=.*,# smtpd_tls_cert_file=/etc/letsencrypt/live/$DOMAIN/fullchain.pem," /etc/postfix/main.cf
sed -i "s,# smtpd_tls_key_file=.*,# smtpd_tls_key_file=/etc/letsencrypt/live/$DOMAIN/privkey.pem," /etc/postfix/main.cf
sed -i "s,# smtpd_tls_CAfile=.*,# smtpd_tls_CAfile=/etc/letsencrypt/live/$DOMAIN/chain.pem," /etc/postfix/main.cf
sed -i "s,^smtpd_tls_dh1024_param_file =.*,smtpd_tls_dh1024_param_file = $SSLPATH/dhparams.pem," /etc/postfix/main.cf

# download master.cf fro postfix from github
mv /etc/postfix/master.cf /etc/postfix/master.cf.orig
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/template_master.cf  -O /etc/postfix/master.cf

# check the mysql version, if version is 5.5 do sed
echo "print mysql version"
mysql --version | awk '{ print $5 }'
MYSQLVERSION=`mysql --version | awk '{ print $5 }' | cut -c 1-3`
if [ "$MYSQLVERSION" == "5.5" ];
        then
        echo "remove the FROM_BASE64 in line 572, the function is only for mysql 5.6 and later"
        # attempt to remount the RW mount point as RW; else abort
        # put sed command here
        sed -i 's/"FROM_BASE64(###KEY###)"/"###KEY###"/' $WWWPATHHTML/postfixadmin/model/PFAHandler.php
fi

# Install SPF packages
echo "Install SPF packages"
apt-get install postfix-policyd-spf-python
sed -i "s,HELO_reject =.*,HELO_reject = False," /etc/postfix-policyd-spf-python/policyd-spf.conf
sed -i "s,Mail_From_reject =.*,Mail_From_reject = False," /etc/postfix-policyd-spf-python/policyd-spf.conf

echo "
# --------------------------------------
# SPF
# --------------------------------------
policy-spf_time_limit = 3600s" >> /etc/postfix/main.cf

sed -i "s@\(smtpd_recipient_restrictions =.*,\)\( permit\)@\1 check_policy_service unix:private/policy-spf, permit @" /etc/postfix/main.cf

echo "
# --------------------------------------
# SPF
# --------------------------------------
policy-spf  unix  -       n       n       -       -       spawn
     user=nobody argv=/usr/bin/policyd-spf
" >> /etc/postfix/master.cf

# Install DKIM and packiages
echo "Install DKIM and packages"
apt-get install opendkim opendkim-tools

# DMARC settings
# DNS entry at
# _dmarc.
# v=DMARC1; p=quarantine; rua=mailto:$WEBMASTER_MAIL; ruf=mailto:$WEBMASTER_MAIL; fo=0; adkim=r; aspf=r; pct=100; rf=afrf; ri=86400


# restart all services
echo "restart all serices again"
postfix stop && postfix start
service spamassassin restart
service clamav-daemon restart
service amavis restart
service dovecot restart
postfix restart

# Write mysql root password to file - keep it save
echo "Write root password into file /var/scripts/m-r-pass.txt, keep it safe"
echo $MYSQL_ROOT_PASS >> $SCRIPTS/m-r-pass.txt
echo $PFA_DB_PASS >> $SCRIPTS/m-r-pass.txt

echo "Installation succeded...
Press ENTER to finish"
read
