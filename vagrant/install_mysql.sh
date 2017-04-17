#!/usr/bin/env bash

# Define the mysql root password as this is an unattended installation
MYSQL_ROOT_PASS=123456
INSTALLER=aptitude

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
unset MYSQL_ROOT_PASS

# Remove expect and config files
$INSTALLER -y purge expect

#create empty .my.cnf file
touch /etc/mysql/.my.cnf
chown root:root /etc/mysql/.my.cnf
chmod 400 /etc/mysql/.my.cnf
