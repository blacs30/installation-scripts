# Install and secure mysql-server

Information for ansible automated secure installation are found here: [github.com/PCextreme](https://github.com/PCextreme/ansible-role-mariadb/blob/master/tasks/mysql_secure_installation.yml)

Here can be found some additional security information:  
[hexatier.com](http://www.hexatier.com/mysql-database-security-best-practices-2/)

Have a look for performance and memory settings here: [www.percona.com](https://www.percona.com/blog/2014/01/28/10-mysql-performance-tuning-settings-after-installation/)

The following steps will explain a simple mysql-server installation. Some basic steps how to secure the installation follow after that.

Install mysql-server, the installer will ask for the root password:  
`aptitude install -y mysql-server`

To secure the mysql installation simply run the following command:  
`mysql_secure_installation`

This will ask you a couple of questions:  
1. Enter the current mysql root password to be able to make the changes
2. Do you want to change the root password? --> Not necessarily needed
3. Remove anonymous users? --> Yes
4. Disallow root login remotely? --> Yes
5. Remove test database and access to it? --> Yes
6. Reload privilege tables now? --> Yes

Check the file `/etc/mysql/my.cnf` and check/set the following settings:  
1. bind-address = 127.0.0.1 if the database is used only locally

Create an empty file in `/etc/mysql/.my.cnf`, optionally add some client side mysql properties.  
Set the owner and group to `root`  and the permissions to user read only 400:  
```shell
touch /etc/mysql/.my.cnf
chown root:root /etc/mysql/.my.cnf
chmod 400 /etc/mysql/.my.cnf
```
