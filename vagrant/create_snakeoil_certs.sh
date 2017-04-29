#!/usr/bin/env bash

source /vagrant/environment.sh

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096  \
-subj "/C=$COUNTRYNAME/ST=$PROVINCENAME/L=$KEY_LOCATION/O=$KEY_ORGANIZATION/OU=$KEY_OUN/CN=$KEY_COMMON_NAME/emailAddress=$KEY_MAIL" \
-keyout "$TLS_KEY_FILE" \
-out "$TLS_CERT_FILE"

chmod 600 "$TLS_KEY_FILE"
