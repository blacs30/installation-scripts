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
