#!/usr/bin/env bash
openssl dhparam -out /etc/ssl/example.com_dhparams.pem 2048
chmod 400 /etc/ssl/example.com_dhparams.pem
