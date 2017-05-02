# Install phpmyadmin
Sometimes a gui is a nice to have tool when working with databases. The web ui for mysql is the known phpmyadmin.  
In this write-up I cover all basic steps required to have a functional setup.

### Install prerequisites

Following components are required. Check other manuals on how to install them.
- mysql-server
- nginx  
- php-fpm

In case you want to use ssl:  
- ssl (or snakeoil certs)  
- optional but recommended to create a new stronger __dh key__

At first I install the required php components:  
`aptitude install php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-mcrypt php7.0-gd php7.0-json php7.0-mysql php7.0-opcache php7.0-readline php7.0-mbstring`

You can download the latest (at time of writing) version via this url:  
e.g. `wget  https://files.phpmyadmin.net/phpMyAdmin/4.7.0/phpMyAdmin-4.7.0-all-languages.zip`

Unzip the file and copy it to the target directory.
The path where I copy it to is e.g.: `/var/www/html/phpmyadmin`

Create the initial configuration file by copying the sample:

`cp /var/www/html/phpmyadmin/config.sample.inc.php /var/www/html/phpmyadmin/config.inc.php`

It is recommended to set a blowfish secret in the config file. This way I generate a password `< /dev/urandom tr -dc "a-zA-Z0-9@#*=" | fold -w 32 | head -n 1)`

You can use a service user for a PHP-FPM pool and the owner of the files in the web root directory. It requires little bit more carefulness but increases the security as well as little.

Create the user e.g. with these commands:  
`useradd --no-create-home phpmyadmin`
`usermod --lock phpmyadmin`

Now set the owner and permissions:
```
chown -R phpmyadmin:www-data /var/www/html/phpmyadmin/
find /var/www/html/phpmyadmin/ -type d -exec chmod 750 {} \;
find /var/www/html/phpmyadmin/ -type f -exec chmod 640 {} \;
```

For the php-fpm pool here is my template which I use, save it to e.g. `/etc/php/7.0/fpm/pool.d/phpmyadmin.conf`:  

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

;; phpmyadmin
[phpmyadmin]
env[HOSTNAME] = MyHostName
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = /run/php/phpmyadmin.sock
listen.owner = phpmyadmin
listen.group = www-data
listen.mode = 0660
user = phpmyadmin
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/phpmyadmin-slowlog.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7

listen.backlog = 64
pm = ondemand
pm.max_children = 5
pm.max_requests = 200
pm.process_idle_timeout = 10s
```

As an optional step I have basic authentication activated for the phpmyadmin page, so that an additional password has to be entered.
This way it can be generated:  
`htpasswd -b -c /etc/nginx/.phpmyadmin phpmyadmin myPassword123`

As last step create the nginx vhost configuration, adjust it to your needs (ssl keys, hostname, paths..):

```
upstream phpmyadmin {

	server unix:///run/php/phpmyadmin.sock;
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
	root /var/www/html/phpmyadmin;
	access_log /var/log/nginx/phpmyadmin-access.log;
	error_log /var/log/nginx/phpmyadmin-error.log warn;

	ssl on;
	ssl_certificate /etc/ssl/my_ssl.crt;
	ssl_certificate_key /etc/ssl/my_ssl.key;
	ssl_dhparam /etc/ssl/my_dhparams.pem;

	index index.php;

	include global/secure_ssl.conf;
	include global/restrictions.conf;
	client_header_timeout 3m;

	# Configure GEOIP access before enabling this setting
	# if (\$allow_visit = no) { return 403 };

	# Make sure files with the following extensions do not get loaded by nginx because nginx would display the source code, and these files can contain PASSWORDS!
	location ~* \.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|tpl(\.php)?|xtmpl)$|^(\..*|Entries.*|Repository|Root|Tag|Template)$|\.php_ {

		deny all;
	}

	location ~* \.(jpg|jpeg|png|gif|css|js|ico)$ {

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

		auth_basic "Restricted";
		auth_basic_user_file /etc/nginx/.phpmyadmin;
		index index.php index.html index.htm;

		location ~ ^/phpmyadmin/(.+\.php)\$ {

			try_files \$uri =404;
			fastcgi_param HTTPS on;
			fastcgi_pass phpmyadmin;
			fastcgi_index index.php;
			fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
			include fastcgi_params;
			charset utf8;
			client_max_body_size 64m; #change this if ur export is bigger than 64mb.
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

Activate the vhost configuration and restart php-fpm and nginx:


`ln -s /etc/nginx/sites-available/phpmyadmin.conf /etc/nginx/sites-enabled/phpmyadmin`

```
systemctl restart php7.0-fpm
systemctl restart nginx
```
