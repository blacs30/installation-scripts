#!/bin/bash
# install nginx
# geo blocking for nginx
# https://www.howtoforge.com/nginx-how-to-block-visitors-by-country-with-the-geoip-module-debian-ubuntu
# http://nginxlibrary.com/ip-based-country-blocking/


apt-get install nginx geoip-database libgeoip1

sed -i "s,worker_processes.*;,worker_processes 2;," /etc/nginx/nginx.conf
sed -i "s,worker_connections.*,worker_connections 1024;," /etc/nginx/nginx.conf
sed -i "s,# server_tokens off;,server_tokens off;," /etc/nginx/nginx.conf

echo "download latest geoip database"
mv /usr/share/GeoIP/GeoIP.dat /usr/share/GeoIP/GeoIP.dat_bak
cd /usr/share/GeoIP/
wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
gunzip GeoIP.dat.gz
cd /tmp
