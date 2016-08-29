#!/bin/sh
# https://gist.github.com/lkiesow/c9c5d96ecb71822b82cd9d194c581cc8

CERTS_PATH=/var/www/ssl
PK_CONFIG=$3
# LE_CERT_CONFIG=/etc/letsencrypt/config/lisowski-development.com.with_cert.conf
CERT_CUSTOM=$2
ADMIN_MAIL=webmaster@lisowski-development.com

[[ ! -d $CERTS_PATH/$CERT_CUSTOM/new ]] && mkdir -p $CERTS_PATH/$CERT_CUSTOM/new

create_yearly_key () {
echo "Create private key"
openssl genrsa -out ${CERTS_PATH}/${CERT_CUSTOM}/new/privkey.pem 4096
create_request
}

create_request () {
[[ ! -f $PK_CONFIG ]] && echo "file $PK_CONFIG does not exist" && exit 1
echo "Create Request file"
openssl req -config $PK_CONFIG -new -key $CERTS_PATH/${CERT_CUSTOM}/new/privkey.pem -out $CERTS_PATH/${CERT_CUSTOM}/new/request.csr -outform der

create_cert
tlsa3_record
}

create_cert () {
# [[ ! -f $LE_CERT_CONFIG ]] && echo "file $LE_CERT_CONFIG does not exist" && exit 1
echo "Create Cert"
# /opt/letsencrypt/letsencrypt-auto certonly --config $LE_CERT_CONFIG
/opt/letsencrypt/letsencrypt-auto certonly -t --debug --renew -a webroot --webroot-path /var/www/letsencrypt/ --kep --email $ADMIN_MAIL --csr $CERTS_PATH/$CERT_CUSTOM/request.csr --key-path $CERTS_PATH/${CERT_CUSTOM}/new/privkey.pem --cert-path $CERTS_PATH/${CERT_CUSTOM}/new/cert.pem --fullchain-path $CERTS_PATH/${CERT_CUSTOM}/new/fullchain.pem --chain-path $CERTS_PATH/${CERT_CUSTOM}/new/chain.pem --rsa-key-size 4096
}

tlsa3_record () {
echo "extract TLSA record"
printf '_25._tcp.%s. IN TLSA 3 1 1 %s\n' \
    $(uname -n) \
    $(openssl x509 -in $CERTS_PATH/${CERT_CUSTOM}/new/cert.pem -noout -pubkey |
        openssl pkey -pubin -outform DER |
        openssl dgst -sha256 -binary |
        hexdump -ve '/1 "%02x"')
}

move_certs () {
if [ -f ${CERTS_PATH}/${CERT_CUSTOM}/fullchain.pem ] && [ -f ${CERTS_PATH}/${CERT_CUSTOM}/new/fullchain.pem ] then
rm -f ${CERTS_PATH}/${CERT_CUSTOM}/*.pem
mv ${CERTS_PATH}/${CERT_CUSTOM}/new/*.pem ${CERTS_PATH}/${CERT_CUSTOM}/.
cp ${CERTS_PATH}/${CERT_CUSTOM}/privkey.pem ${CERTS_PATH}/${CERT_CUSTOM}/new/.
}

case "$1" in
