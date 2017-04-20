#!/usr/bin/env bash

source /vagrant/environment.sh

$INSTALLER update
$INSTALLER install -y php7.0-fpm
mv /etc/php/7.0/fpm/pool.d/www.conf /etc/php/7.0/fpm/pool.d/www.conf.backup
sed -i "s,.*date.timezone =.*,date.timezone = $PHP_TIMEZONE," "$PHP_CONFIG_FILE"
sed -i 's/.*opcache.enable =.*/opcache.enable = 1/' "$PHP_CONFIG_FILE"
sed -i 's/.*events.mechanism =.*/events.mechanism = epoll/' "$PHPFPM_CONFIG_FILE"
sed -i 's/.*emergency_restart_threshold =.*/emergency_restart_threshold = 10/' "$PHPFPM_CONFIG_FILE"
sed -i 's/.*emergency_restart_interval =.*/emergency_restart_interval = 1m/' "$PHPFPM_CONFIG_FILE"
sed -i 's/.*process_control_timeout =.*/process_control_timeout = 10s/' "$PHPFPM_CONFIG_FILE"
sed -i 's,.*error_log =.*,error_log = /var/log/php/php7.0-fpm.log,' "$PHPFPM_CONFIG_FILE"
