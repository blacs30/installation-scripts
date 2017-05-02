#!/usr/bin/env bash

# load variables
source /vagrant/environment.sh

$INSTALLER install --assume-yes git

useradd --no-create-home "$SERVICE_USER_DRAW"
usermod --lock "$SERVICE_USER_DRAW"


# create www folder
if [ ! -d "$HTML_ROOT_DRAW" ]; then
  mkdir -p "$HTML_ROOT_DRAW"
fi

cd "$HTML_ROOT_DRAW"

GIT_REPO_URL=https://github.com/jgraph/draw.io.git

git clone $GIT_REPO_URL .


# Set permissions to files and directories
chown -R "$SERVICE_USER_DRAW":www-data "$HTML_ROOT_DRAW"/
find "$HTML_ROOT_DRAW" -type d -exec chmod 750 {} \;
find "$HTML_ROOT_DRAW" -type f -exec chmod 640 {} \;


##########################
# Create the nginx vhost
##########################
cat << DRAW_VHOST > "$NGINX_VHOST_PATH_DRAW"
server {

	listen 80;
	server_name $VHOST_SERVER_NAME_DRAW;
	location / {

		return 301 https://\$server_name\$request_uri;
	}
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name $VHOST_SERVER_NAME_DRAW;
	root $HTML_ROOT_DRAW/war;
	access_log /var/log/nginx/${APPNAME_DRAW}-access.log;
	error_log /var/log/nginx/${APPNAME_DRAW}-error.log warn;

	ssl on;
	ssl_certificate $TLS_CERT_FILE;
	ssl_certificate_key $TLS_KEY_FILE;
	ssl_dhparam $DH_PARAMS_FILE;

	index index.html;

	include global/secure_ssl.conf;
	include global/restrictions.conf;
	client_max_body_size 20M;

	# if (\$allow_visit = no) { return 403 };
}

DRAW_VHOST

ln -s "$NGINX_VHOST_PATH_DRAW" /etc/nginx/sites-enabled/"$APPNAME_DRAW"


nginx -t && systemctl restart nginx
