# Install PHP-FPM
Version: 7.0

In connection with nginx I use php-fpm to process php pages.

This is the setup I use. The pools look different depending on the expected number of visitors and required size of the page.

### The setup
Install php7.0-fpm:  
`aptitude install php7.0-fpm`  

I disable the default pool:  
`mv /etc/php/7.0/fpm/pool.d/www.conf /etc/php/7.0/fpm/pool.d/www.conf.backup`  

Set the correct timezone in the file `/etc/php/7.0/fpm/php.ini`:  
- date.timezone = "Europe/Berlin"

Enable the opcache as it increases the performance even more.  
Read here for more information and further required settings: [1and1.com](https://community.1and1.com/php-7/) and here [scalingphpbook.com](https://www.scalingphpbook.com/blog/2014/02/14/best-zend-opcache-settings.html)  
In the file `/etc/php/7.0/fpm/php.ini` set (and adjust to your needs):  
- opcache.enable = 1;
- opcache.revalidate_freq=0
- opcache.validate_timestamps=0 (comment this out in your dev environment)
- opcache.max_accelerated_files=7963
- opcache.memory_consumption=192
- opcache.interned_strings_buffer=16
- opcache.fast_shutdown=1

Set the event mechanism for FPM in `/etc/php/7.0/fpm/php-fpm.conf`:  
- events.mechanism = epoll
- emergency_restart_threshold = 10
- emergency_restart_interval = 1m
- process_control_timeout = 10s
- error_log = /var/log/php/php7.0-fpm.log

Here are some security background information regarding
the setting [cgi.fix_pathinfo = 0](https://serverfault.com/questions/627903/is-the-php-option-cgi-fix-pathinfo-really-dangerous-with-nginx-php-fpm) which is not anymore required but therefore the following settings should be check and set for the pools to make sure that only .php files are executed by FPM.  
The pool configuration should include this setting:  
`security.limit_extensions = .php .php3 .php4 .php5 .php7`


## Pool configurations
I have saved the following templates:  
- big_oc (Big size pool for e.g. Owncloud/Nextcloud)
- middle_oc (Middle sized pool for e.g. Owncloud/Nextcloud )
- big_wp (Big size pool for e.g. Wordpress )
- middle (Middle sized pool for e.g. Wordpress and other sites)
- small (Small sized, on demand, pool, for e.g. administrative pages or lower traffic pages )

This one is the global section which goes into every of my pools, make sure to adjust it to your needs:  
```
;; MyApplicationName
[MyPoolName]
env[HOSTNAME] = MyHostname
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] =/tmp
listen = unix:///run/php/MyPoolName.sock
listen.owner = pool_owner
listen.group = www-data
listen.mode = 0660
user = pool_owner
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/slowlog-MyPoolName.log
catch_workers_output = yes
security.limit_extensions = .php .php3 .php4 .php5 .php7
```

Explanations  
> The number of PHP-FPM children that should be spawned automatically  
> pm.start_servers =  
> The maximum number of children allowed (connection limit)  
> pm.max_children =  
> The minimum number of spare idle PHP-FPM servers to have available  
> pm.min_spare_servers =  
> The maximum number of spare idle PHP-FPM servers to have available  
> pm.max_spare_servers =  
> Maximum number of requests each child should handle before re-spawning  
> pm.max_requests =  
> Maximum amount of time to process a request (similar to max_execution_time in php.ini  
> request_terminate_timeout =  


This is a big sized Owncloud/Nextcloud pool:   
```
listen.backlog = 1024
pm = dynamic
pm.max_children = 40
pm.start_servers = 10
pm.min_spare_servers = 4
pm.max_spare_servers = 10
pm.max_requests = 1000
pm.process_idle_timeout = 300s
request_terminate_timeout = 300
php_value[max_execution_time] = 300
php_value[max_input_time] = 300
php_value[memory_limit] = 4096M
php_value[post_max_size] = 4096M
php_value[upload_max_filesize] = 4096M
```

This is a middle sized Owncloud/Nextcloud pool:   
```   
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

This is a big sized WordPress pool:   
```
listen.backlog = 1024
pm = dynamic
pm.max_children = 40
pm.start_servers = 10
pm.min_spare_servers = 4
pm.max_spare_servers = 10
pm.max_requests = 1000
pm.process_idle_timeout = 300s
request_terminate_timeout = 300
php_value[max_input_time] = 300
php_value[max_execution_time] = 300
php_value[memory_limit] = 75M
php_value[post_max_size] = 50M
php_value[upload_max_filesize] = 50M
```

This is a middle sized pool:  
```  
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
This is a small pool size which creates process managers on demand:  

```
listen.backlog = 64
pm = ondemand
pm.max_children = 5
pm.max_requests = 200
pm.process_idle_timeout = 10s
```
