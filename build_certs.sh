#!/bin/sh
# https://gist.github.com/lkiesow/c9c5d96ecb71822b82cd9d194c581cc8

CERTS_PATH=/var/www/ssl
PK_CONFIG=$3
CERT_CUSTOM=$2
ADMIN_MAIL=webmaster@example.com

[[ ! -d $CERTS_PATH/$CERT_CUSTOM/new ]] && mkdir -p $CERTS_PATH/$CERT_CUSTOM/new

usage() {
echo "------------------------
USAGE: build_cert MODE CUSTOM_CERT_PATH_NAME [PRIVATE_KEY.conf]
------------------------
MODES:
- create_key_config
- create_yearly_key (needs PRIVATE_KEY.conf parameter)
	(calls create_request,create_cert,tlsa_record)
- create_request (needs PRIVATE_KEY.conf parameter)
	(calls create_cert,tlsa_record)
- create_cert
- tlsa_record
- copy_certs
- revoke_cert
"
}

create_key_config () {
# use input interactivly later
echo "adjust this part to your need before you run this method" && exit 1
cat << VHOST_CREATE > $PK_CONFIG
[ req ]
default_md = sha512
prompt = no
encrypt_key = no
distinguished_name = req_distinguished_name
req_extensions = v3_req

[ req_distinguished_name ]
countryName = "DE"
stateOrProvinceName = "Niedersachsen"
localityName = "Lüneburg"
postalCode = "21337"
streetAddress = "Wallstraße"
organizationName = "Organisation"
organizationalUnitName = "IT"
commonName = "imap.example.com"
emailAddress = "admin@example.com"

[ v3_req ]
subjectAltName = DNS:smtp.example.com,DNS:imap.example2.com,DNS:smtp.example2.com
VHOST_CREATE
}

create_yearly_key() {
echo "Create 4096 private key in ${CERTS_PATH}/${CERT_CUSTOM}/new/privkey.pem"
openssl genrsa -out ${CERTS_PATH}/${CERT_CUSTOM}/new/privkey.pem 4096
create_request
}

create_request() {
[[ ! -f $PK_CONFIG ]] && echo "file $PK_CONFIG does not exist" && exit 1
echo "Create Request file"
openssl req -config $PK_CONFIG -new -key $CERTS_PATH/${CERT_CUSTOM}/new/privkey.pem -out $CERTS_PATH/${CERT_CUSTOM}/new/request.csr -outform der
create_cert
}

create_cert() {
echo "Create Cert"
/opt/letsencrypt/letsencrypt-auto certonly \
-a webroot \
--webroot-path /var/www/letsencrypt/ \
--email $ADMIN_MAIL \
--csr $CERTS_PATH/$CERT_CUSTOM/new/request.csr \
--key-path $CERTS_PATH/${CERT_CUSTOM}/new/privkey.pem \
--cert-path $CERTS_PATH/${CERT_CUSTOM}/new/cert.pem \
--fullchain-path $CERTS_PATH/${CERT_CUSTOM}/new/fullchain.pem \
--chain-path $CERTS_PATH/${CERT_CUSTOM}/new/chain.pem \
--rsa-key-size 4096

[[ -f $CERTS_PATH/${CERT_CUSTOM}/new/privkey.pem ]] && [[ -f $CERTS_PATH/${CERT_CUSTOM}/new/cert.pem ]] && cat $CERTS_PATH/${CERT_CUSTOM}/new/privkey.pem > $CERTS_PATH/${CERT_CUSTOM}/new/keycert.pem
[[ -f $CERTS_PATH/${CERT_CUSTOM}/new/cert.pem ]] && cat $CERTS_PATH/${CERT_CUSTOM}/new/cert.pem >> $CERTS_PATH/${CERT_CUSTOM}/new/keycert.pem
[[ -f $CERTS_PATH/${CERT_CUSTOM}/new/keycert.pem ]] && chmod 600 $CERTS_PATH/${CERT_CUSTOM}/new/keycert.pem
tlsa_record
}


copy_certs() {
ARCH_DATE="$(date +%d-%m-%Y)"
if [ -f ${CERTS_PATH}/${CERT_CUSTOM}/fullchain.pem ] && [ -f ${CERTS_PATH}/${CERT_CUSTOM}/new/fullchain.pem ] || [ -f ${CERTS_PATH}/${CERT_CUSTOM}/new/fullchain.pem ]
then
mkdir -p ${CERTS_PATH}/${CERT_CUSTOM}/archive/$ARCH_DATE
mv -f ${CERTS_PATH}/${CERT_CUSTOM}/*.pem ${CERTS_PATH}/${CERT_CUSTOM}/archive/$ARCH_DATE
mv ${CERTS_PATH}/${CERT_CUSTOM}/new/*.* ${CERTS_PATH}/${CERT_CUSTOM}/
mv ${CERTS_PATH}/${CERT_CUSTOM}/request.csr ${CERTS_PATH}/${CERT_CUSTOM}/new/
cp ${CERTS_PATH}/${CERT_CUSTOM}/privkey.pem ${CERTS_PATH}/${CERT_CUSTOM}/new/
fi
revoke_cert
}

revoke_cert() {
echo "run this:
bash /opt/letsencrypt/letsencrypt-auto revoke --cert-path ${CERTS_PATH}/${CERT_CUSTOM}/archive/..cert.pem"
}

if [ $# -lt 2 ]; then usage;exit; fi
case "$1" in
	revoke_cert)
		revoke_cert
	;;
	copy_certs)
		copy_certs
	;;
	tlsa_record)
		tlsa_record
	;;
	create_cert)
		create_cert
	;;
	create_yearly_key)
		if [ $# -ne 3 ]; then echo "PRIVATE_KEY.conf needed";usage;exit; fi
		create_yearly_key
	;;
	create_request)
		create_request
	;;
	*)
	usage
	exit 3
	;;
esac
