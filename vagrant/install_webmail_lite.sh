#!/usr/bin/env bash

# load variables
source /vagrant/environment.sh

$INSTALLER install -y software-properties-common php7.0 php7.0-mcrypt php7.0-curl php7.0-gd php7.0-mbstring php-xml-parser php7.0-common php7.0-cli php7.0-json	php7.0-readline	php7.0-mysql


#
# create database
#
cat << EOF > /tmp/createdb.sql
CREATE DATABASE IF NOT EXISTS $MYSQL_DB_WEBMAIL;
GRANT ALL PRIVILEGES ON $MYSQL_DB_WEBMAIL.* TO '$MYSQL_WEBMAIL_USER'@'$MYSQL_DB_HOST' IDENTIFIED BY '$MYSQL_WEBMAIL_PASS';
quit
EOF

mysql -uroot -p"$MYSQL_ROOT_PASS" -h"$MYSQL_DB_HOST" < /tmp/createdb.sql

if [ -f /tmp/createdb.sql ]; then
  rm -f /tmp/createdb.sql
fi


useradd --no-create-home "$SERVICE_USER_WEBMAIL"
usermod --lock "$SERVICE_USER_WEBMAIL"


# create www folder
if [ ! -d "$HTML_ROOT_WEBMAIL" ]; then
  mkdir -p "$HTML_ROOT_WEBMAIL"
fi


AL_WEBMAIL_URL=https://www.afterlogic.org/download/webmail_php.zip
AL_WEBMAIL_ZIP=webmail_php.zip

wget $AL_WEBMAIL_URL -O /tmp/$AL_WEBMAIL_ZIP
unzip /tmp/$AL_WEBMAIL_ZIP
cp -rT webmail "$HTML_ROOT_WEBMAIL"/

if [ -d /tmp/webmail ]; then
  rm -rf /tmp/webmail
fi

if [ -d "$HTML_ROOT_WEBMAIL"/install ]; then
  rm -rf "$HTML_ROOT_WEBMAIL"/install
fi

# Set permissions to files and directories
chown -R "$SERVICE_USER_WEBMAIL":www-data "$HTML_ROOT_WEBMAIL"/
find "$HTML_ROOT_WEBMAIL" -type d -exec chmod 750 {} \;
find "$HTML_ROOT_WEBMAIL" -type f -exec chmod 640 {} \;


# create basic auth for nginx
htpasswd -b -c /etc/nginx/."${NGINX_BASIC_AUTH_WEBMAIL_FILE}" "${NGINX_BASIC_AUTH_WEBMAIL_USER}" "${NGINX_BASIC_AUTH_WEBMAIL_PW}"


##########################
# Create the php fpm pool
##########################
cat << WEBMAIL_POOL > "$POOL_CONF_PATH_WEBMAIL"
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

;; $APPNAME_WEBMAIL
[$APPNAME_WEBMAIL]
env[HOSTNAME] = $HOST_NAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/$PHP_OWNER_WEBMAIL.sock
listen.owner = $PHP_OWNER_WEBMAIL
listen.group = www-data
listen.mode = 0660
user = $PHP_OWNER_WEBMAIL
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/$PHP_OWNER_WEBMAIL-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

listen.backlog = 64
pm = ondemand
pm.max_children = 5
pm.max_requests = 200
pm.process_idle_timeout = 10s
WEBMAIL_POOL



##########################
# Create the nginx vhost
##########################
cat << WEBMAIL_VHOST > "$NGINX_VHOST_PATH_WEBMAIL"
upstream webmail {

	server unix:///run/php/$PHP_OWNER_WEBMAIL.sock;
}

