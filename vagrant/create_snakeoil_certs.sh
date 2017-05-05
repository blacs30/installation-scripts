#!/usr/bin/env bash

# URL https://coolaj86.com/articles/create-your-own-certificate-authority-for-testing/

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

echo "Running create_snakeoil_certs.sh"

source /vagrant/environment.sh

# * * * * * * * * * * * * * * *
# Define alternateDNS entry
# * * * * * * * * * * * * * * *
# From the array build the alternateDNS variable with DNS: and commas
KEY_SUBJ_ALT_NAME_TEMP=
counter=0
for i in ${KEY_SUBJ_ALT_NAME[*]}; do
	if [ "$counter" == "0" ]; then
		ADD_ALT_DOMAIN=DNS:$i
		KEY_SUBJ_ALT_NAME_TEMP=${KEY_SUBJ_ALT_NAME_TEMP}${ADD_ALT_DOMAIN}
	else
		ADD_ALT_DOMAIN=,DNS:$i
		KEY_SUBJ_ALT_NAME_TEMP=${KEY_SUBJ_ALT_NAME_TEMP}${ADD_ALT_DOMAIN}
	fi
counter=$((counter + 1))
done

# check in case there are no alternateDNS and set the alternateDNS to the KEY_COMMON_NAME
if [ -z $KEY_SUBJ_ALT_NAME_TEMP ]; then
	KEY_SUBJ_ALT_NAME=DNS:$KEY_COMMON_NAME
else
	KEY_SUBJ_ALT_NAME=$KEY_SUBJ_ALT_NAME_TEMP
fi

# * * * * * * * * * * * * * * *
# Create Root Certificate Authority
# * * * * * * * * * * * * * * *
mkdir -p ${SSL_PATH}/ca
openssl genrsa -passout pass:$CA_PASS -aes256 \
  -out ${SSL_PATH}/ca/server.ca.key.pem 4096

chmod 600 ${SSL_PATH}/ca/server.ca.key.pem


# * * * * * * * * * * * * * * *
# Self-sign your Root Certificate Authority
# * * * * * * * * * * * * * * *
openssl req \
  -x509 \
  -new \
  -nodes \
  -key ${SSL_PATH}/ca/server.ca.key.pem \
  -passin pass:$CA_PASS \
  -days 9131 \
  -out ${SSL_PATH}/ca/server.ca.crt.pem \
  -subj "/C=$COUNTRYNAME/ST=$PROVINCENAME/L=$KEY_LOCATION/O=$KEY_ORGANIZATION/CN=$KEY_COMMON_NAME"

chmod 600 ${SSL_PATH}/ca/server.ca.crt.pem




# * * * * * * * * * * * * * * *
# This is for a simple snakeoil cert without a CA
# * * * * * * * * * * * * * * *
#openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096  \
#-subj "/C=$COUNTRYNAME/ST=$PROVINCENAME/L=$KEY_LOCATION/O=$KEY_ORGANIZATION/OU=$KEY_OUN/CN=$KEY_COMMON_NAME/emailAddress=$KEY_MAIL" \
#-keyout "$TLS_KEY_FILE" \
#-out "$TLS_CERT_FILE"


# * * * * * * * * * * * * * * *
# Create Certificate for domain and Create CSR
# * * * * * * * * * * * * * * *
# make directories to work from
mkdir -p $SSL_PATH/{servers,tmp}

# Create Certificate for this domain
mkdir -p "$SSL_PATH/servers/${KEY_COMMON_NAME}"
openssl genrsa \
  -out "$TLS_KEY_FILE" \
  4096

chmod 600 "$TLS_KEY_FILE"

# --> Create CSR request file
cat << CSR_WRITE > "$SSL_PATH"/tmp/${KEY_COMMON_NAME}.ini
[ req ]
default_md = sha512
prompt = no
encrypt_key = no
distinguished_name = req_distinguished_name
req_extensions = v3_req

[ req_distinguished_name ]
countryName = "$COUNTRYNAME"
stateOrProvinceName = "$PROVINCENAME"
localityName = "$KEY_LOCATION"
organizationName = "$KEY_ORGANIZATION"
organizationalUnitName = "$KEY_OUN"
commonName = "$KEY_COMMON_NAME"
emailAddress = "$KEY_MAIL"

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = $KEY_SUBJ_ALT_NAME
CSR_WRITE

# Create the CSR
openssl req -new \
  -out "$SSL_PATH/tmp/${KEY_COMMON_NAME}.csr.pem" \
  -key "$TLS_KEY_FILE" \
  -config "$SSL_PATH/tmp/${KEY_COMMON_NAME}.ini"
# without password at the moment as monit does not support it


# Sign the request from Server with your Root CA
openssl x509 \
  -req -days 9131 -in $SSL_PATH/tmp/${KEY_COMMON_NAME}.csr.pem \
  -CA $SSL_PATH/ca/server.ca.crt.pem \
  -passin pass:$CA_PASS \
  -CAkey $SSL_PATH/ca/server.ca.key.pem \
  -CAcreateserial \
  -out $TLS_CERT_FILE \
  -extfile "$SSL_PATH/tmp/${KEY_COMMON_NAME}.ini" \
  -extensions v3_req


# fullchain: certs/servers/${KEY_COMMON_NAME}/fullchain.pem
# (contains Server CERT, Intermediates and Root CA)
cat \
  "$SSL_PATH/servers/${KEY_COMMON_NAME}/cert.pem" \
  "$SSL_PATH/ca/server.ca.crt.pem" \
  > "$SSL_CA_WITH_CRL_FULLCHAIN"

chmod 600 "$SSL_CA_WITH_CRL_FULLCHAIN"


# combined: certs/servers/${KEY_COMMON_NAME}/combined.pem
# (contains Server CERT and Server KEY)
cat \
  "$TLS_KEY_FILE" \
  "$TLS_CERT_FILE" \
  > "$TLS_COMBINED"

chmod 600 "$TLS_COMBINED"
