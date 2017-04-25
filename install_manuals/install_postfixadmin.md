# Install postfixadmin
Postfixadmin is a helpful web ui for postfix. It helps to administer mail boxes, domains, aliases and more.

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
`aptitude install software-properties-common php7.0 php7.0-mcrypt php7.0-curl php7.0-gd php7.0-mbstring php-xml-parser php7.0-common php7.0-cli php7.0-json php7.0-readline php7.0-imap php7.0-mysql`

You can download the latest (at time of writing) version via this url:  
e.g. `wget  https://netcologne.dl.sourceforge.net/project/postfixadmin/postfixadmin/postfixadmin-3.0.2/postfixadmin-3.0.2.tar.gz`

Unzip the file and copy it to the target directory.
The path where I copy it to is e.g.: `/var/www/html/pfa`

Create the initial configuration file by downloading my template into the main folder :  
`wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/postfixadmin.config.local.php`

The template has to be adjusted but it contains helpful comments how the changes affect the behavior.

I adjust the following settings:  
- postfix_admin_url
- database_user
- database_password
- database_name
- admin_email
- admin@example.com
- footer_text
- footer_link


In case you have mysql version 5.5. (check with `mysql -version`) there is a change in this file needed. The FROM_BASE64 function doesn't exist yet in that mysql version, it was added in 5.6.1.  
- /var/www/html/pfa/model/PFAHandler.php  
    - Search for "FROM_BASE64(###KEY###)" and change it to "###KEY###"


You can use a service user for a PHP-FPM pool and the owner of the files in the web root directory. It requires little bit more carefulness but increases the security as well as little.

Create the user e.g. with these commands:  
`useradd --no-create-home pfa`
`usermod --lock pfa`

Now set the owner and permissions:
```
chown -R pfa:www-data /var/www/html/pfa/
find /var/www/html/pfa/ -type d -exec chmod 750 {} \;
find /var/www/html/pfa/ -type f -exec chmod 640 {} \;
```

For the php-fpm pool here is my template which I use, save it to e.g. `/etc/php/7.0/fpm/pool.d/pfa.conf`:  

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

;; pfa
[pfa]
env[HOSTNAME] = MyHostName
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/pfa.sock
listen.owner = pfa
listen.group = www-data
listen.mode = 0660
user = pfa
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/pfa-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

listen.backlog = 64
pm = ondemand
pm.max_children = 5
pm.max_requests = 200
pm.process_idle_timeout = 10s
```

As an optional step I have basic authentication activated for the pfa page, so that an additional password has to be entered.
This way it can be generated:  
`htpasswd -b -c /etc/nginx/.pfa pfa myPassword123`

As last step create the nginx vhost configuration, adjust it to your needs (ssl keys, hostname, paths..):

```
upstream pfa {
server unix:///run/php/pfa.sock;
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
root   					/var/www/html/pfa;
access_log     	/var/log/nginx/pfa-access.log;
error_log      	/var/log/nginx/pfa-error.log warn;

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

location /pfa {
auth_basic                    "Restricted";
auth_basic_user_file          /etc/nginx/.pfa;
index index.php index.html index.htm;
location ~ ^/pfa/(.+\.php)$ {
try_files \$uri =404;
fastcgi_param HTTPS on;
fastcgi_pass pfa;
fastcgi_index index.php;
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
include /etc/nginx/fastcgi_params;
}
location ~* \.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|tpl(\.php)?|xtmpl)$|^(\..*|Entries.*|Repository|Root|Tag|Template)$|\.php_ {
deny all;
}
location ~* ^/pfa/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
}
}

## enable this location to forbid setup.php access
## after the superuser has been created
#location = /postfixadmin/setup.php {
#        deny all;
#        access_log off;
#        log_not_found off;
#}
}
```

Activate the vhost configuration and restart php-fpm and nginx:


`ln -s /etc/nginx/sites-available/pfa.conf /etc/nginx/sites-enabled/pfa`

```
systemctl restart php7.0-fpm
systemctl restart nginx
```

In the browser open the page https://mydomain.com/pfa/setup.php. You will be asked to enter a setup password twice. That will generate a hash which needs to be added in the config file from before. Add this line:  
`CONF['setup_password'] = 'GENERATED_SETUP_HASH';`

With version 3.x the postfixadmin-cli was introduced. It allows the creation of a superadmin via the shell. That is nice for automated installation. The command could look like this:  
- open the setup.php page so that the tables etc are created in the database  
`curl https://$NGINX_BASIC_AUTH_PFA_USER:$NGINX_BASIC_AUTH_PFA_PW@localhost/pfa/setup.php --insecure`  
- run the command to create a superuser:  
`bash /var/www/html/pfa/scripts/postfixadmin-cli admin add webmaster@test.com --password $POSTMASTER_PASSWORD --password2 $POSTMASTER_PASSWORD --superadmin`

Don't refresh the browser, just continue to create the superuser.

>Now that the superuser is created you can enable the deny all to the setup.php in the nginx vhost to prevent access to that page.

You can now login to postfixadmin and configure your domains, aliases etc.
