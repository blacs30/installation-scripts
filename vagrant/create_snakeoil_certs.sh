#!/usr/bin/env bash
COUNTRYNAME=DE
PROVINCENAME=Hamburg
KEY_LOCATION=Hamburg
KEY_ORGANIZATION=Organisation
KEY_OUN=IT
KEY_COMMON_NAME=testorg.com
KEY_MAIL=webmaster@testorg.com

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096  \
-subj "/C=$COUNTRYNAME/ST=$PROVINCENAME/L=$KEY_LOCATION/O=$KEY_ORGANIZATION/OU=$KEY_OUN/CN=$KEY_COMMON_NAME/emailAddress=$KEY_MAIL" \
-keyout /etc/ssl/$KEY_COMMON_NAME.key \
-out /etc/ssl/$KEY_COMMON_NAME.crt

chmod 600 /etc/ssl/$KEY_COMMON_NAME.key
