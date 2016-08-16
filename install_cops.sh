#!/bin/bash
# install cops - with nginx
# http://blog.slucas.fr/en/oss/calibre-opds-php-server

cd /tmp
wget https://github.com/seblucas/cops/releases/download/1.0.0/cops-1.0.0.zip
unzip cops-1.0.0.zip -d /tmp/cops
mkdir /var/www/ebooks.lisowski-development.com/public_html
mv /tmp/cops
cp /var/www/ebooks.lisowski-development.com/public_html/config_local.php.example /var/www/ebooks.lisowski-development.com/public_html/config_local.php
sed -i "s,.*config['calibre_directory'] =.*;,$config['calibre_directory'] = '/var/www/cloud.lisowski-development.com/public_html/data/claas/files/Calibre_Library/';," /var/www/ebooks.lisowski-development.com/public_html/config_local.php

chown oclisdev:www-data -R /var/www/ebooks.lisowski-development.com/
