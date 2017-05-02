# Install Owncloud
This is a manual for an owncloud installation.
I will use mysql, nginx and redis caching for it.

### Install prerequisites

Following components are required. Check other manuals on how to install them.
- mysql-server
- create an empty database too
- nginx  
- php-fpm
- redis-server (optional)

In case you want to use ssl:  
- ssl (or snakeoil certs)  
- optional but recommended, create a stronger __dh key__

At first I install the required components:  
`aptitude install software-properties-common php7.0 php7.0-common php7.0-mbstring php7.0-xmlwriter php7.0-mysql php7.0-intl php7.0-mcrypt php7.0-ldap php7.0-imap php7.0-cli php7.0-gd php7.0-json php7.0-curl php7.0-xmlrpc php7.0-zip libsm6 libsmbclient`

If you decide to use redis then it the php plugin is needed:  
`aptitude install php7.0-redis`


### prepare and install

You can download the latest version via this url:  
e.g. `wget  https://download.owncloud.org/community/owncloud-9.1.5.tar.bz2`


Unzip the file and copy it to the target directory.
The path where I copy it to is e.g.: `/var/www/html/owncloud`


You can use a service user for a PHP-FPM pool and the owner of the files in the web root directory. It requires little bit more carefulness but increases the security as well a little. This step is recommended.

Create the user e.g. with these commands, it will not create a home directory and disallow the login:  
`useradd --no-create-home owncloud`  
`usermod --lock owncloud`


Now set the owner and permissions, after the installation it will be hardened with a script further below but this is fine for the installation.:
```
chown -R owncloud:www-data /var/www/html/owncloud/
find /var/www/html/owncloud/ -type d -exec chmod 750 {} \;
find /var/www/html/owncloud/ -type f -exec chmod 640 {} \;
```


For the php-fpm pool here is my template which I use, save it to e.g. `/etc/php/7.0/fpm/pool.d/owncloud.conf`:  

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

;; owncloud
[webmail]
env[HOSTNAME] = MyHostName
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/owncloud.sock
listen.owner = owncloud
listen.group = www-data
listen.mode = 0660
user = owncloud
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/owncloud-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

;; middle sized owncloud / nextcloud pool
listen.backlog = 1024
pm = dynamic
pm.max_children = 30
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 6
pm.max_requests = 500
pm.process_idle_timeout = 150s
request_terminate_timeout = 150
php_value[max_input_time] = 150
php_value[max_execution_time] = 150
php_value[memory_limit] = 1512M
php_value[post_max_size] = 1512M
php_value[upload_max_filesize] = 1512M
```

The next step is to create the nginx vhost configuration, adjust it to your needs (ssl keys, hostname, paths..):

```
upstream owncloud {

	server unix:///run/php/owncloud.sock;
}

server {

	listen 80;
	server_name mydomain.com;
	location / {

		return 301 https://\$server_name\$request_uri;
	}
}

