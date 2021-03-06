#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

echo "Running $0"

source /vagrant/environment.sh

$INSTALLER install -y redis-server

# configuration
sed -i 's/^port .*/port 0/' $REDIS_CONF
sed -i "/requirepass .*/c\requirepass $REDIS_PASS" $REDIS_CONF

if ! grep -Fq "^unixsocket $REDIS_SOCKET" $REDIS_CONF; then
  sed -i "s|# unixsocket .*|unixsocket $REDIS_SOCKET|" $REDIS_CONF
fi

if ! grep -Fq "^unixsocketperm 770" $REDIS_CONF; then
  sed -i "s|# unixsocketperm .*|unixsocketperm 770|" $REDIS_CONF
fi

if [ ! -d /run/redis ]; then
  mkdir /run/redis
  echo "Create run/redis dir"
fi

chown redis:redis /run/redis
chmod 755 /run/redis

usermod --append --groups redis www-data

systemctl restart redis-server
