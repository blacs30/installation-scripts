# Install phpmyadmin
Sometimes a gui is a nice to have tool when working with databases. The web ui for mysql is the known phpmyadmin.  
In this write-up I cover all basic steps required to have a functional setup.

### Install prerequisites

install_mysql  
install_nginx  
install_php_fpm  
create_snakeoil_certs  
create_dh_param  


SOFTWARE_URL=https://files.phpmyadmin.net/phpMyAdmin/4.6.4/phpMyAdmin-4.6.4-all-languages.zip
SOFTWARE_ZIP=$(basename $SOFTWARE_URL)
SOFTWARE_DIR=$(printf '%s' "$SOFTWARE_ZIP" | sed -e 's/.zip//')

At first I install the required php components:  
`aptitude install php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-mcrypt php7.0-gd php7.0-json php7.0-mysql php7.0-opcache php7.0-readline php7.0-mbstring`


You can use a service user for a PHP-FPM pool and the owner of the files in the web root directory. It requires little bit more carefulness but increases the security as well as little.


`useradd --no-create-home phpmyadmin`
`usermod --lock phpmyadmin`
