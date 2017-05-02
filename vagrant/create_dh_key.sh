#!/usr/bin/env bash

source /vagrant/environment.sh

openssl dhparam -out ${DH_PARAMS_FILE} 512 #TODO(Change back to 2048)
chmod 400 ${DH_PARAMS_FILE}
