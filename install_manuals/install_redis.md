# Install redis-server
Redis is a widely known caching server which can be also used for owncloud, nextcloud and wordpress and a lot more.
These 3 cases are described in these manuals.
This is a basic setup as unix socket and a password.

### Start
Install redis-server:  
`aptitude install redis-server`  

After the installation edit the configuration file. It is typically located here: `/etc/redis/redis.conf`

Set the password which is required of client to a password of your choice, better generate one.
`requirepass mYMasterPassword_`

If you want to use redis with unix socket set this settings, create the folder `/run/redis` in case it does not exist yet. When using a unixsocket set the port to 0:  
`port 0`  
`unixsocket /run/redis/redis.sock`

Then set the permission of the socket to __770__, that is required for owncloud / nextcloud (maybe wordpress too, I don't know).  
`unixsocketperm 770`


If the directory `/etc/tmpfiles.d` exists execute the command below to persist the directory or 10 days, which contains the socket already:  
`echo 'd  /run/redis  0755  redis  redis  10d  -' >> /etc/tmpfiles.d/redis.conf`


Redis is the group all users who should be able to use redis need to be added to. To connect with nginx (on debian www-data) we need to add www-data to the redis group.
`usermod --append --groups redis www-data`
