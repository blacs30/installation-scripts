#!/usr/bin/env bash

source /vagrant/environment.sh

curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash

$INSTALLER update
$INSTALLER install -y gitlab-ce

gitlab-ctl reconfigure

#GITLAB_CONFIG=/etc/gitlab/gitlab.rb
sed -i "s|^external_url '.*|external_url '$GITLAB_URL'|" "$GITLAB_CONFIG"
sed -i "s|.*web_server\['external_users'\].*|web_server['external_users'] = ['www-data']|" "$GITLAB_CONFIG"
awk -v q="'" 'NR==1,/nginx\[\x27enable\x27\].*/{sub(/.*nginx\[\x27enable\x27\].*/, "nginx[\x27enable\x27] = false")} 1' "$GITLAB_CONFIG" > "$GITLAB_CONFIG".tmp && mv "$GITLAB_CONFIG".tmp "$GITLAB_CONFIG"

gitlab-ctl reconfigure


#
# write nginx vhost
#
cat << GITLAB_VHOST > "$NGINX_VHOST_PATH_GITLAB"
upstream gitlab-workhorse {

  server unix:/var/opt/gitlab/gitlab-workhorse/socket;
}

server {

	listen 80;
	# enforce https
	server_name $VHOST_SERVER_NAME_GITLAB;
	location / {

		return 301 https://\$server_name\$request_uri;
	}
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name $VHOST_SERVER_NAME_GITLAB;
	access_log /var/log/nginx/${APPNAME_GITLAB}-access.log;
	error_log /var/log/nginx/${APPNAME_GITLAB}_error.log warn;

	ssl on;
	ssl_certificate $TLS_CERT_FILE;
	ssl_certificate_key $TLS_KEY_FILE;
	ssl_dhparam $DH_PARAMS_FILE;

	include global/secure_ssl.conf;
	include global/restrictions.conf;

	client_max_body_size 20M;

	index index.php;

	# Additional rules go here.


	# This block is for GEOIP blocking / allowing
	# if ($allow_visit = no) {
	#    return 403;
	# }

	location / {

		## If you use HTTPS make sure you disable gzip compression
		## to be safe against BREACH attack.

		## https://github.com/gitlabhq/gitlabhq/issues/694
		## Some requests take more than 30 seconds.
		proxy_read_timeout 3600;
		proxy_connect_timeout 300;
		proxy_redirect off;
		proxy_http_version 1.1;

		proxy_set_header Host \$http_host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header X-Forwarded-Proto https;

		proxy_pass http://gitlab-workhorse;
	}

	error_page 404 /404.html;
	error_page 422 /422.html;
	error_page 500 /500.html;
	error_page 502 /502.html;

	location ~ ^/(404|422|500|502)(-custom)?\.html$ {

		root /opt/gitlab/embedded/service/gitlab-rails/public;
		internal;
	}
}
GITLAB_VHOST

ln -s "$NGINX_VHOST_PATH_GITLAB" /etc/nginx/sites-enabled/"$APPNAME_GITLAB"


nginx -t && systemctl reload nginx
