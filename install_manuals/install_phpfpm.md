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
