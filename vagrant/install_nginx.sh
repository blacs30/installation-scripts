#!/usr/bin/env bash

source /vagrant/environment.sh

$INSTALLER install -y nginx

# download and update the geoip database and tools
$INSTALLER install -y geoip-database libgeoip1 apache2-utils
cd /usr/share/GeoIP
mv GeoIP.dat GeoIP.dat_bak
wget https://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz --no-check-certificate
gunzip GeoIP.dat.gz

# download config templates from github
mkdir -p $NGINX_DIR/global
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/geoip_settings.conf --no-check-certificate -O $NGINX_DIR/global/geoip_settings.conf
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/restrictions.conf --no-check-certificate -O $NGINX_DIR/global/restrictions.conf
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/secure_ssl.conf --no-check-certificate -O $NGINX_DIR/global/secure_ssl.conf
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/wordpress.conf --no-check-certificate -O $NGINX_DIR/global/wordpress.conf

# remove the default site
rm -rf $NGINX_DIR/sites-enabled/default

# set server tokens off
sed -i -r -e 's/.*server_tokens.*/        server_tokens off;/' "$NGINX_CONF"

# add the geoip settings to the global http config
sed -i -e '/^http {/ a \ \ \ \ \ \ \ \ # Include geoip settings' "$NGINX_CONF"
sed -i -e '/^http {/ a \ \ \ \ \ \ \ \ include /etc/nginx/global/geoip_settings.conf;' "$NGINX_CONF"

# set the worker_processes to 4
sed -i -e 's/worker_processes.*/worker_processes 4;/' "$NGINX_CONF"

# set the worker_connections to 1024
sed -i -r -e 's/.*worker_connections.*/        worker_connections 1024;/' "$NGINX_CONF"

systemctl restart nginx
