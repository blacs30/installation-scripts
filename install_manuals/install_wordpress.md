# Install Wordpress
This is a manual for a wordpress installation. I know there are many out there...
It will install some plugins and prepares for redis caching and 2FA for required accounts (e.g. admins)

### Install prerequisites

Following components are required. Check other manuals on how to install them.
- mysql-server
- create an empty database too
- nginx  
- php-fpm
- redis-server (optional)

In case you want to use ssl:  
- ssl (or snakeoil certs)  
- optional but recommended to create a new stronger __dh key__

At first I install the required php components:  
`aptitude install php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-gd php7.0-json php7.0-mysql php7.0-opcache php7.0-readline`

If you decided to use redis then it the php plugin is needed:  
`aptitude install php7.0-redis`


You can download the latest version via this url:  
e.g. `wget  https://wordpress.org/latest.zip`

Unzip the file and copy it to the target directory.
The path where I copy it to is e.g.: `/var/www/html/wordpress`


You can use a service user for a PHP-FPM pool and the owner of the files in the web root directory. It requires little bit more carefulness but increases the security as well as little.

Create the user e.g. with these commands, it will not create a home directory and disallow the login:  
`useradd --no-create-home wordpress`  
`usermod --lock wordpress`


For the php-fpm pool here is my template which I use, save it to e.g. `/etc/php/7.0/fpm/pool.d/wordpress.conf`:  

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

;; wordpress
[webmail]
env[HOSTNAME] = MyHostName
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/wordpress.sock
listen.owner = wordpress
listen.group = www-data
listen.mode = 0660
user = wordpress
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/wordpress-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

