#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

echo "Running $0"

source /vagrant/environment.sh

# install debconf-set-selections for unattended installation of mysql,
# to define the password for the installation process
$INSTALLER install -y debconf-set-selections
echo mysql-server mysql-server/root_password password "$MYSQL_ROOT_PASS" | debconf-set-selections
echo mysql-server mysql-server/root_password_again password "$MYSQL_ROOT_PASS" | debconf-set-selections

# install mysql-server
$INSTALLER install -y mysql-server

# Secure mysql with mysql_secure_installation via expect automated execution
$INSTALLER install -y expect
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root:\"
send \"$MYSQL_ROOT_PASS\r\"
expect \"Would you like to setup VALIDATE PASSWORD plugin?\"
send \"n\r\"
expect \"Change the password for root ?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
export SECURE_MYSQL
echo "$SECURE_MYSQL"
unset SECURE_MYSQL

# Remove expect and config files
$INSTALLER -y purge expect

#create empty .my.cnf file
touch /etc/mysql/.my.cnf
chown root:root /etc/mysql/.my.cnf
chmod 400 /etc/mysql/.my.cnf

#create custom config for utf8mb4 settings
cat << EOF > /etc/mysql/conf.d/90-custom-settings.cnf
[client]
default-character-set=utf8mb4

[mysqld]
collation-server = utf8mb4_unicode_ci
init-connect='SET NAMES utf8mb4'
character-set-server = utf8mb4
innodb_large_prefix=on
innodb_file_format=barracuda
innodb_file_per_table=true

[mysql]
default-character-set=utf8mb4
EOF

sed -i "s/^bind-address.*/bind-address            = $MYSQL_BIND_NAME_IP/" /etc/mysql/my.cnf

systemctl restart mysql
