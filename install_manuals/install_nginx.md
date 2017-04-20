# Install Nginx
I choose to use nginx over apache as the configuration settings feel more comfortable to me. The performance is great too I cannot tell much regarding real numbers as the pages are not heavily visited.

### Let's go
Simply lets install nginx:  
`aptitude install nginx`  

If you want to have GEOIP based access and denies install the following packages, wget is required for downloading the latest GEOIP database:  
`aptitude install geoip-database libgeoip1 apache2-utils`  

It is good to refresh the GEOIP database after the installation.  
So lets backup the existing database:  
```shell
cd /usr/share/GeoIP
mv GeoIP.dat GeoIP.dat_bak
wget https://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz --no-check-certificate
gunzip GeoIP.dat.gz
```

I've put some scripts on Github which I use for general settings, e.g. SSL protocols and ciphers.. the next few steps describe the downloading and using them.

Create the global directory:  
`mkdir -p /etc/nginx/global`  

Download the scripts from github:  
- GEOIP settings  
`wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/geoip_settings.conf --no-check-certificate -O /etc/nginx/global/geoip_settings.conf`  
- global restrictions e.g. for favicon and robots file  
`wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/restrictions.conf --no-check-certificate -O /etc/nginx/global/restrictions.conf`  
- SSL settings  
`wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/secure_ssl.conf --no-check-certificate -O /etc/nginx/global/secure_ssl.conf`  
- wordpress configuration  
`wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/wordpress.conf --no-check-certificate -O /etc/nginx/global/wordpress.conf`  

I remove the default site normally and then create my own but this step is optional:  
`rm -rf /etc/nginx/sites-enabled/default`

Now adjust the nginx.conf, these settings vary depending on the machine and the requirements for the things you're going to host. You can find some information how to optimize the settings here [www.if-not-true-then-false.com](https://www.if-not-true-then-false.com/2011/nginx-and-php-fpm-configuration-and-optimizing-tips-and-tricks/).

In the file `/etc/nginx/nginx.conf` set:  
- `worker_processes 4`  
- `worker_connections 1024`  
- `server_tokens off`

Add the file include `geoip_settings.conf` into the global http configuration of the `nginx.conf`:  
- `include /etc/nginx/global/geoip_settings.conf`

## VHOST configuration
I have saved the following templates here on github:  
- big_oc (Big size pool for e.g. Owncloud/Nextcloud)
- middle_oc (Middle sized pool for e.g. Owncloud/Nextcloud )
- big_wp (Big size pool for e.g. Wordpress )
- middle (Middle sized pool for e.g. Wordpress and other sites)
- small (Small sized, on demand, pool, for e.g. administrative pages or lower traffic pages )

Here is an working example for the phphmyadmin installation, per default I always use SSL, it's free and not really that difficult anymore. Some settings have to be adjust (hostname, path to root, certs, etc...):  

```
upstream phpmyadmin {
server unix:///run/php/phpmyadmin.sock;
}

server {
listen 		80;
server_name     mydomain.com;
location / {
return 301 https://\$server_name\$request_uri;
}
}

server {
listen 					443 ssl http2;
listen          [::]:443 ssl http2;
server_name    	mydomain.com;
root   					/var/www/html;
access_log     	/var/log/nginx/phpmyadmin-access.log;
error_log      	/var/log/nginx/phpmyadmin-error.log warn;

ssl    									on;
ssl_certificate        	/etc/ssl/my_ssl.crt;
ssl_certificate_key    	/etc/ssl/my_ssl.key;
ssl_dhparam             /etc/ssl/my_dhparams.pem;

index                   index.php;

include                 global/secure_ssl.conf;
include                 global/restrictions.conf;
client_header_timeout   3m;

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
include /etc/nginx/fastcgi_params;
fastcgi_pass phpmyadmin;
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
}

location /phpmyadmin {
auth_basic                    "Restricted";
auth_basic_user_file          /etc/nginx/.phpmyadmin;
index                         index.php index.html index.htm;

location ~ ^/phpmyadmin/(.+\.php)\$ {
try_files           \$uri =404;
fastcgi_param       HTTPS on;
fastcgi_pass        phpmyadmin;
fastcgi_index       index.php;
fastcgi_param       SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
include             fastcgi_params;
charset             utf8;
client_max_body_size  64m; #change this if ur export is bigger than 64mb.
client_body_buffer_size 128k;
}

location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
}
}

location /phpMyAdmin {
rewrite ^/* /phpmyadmin last;
}
}
```
