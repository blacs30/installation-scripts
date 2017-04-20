#!/usr/bin/env bash

source /vagrant/environment.sh

openssl dhparam -out /etc/ssl/"${KEY_COMMON_NAME}"_dhparams.pem 2048
chmod 400 /etc/ssl/"${KEY_COMMON_NAME}"_dhparams.pem