server {

	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name mydomain.com;
	root /var/www/html/owncloud;
	access_log /var/log/nginx/owncloud-access.log;
	error_log /var/log/nginx/owncloud-error.log warn;

	ssl on;
	ssl_certificate /etc/ssl/my_ssl.crt;
	ssl_certificate_key /etc/ssl/my_ssl.key;
	ssl_dhparam /etc/ssl/my_dhparams.pem;

	index index.php;

	include global/secure_ssl.conf;
	include global/restrictions.conf;


	# Additional rules go here.
	# if (\$allow_visit = no) { return 403 };
	add_header X-Content-Type-Options nosniff;
	add_header X-Frame-Options "SAMEORIGIN";
	add_header X-XSS-Protection "1; mode=block";
	add_header X-Robots-Tag none;
	add_header X-Download-Options noopen;
	add_header X-Permitted-Cross-Domain-Policies none;

	location = /robots.txt {

		allow all;
		log_not_found off;
		access_log off;
	}

	# The following 2 rules are only needed for the user_webfinger app.
	# Uncomment it if you're planning to use this app.
	#rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
	#rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json last;

	location = /.well-known/carddav {

		return 301 \$scheme://\$host/remote.php/dav;
	}
	location = /.well-known/caldav {

		return 301 \$scheme://\$host/remote.php/dav;
	}

	# set max upload size
	client_max_body_size 4096M;
	fastcgi_buffers 64 4K;

	# Disable gzip to avoid the removal of the ETag header
	gzip off;

	# Uncomment if your server is build with the ngx_pagespeed module
	# This module is currently not supported.
	# pagespeed off;
	error_page 403 /core/templates/403.php;
	error_page 404 /core/templates/404.php;

	location / {

		rewrite ^ /index.php\$uri;
	}

	location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {

		deny all;
	}
	location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {

		deny all;
	}

	location ~ ^/(?:index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|ocs-provider/.+|core/templates/40[34])\.php(?:$|/) {

		fastcgi_split_path_info ^(.+\.php)(/.*)$;
		include fastcgi_params;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		fastcgi_param PATH_INFO \$fastcgi_path_info;
		fastcgi_param HTTPS on;
		#Avoid sending the security headers twice
		fastcgi_param modHeadersAvailable true;
		fastcgi_param front_controller_active true;
		fastcgi_pass owncloud;
		fastcgi_intercept_errors on;
		fastcgi_request_buffering off;
	}

	location ~ ^/(?:updater|ocs-provider)(?:$|/) {

		try_files \$uri/ =404;
		index index.php;
	}

	# Adding the cache control header for js and css files
	# Make sure it is BELOW the PHP block
	location ~* \.(?:css|js)$ {

		try_files \$uri /index.php\$uri\$is_args\$args;
		add_header Cache-Control "public, max-age=7200";
		# Add headers to serve security related headers (It is intended to have those duplicated to the ones above)
		add_header X-Content-Type-Options nosniff;
		add_header X-Frame-Options "SAMEORIGIN";
		add_header X-XSS-Protection "1; mode=block";
		add_header X-Robots-Tag none;
		add_header X-Download-Options noopen;
		add_header X-Permitted-Cross-Domain-Policies none;
		# Optional: Don't log access to assets
		access_log off;
	}

	location ~* \.(?:svg|gif|png|html|ttf|woff|ico|jpg|jpeg)$ {

		try_files \$uri /index.php\$uri\$is_args\$args;
		# Optional: Don't log access to other assets
		access_log off;
	}
}
```


Now you can start the installation of owncloud.
There are two ways:
1. Navigate to the website url and follow the setup wizard.
2. Use the command line interface (cli) with this command:  
`su owncloud -s /bin/bash -c "php /var/www/html/owncloud/occ maintenance:install -vvv --database mysql --database-name MYSQL_DB_NAME --database-table-prefix TABLE_PREFIX --database-user MYSQL_DB_USER --database-pass MYSQL_DB_PASSWORD --admin-user admin --admin-pass 123456"`

To break it down, a little here are the things it does:  
- su owncloud --> this changes the user which will execute the whole script.
-  -s /bin/bash -c  --> this tells that the user should use the shell and run a command
- php /path/to/owncloud/occ maintenance:install -vvv --> this tells php to run occ with the appended parameters

We pass then a couple of parameter to the occ installation. The database type, name, a table prefix, database user, database password, an admin user name, an admin password.  
__This procedure assumes that you've created an empty mysql database before.__


### configuration
Now let's configure ownCloud.  
Edit the file `/var/www/html/owncloud/config/config.php`  
Set correct values for these things:  
- trusted_domains
- overwrite.cli.url
- datadirectory (you can move it somewhere else if you wish)
- set the timezone


In owncloud you can change the background jobs method. I choose cron as it is said to be the most reliable one.

On the system side you have to configure a cron job that is run e.g. every 15 minutes. For the parameter -u I use the user under which the fpm pool is running and which has access to the files.  
`(crontab -l -u "owncloud"  2>/dev/null; echo "*/15 * * * * php /var/www/html/owncloud/cron.php") | crontab -u "owncloud" -`


#### configuration for using redis cache
In case you have decided for redis ownclouds's config.php has to be extended with a few configurations:  
```
'filelocking.enabled' => true,
'memcache.local' => '\OC\Memcache\Redis',
'memcache.locking' => '\OC\Memcache\Redis',
'redis' => array(
   'host' => '/run/redis/redis.sock',
   'port' => 0,
   'timeout' => 0.0,
   'password' => 'requirepass password',
    ),
```

This enables redis to be responsible for file caching and locking.  
Adjust the host (unix socket) and the password, which is the requirepass password from the redis.conf.

That owncloud can communicate with the redis unix socket it has to have the permissions. Set the permissions by adding the owncloud service user to the redis group.

`usermod --append --groups redis owncloud`

After the setup of redis php7.0-fpm has to be restarted.  
`systemctl restart php7.0-fpm`

#### secure file permissions

This script sets secure permissions, it origins from the official owncloud manual [https://doc.owncloud.org](https://doc.owncloud.org/server/9.0/admin_manual/installation/installation_wizard.html). just substitute the ocpath and the htuser, htgroup with the correct details.  
```bash
#!/bin/bash
ocpath='/var/www/html/owncloud'
htuser='www-data'
htgroup='www-data'
rootuser='root'

printf "Creating possible missing Directories\n"
mkdir -p $ocpath/data
mkdir -p $ocpath/assets
mkdir -p $ocpath/updater

printf "chmod Files and Directories\n"
find ${ocpath}/ -type f -print0 | xargs -0 chmod 0640
find ${ocpath}/ -type d -print0 | xargs -0 chmod 0750

printf "chown Directories\n"
chown -R ${rootuser}:${htgroup} ${ocpath}/
chown -R ${htuser}:${htgroup} ${ocpath}/apps/
chown -R ${htuser}:${htgroup} ${ocpath}/assets/
chown -R ${htuser}:${htgroup} ${ocpath}/config/
chown -R ${htuser}:${htgroup} ${ocpath}/data/
chown -R ${htuser}:${htgroup} ${ocpath}/themes/
chown -R ${htuser}:${htgroup} ${ocpath}/updater/

chmod +x ${ocpath}/occ

printf "chmod/chown .htaccess\n"
if [ -f ${ocpath}/.htaccess ]
 then
  chmod 0644 ${ocpath}/.htaccess
  chown ${rootuser}:${htgroup} ${ocpath}/.htaccess
fi
if [ -f ${ocpath}/data/.htaccess ]
 then
  chmod 0644 ${ocpath}/data/.htaccess
  chown ${rootuser}:${htgroup} ${ocpath}/data/.htaccess
fi
```
