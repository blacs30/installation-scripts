#!/bin/bash
# install nginx
# geo blocking for nginx
# https://www.howtoforge.com/nginx-how-to-block-visitors-by-country-with-the-geoip-module-debian-ubuntu
# http://nginxlibrary.com/ip-based-country-blocking/


apt-get install nginx

sed -i "s,worker_processes.*;,worker_processes 2;," /etc/nginx/nginx.conf
sed -i "s,worker_connections.*,worker_connections 1024;," /etc/nginx/nginx.conf
sed -i "s,# server_tokens off;,server_tokens off;," /etc/nginx/nginx.conf
