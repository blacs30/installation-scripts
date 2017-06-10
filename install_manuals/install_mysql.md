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

### utf8mb4 support
The character set __utf8__ alone is not enough in mysql to show all unicode characters. The required character set is __utf8mb4__.
To use that character set create a custom configuration file with the following content:

```bash
ladmin@localhost $ cat /etc/mysql/conf.d/90-custom-settings.cnf
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
```


### Create an empty database
When I want to setup a database automatically I first check if my mysql root password is correct. This line is enough:

```bash
if echo exit | mysql -uroot -p"MYSQL_ROOT_PASS" -h"MYSQL_HOST" >/dev/null 2>&1; then echo "successfully connected"; fi
```

After that I check if the database to be created already exists with this name. If the result is __NOT__ 0 then the database exists already.

```bash
echo "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'MYSQL_DB_NAME' ;" | \
mysql -uroot -p"MYSQL_ROOT_PASS" -h"MYSQL_HOST" | grep -c SCHEMA_NAME
```

Now let's create the database:  
1. I create a temporaray file, you could also put the commands directly into mysql:  
```
echo "
CREATE DATABASE IF NOT EXISTS $MYSQL_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;;
GRANT ALL PRIVILEGES ON MYSQL_DB_NAME.* TO 'MYSQL_DB_USER'@'127.0.0.1' IDENTIFIED BY 'MYSQL_DB_PASSWORD';
quit" > /tmp/createdb.sql
```

2. Run the sql file as root in mysql:  
`mysql -uroot -p"MYSQL_ROOT_PASS" -h"MYSQL_HOST" < /tmp/createdb.sql`
