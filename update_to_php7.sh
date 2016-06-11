#!/bin/bash
# update from php5.6 to php7.0
cd /tmp

# add repository to apt sources
sudo echo "deb http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list
sudo echo "deb-src http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list

# add key from repository to apt-get
wget https://www.dotdeb.org/dotdeb.gpg
sudo apt-key add dotdeb.gpg
sudo apt-get update

# install php7.0 and components
sudo apt-get install php7.0 \
libapache2-mod-php7.0 \
php7.0-common \
php7.0-cli \
php-pear \
php7.0-curl \
php7.0-gd \
php7.0-intl \
php7.0-json \
php7.0-readline \
php7.0-mcrypt \
php7.0-mysql \
php7.0-sqlite3 \
php7.0-imagick \
php7.0-redis
# apt-get install -y  php7.0-mbstring

# disable php5 and enable php7.0 for apache and restart the service
sudo a2dismod php5
sudo a2enmod php7.0
sudo service apache2 restart

# set php7.0 as default php
sudo ln -sfn /usr/bin/php7.0 /etc/alternatives/php

# show php version
php -v

# OPTIONAL remove php5 and clean configs
# apt-get purge php5-common
# apt-get --purge autoremove
