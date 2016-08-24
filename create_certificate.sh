# create certificate
cd /tmp
openssl genrsa -out privkey.pem 4096


cat << VHOST_CREATE > /tmp/imap.example.cert.conf
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

openssl req -config /tmp/imap.example.cert.conf -new -key privkey.pem -out request.csr -outform der

/opt/letsencrypt/letsencrypt-auto certonly -a manual --key-path privkey.pem --cert-path cert.pem --fullchain-path fullchain.pem --csr /tmp/request.csr


echo "extract TLSA record"
printf '_25._tcp.%s. IN TLSA 3 1 1 %s\n' \
    $(uname -n) \
    $(openssl x509 -in cert.pem -noout -pubkey |
        openssl pkey -pubin -outform DER |
        openssl dgst -sha256 -binary |
        hexdump -ve '/1 "%02x"')
