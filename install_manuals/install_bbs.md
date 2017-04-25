# Install BicBucStriim (BBS)
BBS is a webinterface for ebooks. It shows the calibre database and allows to view, send and download ebooks in different formats.
Mainly I use COPS 1.x because of its features in OPDS searching but nontheless this is nice software.

### Install prerequisites

Following components are required. Check other manuals on how to install them.
- nginx  
- php-fpm

In case you want to use ssl:  
- ssl (or snakeoil certs)  
- optional but recommended to create a new stronger __dh key__

At first I install the required php components:  
`aptitude install php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-gd php7.0-intl php7.0-json php7.0-mcrypt php7.0-opcache php7.0-sqlite3 php7.0-xml`

You can download the latest version (of this writing) via this url:  
e.g. `wget https://github.com/rvolz/BicBucStriim/archive/v1.3.6.zip`

Unzip the file and copy it to the target directory.  
The path where I copy it to is e.g.: `/var/www/html/bbs`

You can use a service user for a PHP-FPM pool and the owner of the files in the web root directory. It requires little bit more carefulness but increases the security as well as little.

Create the user e.g. with these commands, it will not create a home directory and disallow the login:  
`useradd --no-create-home bbs`  
`usermod --lock bbs`

Now set the owner and permissions:
```
chown -R bbs:www-data /var/www/html/bbs/
find /var/www/html/bbs/ -type d -exec chmod 750 {} \;
find /var/www/html/bbs/ -type f -exec chmod 640 {} \;
```

Depending on the permission settings may the files be owned by a different user. To be able to access these files the bbs user has to be added to the owncloud group.  
`usermod --append --groups owncloud bbs`

For the php-fpm pool here is my template which I use, save it to e.g. `/etc/php/7.0/fpm/pool.d/bbs.conf`:  

```
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

;; bbs
[bbs]
env[HOSTNAME] = MyHostName
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/bbs.sock
listen.owner = bbs
listen.group = www-data
listen.mode = 0660
user = bbs
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/bbs-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

listen.backlog = 64
pm = ondemand
pm.max_children = 5
pm.max_requests = 200
pm.process_idle_timeout = 10s
```

As next step create the nginx vhost configuration, adjust it to your needs (ssl keys, hostname, paths..):

```
upstream bbs {
server unix:///run/php/bbs.sock;
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
root   					/var/www/html/bbs;
access_log     	/var/log/nginx/bbs-access.log;
error_log      	/var/log/nginx/bbs-error.log warn;

ssl    									on;
ssl_certificate        	/etc/ssl/my_ssl.crt;
ssl_certificate_key    	/etc/ssl/my_ssl.key;
ssl_dhparam             /etc/ssl/my_dhparams.pem;

index                   index.php;

include                 global/secure_ssl.conf;

# Additional rules go here.
include                 global/restrictions.conf;

# if (\$allow_visit = no) { return 403 };

location / {
rewrite ^/(img/.*)$ /\$1 break;
rewrite ^/(js/.*)$ /\$1 break;
rewrite ^/(style/.*)$ /\$1 break;
rewrite ^/$ /index.php last;
rewrite ^/(admin|authors|authorslist|login|logout|metadata|search|series|serieslist|tags|tagslist|titles|titleslist|opds)/.*$ /index.php last;
}

location ~* \.(?:ico|css|js|gif|jpe?g|png|ttf|woff|svg|eot)$ {
# Some basic cache-control for static files to be sent to the browser
expires max;
add_header Pragma public;
add_header Cache-Control "public, must-revalidate, proxy-revalidate";
}

location ~ \.php$ {
try_files \$uri \$uri/ /index.php;
include fastcgi.conf;
fastcgi_pass   bbs;
}
}
```

Activate the vhost configuration and restart php-fpm and nginx:


`ln -s /etc/nginx/sites-available/bbs.conf /etc/nginx/sites-enabled/bbs`

```
systemctl restart php7.0-fpm
systemctl restart nginx
```

That's it. The initial user and password are:  
admin:admin