server {

	listen 80;
	server_name $VHOST_SERVER_NAME_WEBMAIL;
	location / {

		return 301 https://\$server_name\$request_uri;
	}
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name $VHOST_SERVER_NAME_WEBMAIL;
	root $HTML_ROOT_WEBMAIL;
	access_log /var/log/nginx/${PHP_OWNER_WEBMAIL}-access.log;
	error_log /var/log/nginx/${PHP_OWNER_WEBMAIL}-error.log warn;

	ssl on;
	ssl_certificate $TLS_CERT_FILE;
	ssl_certificate_key $TLS_KEY_FILE;
	ssl_dhparam $DH_PARAMS_FILE;

	index index.php;

	include global/secure_ssl.conf;
	include global/restrictions.conf;

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
		include fastcgi_params;
		fastcgi_buffers 16 16k;
		fastcgi_buffer_size 32k;
		fastcgi_pass webmail;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
	}

	location /adminpanel {

		auth_basic "Restricted";
		auth_basic_user_file /etc/nginx/.${NGINX_BASIC_AUTH_WEBMAIL_FILE};
	}

	location / {

		location ~ ^/(.+\.php)$ {

			try_files \$uri =404;
			fastcgi_param HTTPS on;
			fastcgi_buffers 16 16k;
			fastcgi_buffer_size 32k;
			fastcgi_pass webmail;
			fastcgi_index index.php;
			fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
			include fastcgi_params;
		}

		location ~* ^/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {

		}
	}
}
WEBMAIL_VHOST

ln -s "$NGINX_VHOST_PATH_WEBMAIL" /etc/nginx/sites-enabled/"$APPNAME_WEBMAIL"



systemctl restart php7.0-fpm && systemctl restart nginx



# webmail configuration
WEBMAIL_CONFIG_FILE="$HTML_ROOT_WEBMAIL"/data/settings/settings.xml

sed -i "s|<SiteName.*|<SiteName>$WEBMAIL_SITENAME</SiteName>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<AdminLogin.*|<AdminLogin>admin</AdminLogin>|" $WEBMAIL_CONFIG_FILE

sed -i "s|<DBType.*|<DBType>MySQL</DBType>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<DBPrefix.*|<DBPrefix>${TABLE_PREFIX_WEBMAIL}</DBPrefix>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<DBHost.*|<DBHost>$MYSQL_DB_HOST</DBHost>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<DBName.*|<DBName>$MYSQL_DB_WEBMAIL</DBName>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<DBLogin.*|<DBLogin>$MYSQL_WEBMAIL_USER</DBLogin>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<DBPassword.*|<DBPassword>$MYSQL_WEBMAIL_PASS</DBPassword>|" $WEBMAIL_CONFIG_FILE

sed -i "s|<IncomingMailProtocol.*|<IncomingMailProtocol>IMAP4</IncomingMailProtocol>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<IncomingMailServer.*|<IncomingMailServer>$IMAP_SERVER</IncomingMailServer>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<IncomingMailPort.*|<IncomingMailPort>993</IncomingMailPort>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<IncomingMailUseSSL.*|<IncomingMailUseSSL>On</IncomingMailUseSSL>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<OutgoingMailServer.*|<OutgoingMailServer>$SMTP_SERVER</OutgoingMailServer>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<OutgoingMailPort.*|<OutgoingMailPort>465</OutgoingMailPort>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<OutgoingMailUseSSL.*|<OutgoingMailUseSSL>On</OutgoingMailUseSSL>|" $WEBMAIL_CONFIG_FILE

sed -i "s|<MailsPerPage.*|<MailsPerPage>200</MailsPerPage>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<AllowCalendar.*|<AllowCalendar>On</AllowCalendar>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<ShowWeekEnds.*|<ShowWeekEnds>Off</ShowWeekEnds>^|" $WEBMAIL_CONFIG_FILE
sed -i "s|<ContactsPerPage.*|<ContactsPerPage>50</ContactsPerPage>|" $WEBMAIL_CONFIG_FILE
sed -i "s|<AllowFiles.*|<AllowFiles>On</AllowFiles>|" $WEBMAIL_CONFIG_FILE
