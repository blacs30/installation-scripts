#!/usr/bin/env bash

# load variables
source /vagrant/environment.sh

$INSTALLER install -y software-properties-common php7.0 php7.0-mcrypt php7.0-curl php7.0-gd php7.0-mbstring php-xml-parser php7.0-common php7.0-cli php7.0-json php7.0-readline php7.0-imap php7.0-mysql

useradd --no-create-home "$SERVICE_USER_PFA"
usermod --lock "$SERVICE_USER_PFA"

# create www folder
if [ ! -d "$HTML_ROOT_PFA" ]; then
  mkdir -p "$HTML_ROOT_PFA"
fi

SOFTWARE_URL=https://netcologne.dl.sourceforge.net/project/postfixadmin/postfixadmin/postfixadmin-3.0.2/postfixadmin-3.0.2.tar.gz
SOFTWARE_ZIP=$(basename $SOFTWARE_URL)
SOFTWARE_DIR=$(printf "%s" "$SOFTWARE_ZIP" | sed -e 's/.tar.gz//')

cd /tmp
wget $SOFTWARE_URL
tar -xf /tmp/"$SOFTWARE_ZIP"
cp -r "$SOFTWARE_DIR"/* "$HTML_ROOT_PFA"
if [ -f /tmp/"$SOFTWARE_ZIP" ]; then
  rm -f /tmp/"$SOFTWARE_ZIP"
fi

if [ -d /tmp/"$SOFTWARE_DIR" ]; then
  rm -rf /tmp/"$SOFTWARE_DIR"
fi

#
# create database
#
cat << EOF > /tmp/createdb.sql
CREATE DATABASE IF NOT EXISTS $MYSQL_DB_PFA;
GRANT ALL PRIVILEGES ON $MYSQL_DB_PFA.* TO '$MYSQL_PFA_USER'@'$MYSQL_DB_HOST' IDENTIFIED BY '$MYSQL_PFA_PASS';
quit
EOF

mysql -uroot -p"$MYSQL_ROOT_PASS" -h"$MYSQL_DB_HOST" < /tmp/createdb.sql

if [ -f /tmp/createdb.sql ]; then
  rm -f /tmp/createdb.sql
fi


#create new empty postfix local config file
POSTFIXADM_CONF_FILE=$HTML_ROOT_PFA/config.local.php
touch "$POSTFIXADM_CONF_FILE"

#download postfixadmin template
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/postfixadmin.config.local.php --no-check-certificate -O "$POSTFIXADM_CONF_FILE"

chown -R "$SERVICE_USER_PFA":www-data "$HTML_ROOT_PFA"
find "$HTML_ROOT_PFA" -type d -exec chmod 750 {} \;
find "$HTML_ROOT_PFA" -type f -exec chmod 640 {} \;

sed -i "s,.*'postfix_admin_url'.*,\$CONF['postfix_admin_url'] = 'https://$VHOST_SERVER_NAME_PFA';," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'database_host'.*,\$CONF['database_host'] = '$MYSQL_DB_HOST';," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'database_user'.*,\$CONF['database_user'] = '$MYSQL_PFA_USER';," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'database_password'.*,\$CONF['database_password'] = '$MYSQL_PFA_PASS';," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'database_name'.*,\$CONF['database_name'] = '$MYSQL_DB_PFA';," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'admin_email'.*,\$CONF['admin_email'] = '$PFA_POSTMASTER';," "$POSTFIXADM_CONF_FILE"
sed -i "s,'admin@example.com','$PFA_POSTMASTER'," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'footer_text'.*,\$CONF['footer_text'] = 'Return to $VHOST_SERVER_NAME_PFA';," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'footer_link'.*,\$CONF['footer_link'] = 'https://$VHOST_SERVER_NAME_PFA';," "$POSTFIXADM_CONF_FILE"

MYSQLVERSION=$(mysql --version | awk '{ print $5 }' | cut -c 1-3)
if [ "$MYSQLVERSION" = "5.5" ]; then
  sed -i 's/"FROM_BASE64(###KEY###)"/"###KEY###"/' "$HTML_ROOT_PFA"/model/PFAHandler.php
fi


# create basic auth for nginx
htpasswd -b -c /etc/nginx/."${NGINX_BASIC_AUTH_PFA_FILE}" "${NGINX_BASIC_AUTH_PFA_USER}" "${NGINX_BASIC_AUTH_PFA_PW}"

##########################
# Create the php fpm pool
##########################
cat << PFA_POOL > "$POOL_CONF_PATH_PFA"
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

;; $APPNAME_PFA
[$APPNAME_PFA]
env[HOSTNAME] = $HOST_NAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/$PHP_OWNER_PFA.sock
listen.owner = $PHP_OWNER_PFA
listen.group = www-data
listen.mode = 0660
user = $PHP_OWNER_PFA
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/$PHP_OWNER_PFA-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

listen.backlog = 64
pm = ondemand
pm.max_children = 5
pm.max_requests = 200
pm.process_idle_timeout = 10s
PFA_POOL

##########################
# Create the nginx vhost
##########################
cat << PFA_VHOST > "$NGINX_VHOST_PATH_PFA"
upstream pfa {

	server unix:///run/php/$PHP_OWNER_PFA.sock;
}

server {

	listen 80;
	server_name $VHOST_SERVER_NAME_PFA;
	location / {

		return 301 https://\$server_name\$request_uri;
	}
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name $VHOST_SERVER_NAME_PFA;
	root $HTML_ROOT_PFA;
	access_log /var/log/nginx/${APPNAME_PFA}-access.log;
	error_log /var/log/nginx/${APPNAME_PFA}-error.log warn;

	ssl on;
	ssl_certificate $TLS_CERT_FILE;
	ssl_certificate_key $TLS_KEY_FILE;
	ssl_dhparam $DH_PARAMS_FILE;

	index index.php;

	include global/secure_ssl.conf;
	include global/restrictions.conf;
	client_header_timeout 3m;

	# Configure GEOIP access before enabling this setting
	# if (\$allow_visit = no) { return 403 };

	location / {

		auth_basic "Restricted";
		auth_basic_user_file /etc/nginx/.${NGINX_BASIC_AUTH_PFA_FILE};
		index index.php index.html index.htm;
		location ~ ^/(.+\.php)$ {

			try_files \$uri =404;
			fastcgi_param HTTPS on;
			fastcgi_pass pfa;
			fastcgi_index index.php;
			fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
			include /etc/nginx/fastcgi_params;
		}

		location ~* \.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|tpl(\.php)?|xtmpl)$|^(\..*|Entries.*|Repository|Root|Tag|Template)$|\.php_ {

			deny all;
		}

		location ~* ^/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {

		}
	}

	## enable this location to forbid setup.php access
	## after the superuser has been created
	#location = /setup.php {
	#
	#	deny all;
	#	access_log off;
	#	log_not_found off;
	#}
}
PFA_VHOST

ln -s "$NGINX_VHOST_PATH_PFA" /etc/nginx/sites-enabled/"$APPNAME_PFA"

systemctl restart php7.0-fpm && systemctl restart nginx

# check the response code of the url call
response=$(curl --write-out %{http_code} --silent --output /dev/null https://"$NGINX_BASIC_AUTH_PFA_USER":"$NGINX_BASIC_AUTH_PFA_PW"@"$VHOST_SERVER_NAME_PFA"/setup.php --insecure)

# if response is not 200 (OK) then add the server domain name into the hosts.
# remove it after run the curl again
if [ "$response" != "200" ]; then
 	echo "127.0.0.1 $VHOST_SERVER_NAME_PFA" >> /etc/hosts
	curl https://"$NGINX_BASIC_AUTH_PFA_USER":"$NGINX_BASIC_AUTH_PFA_PW"@"$VHOST_SERVER_NAME_PFA"/setup.php --insecure
	sed -i "/$VHOST_SERVER_NAME_PFA/d" /etc/hosts
fi


# create the create the user admin for the postfixadmin ui
bash "$HTML_ROOT_PFA"/scripts/postfixadmin-cli admin add "$PFA_POSTMASTER" --password "$PFA_POSTMASTER_PASSWORD" --password2 "$PFA_POSTMASTER_PASSWORD" --superadmin

# create the initial domain in postfixadmin
bash "$HTML_ROOT_PFA"/scripts/postfixadmin-cli domain add "$PFA_DOMAIN_NAME" --description "$PFA_DOMAIN_DESCRIPTION" --aliases 100 --mailboxes 50

# create the required admin mailbox
bash "$HTML_ROOT_PFA"/scripts/postfixadmin-cli mailbox add admin@"$PFA_DOMAIN_NAME" --password "$MAIL_ADMIN_PASSWORD" --password2 "$MAIL_ADMIN_PASSWORD" --name Administrator --quota 0 --active 1 --welcome-mail 1