;; middle sized pool
listen.backlog = 512
pm = dynamic
pm.max_children = 30
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 6
pm.max_requests = 500
pm.process_idle_timeout = 60s
php_value[max_input_time] = 120
php_value[max_execution_time] = 120
php_value[memory_limit] = 50M
php_value[php_post_max_size] = 25M
php_value[upload_max_filesize] = 25M
```

The next step is to create the nginx vhost configuration, adjust it to your needs (ssl keys, hostname, paths..):

```
upstream wordpress {

	server unix:///run/php/wordpress.sock;
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
	root /var/www/html/wordpress;
	access_log /var/log/nginx/wordpress-access.log;
	error_log /var/log/nginx/wordpress-error.log warn;

	ssl on;
	ssl_certificate /etc/ssl/my_ssl.crt;
	ssl_certificate_key /etc/ssl/my_ssl.key;
	ssl_dhparam /etc/ssl/my_dhparams.pem;


	include global/secure_ssl.conf;
	include global/restrictions.conf;
	include global/wordpress.conf;

	client_max_body_size 40M;
	index index.php;

	location = /xmlrpc.php {

		deny all;
		access_log off;
		log_not_found off;
	}

	# Pass all .php files onto a php-fpm/php-fcgi server.
	location ~ [^/]\.php(/|$) {

		fastcgi_split_path_info ^(.+?\.php)(/.*)$;
		try_files \$uri \$uri/ /index.php?args;
		include fastcgi.conf;
		fastcgi_index index.php;
		# fastcgi_intercept_errors on;
		fastcgi_pass wordpress;
	}


	# Secure wp-login.php requests
	location = /wp-login.php {

		# if (\$allow_visit = no) { return 403 };

		fastcgi_split_path_info ^(.+?\.php)(/.*)$;
		try_files \$uri \$uri/ /index.php?args;
		include fastcgi.conf;
		fastcgi_index index.php;
		# fastcgi_intercept_errors on;
		fastcgi_pass wordpress;
	}

	# Secure /wp-admin requests
	location ~ ^wp-admin {

		# if (\$allow_visit = no) { return 403 };
	}

	# Secure /wp-admin requests (allow admin-ajax.php)
	location ~* ^/wp-admin/admin-ajax.php$ {

		fastcgi_split_path_info ^(.+?\.php)(/.*)$;
		try_files \$uri \$uri/ /index.php?args;
		include fastcgi.conf;
		fastcgi_index index.php;
		# fastcgi_intercept_errors on;
		fastcgi_pass wordpress;
	}

	# Secure /wp-admin requests (.php files)
	location ~* ^/wp-admin/.*\.php {

		# if (\$allow_visit = no) { return 403 };

		fastcgi_split_path_info ^(.+?\.php)(/.*)$;
		try_files \$uri \$uri/ /index.php?args;
		include fastcgi.conf;
		fastcgi_index index.php;
		# fastcgi_intercept_errors on;
		fastcgi_pass wordpress;
	}
}
```

Activate the vhost configuration and restart php-fpm and nginx:


`ln -s /etc/nginx/sites-available/wordpress.conf /etc/nginx/sites-enabled/wordpress`

```
systemctl restart php7.0-fpm
systemctl restart nginx
```

Configure the database connection.
I normally edit the wp-config.php directly but this step can be done in the browser as well.
Edit `/var/www/html/wordpress/wp-config.php` and set:  
- table_prefix (optional)
- DB_HOST
- DB_USER
- DB_NAME
- DB_PASSWORD

I disable the web theme per default with these 2 lines in the same file:  
```
/** Disallow theme editor for WordPress. */
define( 'DISALLOW_FILE_EDIT', true );
```

I don't allow error reporting for php
```
/** Disallow error reporting for php. */
error_reporting(0);
@ini_set(‘display_errors’, 0);
```

Insert salts into the config, this script is handy for that (thanks to [stackoverflow.com](http://stackoverflow.com/questions/21417651/perl-salt-generation-on-wp-config-sample-php)):
```bash
cd /var/www/html/wordpress/
perl -i -ne '
    BEGIN {
        $keysalts = qx(curl -sS https://api.wordpress.org/secret-key/1.1/salt)
    }
    if ( $flipflop = ( m/AUTH_KEY/ .. m/NONCE_SALT/ ) ) {
        if ( $flipflop =~ /E0$/ ) {
            printf qq|%s|, $keysalts;
        }
        next;
    }
    printf qq|%s|, $_;
' wp-config.php
```


Download plugins
I know which plugins I need and have a list. I can simply download them after the setup of wordpress.
This is just the example of the redis plugin.
```bash
wget https://downloads.wordpress.org/plugin/redis-cache.1.3.5.zip
unzip -q redis-cache.1.3.5.zip -d /var/www/html/wordpress/wp-content/plugins
if [ -f redis-cache.1.3.5.zip ]; then
  rm -f redis-cache.1.3.5.zip
fi
```


For the case that you use redis cache too the wp-config.php has to be extended by the following config.
It will tell the e.g. redis socket and password so that wordpress can communicate with the redis-cache.
```
/** Redis config */
define( 'WP_REDIS_CLIENT', 'pecl');
define( 'WP_REDIS_SCHEME', 'unix');
define( 'WP_REDIS_PATH', '/var/run/redis/redis.sock');
define( 'WP_REDIS_DATABASE', '0');
define( 'WP_REDIS_PASSWORD', 'requirepass password');
define( 'WP_REDIS_KEY_SALT', 'wordpress_');
```

As redis is hopefully running as a different user (if on the same machine) the service user for the php-fpm pool has to be added to the redis group to have access to the socket.  
`usermod --append --groups redis wordpress`


Now set the owner and permissions and create the uploads folder in case it does not exist yet:
```bash
if [ ! -d /var/www/html/wordpress/wp-content/uploads ]; then
  mkdir -p /var/www/html/wordpress/wp-content/uploads
fi

chown -R wordpress:www-data /var/www/html/wordpress/
find /var/www/html/wordpress/ -type d -exec chmod 750 {} \;
find /var/www/html/wordpress/ -type f -exec chmod 640 {} \;
chmod 600 /var/www/html/wordpress/wp-config.php
```

Now you can open your website in the browser and you will be directed to the wordpress installation page.
