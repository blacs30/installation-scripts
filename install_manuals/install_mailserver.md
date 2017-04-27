# Install Webmail Lite
There are a couple of webmail softwares out. The most known one is probably roundcube.
I have used the webmail lite though for long times and like it.

### Install prerequisites

Following components are required. Check other manuals on how to install them.
- mysql-server
- create an empty database too
- nginx  
- php-fpm

In case you want to use ssl:  
- ssl (or snakeoil certs)  
- optional but recommended to create a new stronger __dh key__

At first I install the required php components:  
`aptitude install software-properties-common php7.0 php7.0-mcrypt php7.0-curl php7.0-gd php7.0-mbstring php-xml-parser php7.0-common php7.0-cli php7.0-json	php7.0-readline	php7.0-mysql`

You can download the latest version via this url:  
e.g. `wget  https://www.afterlogic.org/download/webmail_php.zip`

There you'll also find the official documentation: [afterlogic.com](https://afterlogic.com/docs/webmail-lite/installation/installation-instructions/installing-on-linux)

Unzip the file and copy it to the target directory.
The path where I copy it to is e.g.: `/var/www/html/webmail`

You can use a service user for a PHP-FPM pool and the owner of the files in the web root directory. It requires little bit more carefulness but increases the security as well as little.

Create the user e.g. with these commands, it will not create a home directory and disallow the login:  
`useradd --no-create-home webmail`  
`usermod --lock webmail`

Now set the owner and permissions:
```
chown -R webmail:www-data /var/www/html/webmail/
find /var/www/html/webmail/ -type d -exec chmod 750 {} \;
find /var/www/html/webmail/ -type f -exec chmod 640 {} \;
```

For the php-fpm pool here is my template which I use, save it to e.g. `/etc/php/7.0/fpm/pool.d/webmail.conf`:  

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

;; webmail
[webmail]
env[HOSTNAME] = MyHostName
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/webmail.sock
listen.owner = webmail
listen.group = www-data
listen.mode = 0660
user = webmail
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/webmail-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

listen.backlog = 64
pm = ondemand
pm.max_children = 5
pm.max_requests = 200
pm.process_idle_timeout = 10s
```

As an optional step I have basic authentication activated for the adminpanel page, so that an additional password has to be entered.
This way it can be generated:  
`htpasswd -b -c /etc/nginx/.webmail webmail myPassword123`

As last step create the nginx vhost configuration, adjust it to your needs (ssl keys, hostname, paths..):

```
upstream webmail {
server unix:///run/php/webmail.sock;
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
root   					/var/www/html/webmail;
access_log     	/var/log/nginx/webmail-access.log;
error_log      	/var/log/nginx/webmail-error.log warn;

ssl    									on;
ssl_certificate        	/etc/ssl/my_ssl.crt;
ssl_certificate_key    	/etc/ssl/my_ssl.key;
ssl_dhparam             /etc/ssl/my_dhparams.pem;

index                   index.php;

include                 global/secure_ssl.conf;
include                 global/restrictions.conf;

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
auth_basic                    "Restricted";
auth_basic_user_file          /etc/nginx/.webmail;
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
```

Activate the vhost configuration and restart php-fpm and nginx:


`ln -s /etc/nginx/sites-available/webmail.conf /etc/nginx/sites-enabled/webmail`

```
systemctl restart php7.0-fpm
systemctl restart nginx
```
Run the installation wizard on this page:  
http(s)://$DOMAIN_APP_NAME/install/

After you finished delete the install directory.

You can find the admin panel in this url:
http(s)://$DOMAIN_APP_NAME/adminpanel/

___

## References
Information about the general setup  
- https://www.exratione.com/2016/05/a-mailserver-on-ubuntu-16-04-postfix-dovecot-mysql/

Information about dmarc spf dkim  
- https://www.skelleton.net/2015/03/21/how-to-eliminate-spam-and-protect-your-name-with-dmarc/

Information about amavis and spamassassin  
- https://thomas-leister.de/postfix-amavis-spamfilter-spamassassin-sieve/

Information about dkim  
- https://seasonofcode.com/posts/setting-up-dkim-and-srs-in-postfix.html

Information about sieve setup  
German  
- https://legacy.thomas-leister.de/dovecot-sieve-manager-installieren-und-einrichten/

Information regarding dane tlsa  
- https://dane.sys4.de/common_mistakes
- https://community.letsencrypt.org/t/please-avoid-3-0-1-and-3-0-2-dane-tlsa-records-with-le-certificates/7022/5
- http://www.internetsociety.org/deploy360/blog/2016/01/lets-encrypt-certificates-for-mail-servers-and-dane-part-1-of-2/
- https://www.internetsociety.org/deploy360/blog/2016/03/lets-encrypt-certificates-for-mail-servers-and-dane-part-2-of-2/

German  
- https://www.heinlein-support.de/sites/default/files/e-mail_made_in_germany_broken_by_design_ueberfluessig_dank_dane.pdf
- https://legacy.thomas-leister.de/dane-und-tlsa-dns-records-erklaert/
- https://legacy.thomas-leister.de/lets-encrypt-mit-hpkp-und-dane/
- https://www.kernel-error.de/projekte/postfix/postfix-dane-tlsa
