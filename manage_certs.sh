#!/bin/sh
CERTS_PATH=/var/www/ssl
CSR_CONFIG=$3
CERT_CUSTOM=$2
ADMIN_MAIL=root #is used for letsencrypt and should be a real mail address

Pause() {
  (tty_state=$(stty -g)
  stty -icanon
  LC_ALL=C dd bs=1 count=1 >/dev/null 2>&1
  stty "$tty_state"
  ) </dev/tty
}

if [ "$1" != "read_config" ]; then
    echo "Adjust the ADMIN_MAIL and CERTS_PATH and comment out this line!"
    Pause
fi

usage() {
	echo "------------------------
	USAGE: build_cert MODE CUSTOM_CERT_PART_NAME [CSR_REQUEST.conf]
	------------------------
	MODES:
	- create_csr_config (needs CSR_REQUEST.conf parameter, will write this will)
	- create_yearly_key (needs CSR_REQUEST.conf parameter, reads this file)
		(calls create_request,create_cert,tlsa_record)
	- create_request (needs CSR_REQUEST.conf parameter, reads this file)
		(calls create_cert,tlsa_record)
	- create_cert
	- tlsa_record
	- copy_certs_to_prod
	- revoke_cert
	- check_expiry
	- read_config

	CUSTOM_CERT_PART_NAME:
	It is used as a part in the complete path to the certifcates:
	e.g.: $CERTS_PATH/example.com/cert.pem
	'example.com' is the CUSTOM_CERT_PART_NAME.

	[CSR_REQUEST.conf]:
	- optional, but required for some MODES
	- filename or full filepath with paramter for the csr request
	- filename or full filepath to existing file when creating the csr request
	------------------------"
}

read_config() {
	printf "Enter the country name\n---------------: e.g.: DE \n"
	read -r COUNTRYNAME

        printf "Enter the state or province name\n---------------: e.g.: Niedersachsen \n"
	read -r PROVINCENAME

	printf "Enter the city or location name\n---------------: e.g.: Lüneburg \n"
	read -r KEY_LOCATION

	printf "Enter the postcal code\n---------------: e.g.: 21337 \n"
	read -r KEY_POST_CODE

	printf "Enter the street name\n---------------: e.g.: Wallstraße \n"
	read -r KEY_STREET

	printf "Enter the organization name\n---------------: e.g.: Organization \n"
	read -r KEY_ORGANIZATION

	printf "Enter the organizational unit name\n---------------: e.g.: IT \n"
	read -r KEY_OUN

	printf "Enter the common name (base domain)\n---------------: e.g.: example.com \n"
	read -r KEY_COMMON_NAME

	printf "Enter the email address\n---------------: e.g.: %s\n" "$ADMIN_MAIL"
	read -r KEY_MAIL

	printf "Enter all domains and subdomains,\ncomma separated for this certificate,\nbut not the common name (%s)\n---------------: \n" "$KEY_COMMON_NAME"
	read -r KEY_ALL_DOMAINS_TEMP
}

create_csr_config() {
	read_config

	if [ ! -z "$KEY_ALL_DOMAINS_TEMP" ];
	then
		KEY_ALL_DOMAINS=$(echo "$KEY_ALL_DOMAINS_TEMP" | sed -e 's/.*/DNS:&/' -e 's/,/,DNS:/g' )
	fi

	if echo "$CSR_CONFIG" | grep -q "/" ; then
  	        FOLDER_LOCATION=$(dirname "$CSR_CONFIG")
		if [ ! -d "$FOLDER_LOCATION" ]; then
		        mkdir -p "$FOLDER_LOCATION";
		fi
	fi

	cat << CSR_WRITE > "$CSR_CONFIG"
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
	postalCode = "$KEY_POST_CODE"
	streetAddress = "$KEY_STREET"
	organizationName = "$KEY_ORGANIZATION"
	organizationalUnitName = "$KEY_OUN"
	commonName = "$KEY_COMMON_NAME"
	emailAddress = "$KEY_MAIL"

	[ v3_req ]
	subjectAltName = $KEY_ALL_DOMAINS
CSR_WRITE

	if echo "$CSR_CONFIG" | grep "/" ;
	then
		echo "---------------
		The csr request config was created here: $CSR_CONFIG !
		---------------";
	else
		LOCATION=$(pwd)
		if [ "$LOCATION" != "/" ]; then LOCATION=${LOCATION}/; fi
		echo "---------------
		The csr request config was created here: ${LOCATION}$CSR_CONFIG !
		---------------";
	fi
}

create_yearly_key() {
	echo "---------------
	Create 4096 private key in ${CERTS_PATH}/${CERT_CUSTOM}/new/privkey.pem
	---------------"
	openssl genrsa -out ${CERTS_PATH}/"${CERT_CUSTOM}"/new/privkey.pem 4096
	create_request
}

create_request() {
	if [ ! -f "$CSR_CONFIG" ]; then
	        echo "file $CSR_CONFIG does not exist"
	        exit 1
	fi
	echo "---------------
	Create Request file
	---------------"
	openssl req -config "$CSR_CONFIG" -new -key $CERTS_PATH/"${CERT_CUSTOM}"/new/privkey.pem -out $CERTS_PATH/"${CERT_CUSTOM}"/new/request.csr -outform der
	create_cert
}

create_cert() {
	echo "---------------
	Create Cert
	remove testing if you are sure to request production certs
	---------------"
	Pause
	/opt/letsencrypt/letsencrypt-auto certonly \
	-a webroot \
	--webroot-path /var/www/letsencrypt/ \
	--email $ADMIN_MAIL \
	--csr $CERTS_PATH/"$CERT_CUSTOM"/new/request.csr \
	--key-path $CERTS_PATH/"${CERT_CUSTOM}"/new/privkey.pem \
	--cert-path $CERTS_PATH/"${CERT_CUSTOM}"/new/cert.pem \
	--fullchain-path $CERTS_PATH/"${CERT_CUSTOM}"/new/fullchain.pem \
	--chain-path $CERTS_PATH/"${CERT_CUSTOM}"/new/chain.pem \
	--rsa-key-size 4096 \
	--test-cert

	if [ -f $CERTS_PATH/"${CERT_CUSTOM}"/new/privkey.pem ] && [ -f $CERTS_PATH/"${CERT_CUSTOM}"/new/cert.pem ]; then
	        cat $CERTS_PATH/"${CERT_CUSTOM}"/new/privkey.pem > $CERTS_PATH/"${CERT_CUSTOM}"/new/keycert.pem
	fi
	if [ -f $CERTS_PATH/"${CERT_CUSTOM}"/new/cert.pem ]; then
	        cat $CERTS_PATH/"${CERT_CUSTOM}"/new/cert.pem >> $CERTS_PATH/"${CERT_CUSTOM}"/new/keycert.pem
	fi
	if [ -f $CERTS_PATH/"${CERT_CUSTOM}"/new/keycert.pem ]; then
	        chmod 600 $CERTS_PATH/"${CERT_CUSTOM}"/new/keycert.pem
	fi
	tlsa_record
	copy_certs_to_staging
}

tlsa_record() {
echo "extract TLSA record"
TLSA_RECORD_CERT_PATH=$CERTS_PATH/${CERT_CUSTOM}/new/fullchain.pem
if [ ! -f "$TLSA_RECORD_CERT_PATH" ]
then
TLSA_RECORD_CERT_PATH=$CERTS_PATH/${CERT_CUSTOM}/fullchain.pem
fi
if [ ! -f "$TLSA_RECORD_CERT_PATH" ]; then echo "TLSA Record gen error, fullchain not found";usage;exit; fi
TLSA_RECORDS=$(bash /var/scripts/chaingen.bash "$TLSA_RECORD_CERT_PATH" "$CERT_CUSTOM")
mail -s "TLSA Records for $CERT_CUSTOM." $ADMIN_MAIL <<EOM
$TLSA_RECORDS
EOM
echo "$TLSA_RECORDS"
}

copy_certs_to_staging() {
	if [ -f ${CERTS_PATH}/"${CERT_CUSTOM}"/new/fullchain.pem ]
	then
		mkdir -p ${CERTS_PATH}/"${CERT_CUSTOM}"/staging
		mv ${CERTS_PATH}/"${CERT_CUSTOM}"/new/*.* ${CERTS_PATH}/"${CERT_CUSTOM}"/staging/
		mv ${CERTS_PATH}/"${CERT_CUSTOM}"/staging/request.csr ${CERTS_PATH}/"${CERT_CUSTOM}"/new/
		cp ${CERTS_PATH}/"${CERT_CUSTOM}"/staging/privkey.pem ${CERTS_PATH}/"${CERT_CUSTOM}"/new/
	fi
}

copy_certs_to_prod() {
	ARCH_DATE="$(date +%d-%m-%Y)"
	if [ -f ${CERTS_PATH}/"${CERT_CUSTOM}"/fullchain.pem ] && [ -f ${CERTS_PATH}/"${CERT_CUSTOM}"/staging/fullchain.pem ] || [ -f ${CERTS_PATH}/"${CERT_CUSTOM}"/staging/fullchain.pem ]
        then
                mkdir -p ${CERTS_PATH}/"${CERT_CUSTOM}"/archive/"$ARCH_DATE"
                mv -f ${CERTS_PATH}/"${CERT_CUSTOM}"/*.pem ${CERTS_PATH}/"${CERT_CUSTOM}"/archive/"$ARCH_DATE"
                mv ${CERTS_PATH}/"${CERT_CUSTOM}"/staging/*.* ${CERTS_PATH}/"${CERT_CUSTOM}"/
        revoke_cert
	fi
}

revoke_cert() {
	echo "---------------
	run this:
	bash /opt/letsencrypt/letsencrypt-auto revoke --cert-path ${CERTS_PATH}/${CERT_CUSTOM}/archive/..cert.pem
	---------------"
}

check_expiry() {
	PRINT=true
	MAIL=true
	LOGGER=false
	ADMIN_MAIL=webmaster@example.com
	warning_days=10
	certs_to_check='example.com:443
	imap.example.com:25
	example2.com:443
	example3.com:443
	'

	$PRINT && printf "%4s %26s   %-38s %s\n" "Days" "Expires On" "Domain" "Options" | tee -a /tmp/cert_expiry.log

	for CERT in $certs_to_check
	do
	       	add_opts=''
	       	if [ "$(echo "$CERT" | cut -d: -f2)" -eq 25 ]; then
	       		add_opts='-starttls smtp'
	       	fi
	       	domain="$(echo "$CERT" | cut -d: -f1)"


	       	if ! output=$(openssl s_client -showcerts -connect "${CERT}" \
	       		-servername "$domain" "$add_opts" < /dev/null 2>/dev/null |\
	       		openssl x509 -noout -dates 2>/dev/null);
	       		then
	       		$PRINT && echo "Error connecting to host for cert [$CERT]"
	       		$LOGGER && logger -p local6.warn "Error connecting to host for cert [$CERT]"
	       		$MAIL && mail -s "Error connecting to host for cert [$CERT]" $ADMIN_MAIL
	       		continue
	       	fi

	       	start_date=$(echo "$output" | grep 'notBefore=' | cut -d= -f2)
	       	end_date=$(echo "$output" | grep 'notAfter=' | cut -d= -f2)

	       	start_epoch=$(date +%s -d "$start_date")
	       	end_epoch=$(date +%s -d "$end_date")
	       	epoch_now=$(date +%s)

	       	if [ "$start_epoch" -gt "$epoch_now" ]; then
	       		$PRINT && echo "Certificate for [$CERT] is not yet valid"
	       		$LOGGER && logger -p local6.warn "Certificate for $CERT is not yet valid"
	                $MAIL && mail -s "Certificate for [$CERT] is not yet valid" $ADMIN_MAIL
	       	fi

	       	days_to_expire=$(((end_epoch - epoch_now) / 86400))

	       	if [ "$days_to_expire" -lt "$warning_days" ]; then
	       		$PRINT && printfn "\033[91m"
	       		$LOGGER && logger -p local6.warn "cert [$CERT] is soon to expire ($days_to_expire days)"
	       	        $MAIL && mail -s "cert [$CERT] is soon to expire ($days_to_expire days)" $ADMIN_MAIL
	       	fi
	       	$PRINT && printf "%4i %26s   %-38s %s\033[0m\n" "$days_to_expire" "$end_date" "$CERT" "$add_opts" | tee -a /tmp/cert_expiry.log
	done
	       	$MAIL && mail -s "Certificate Status" $ADMIN_MAIL < /tmp/cert_expiry.log
	if [ -f /tmp/cert_expiry.log ]; then
	        rm -f /tmp/cert_expiry.log
	fi
}

if [ "$1" = "check_expiry" ];then check_expiry;exit;
	elif [ "$1" = "read_config" ];then read_config;return 0;
	elif [ $# -lt 2 ]; then	usage;exit;
	elif [ $# -ge 2 ]; then
	        if [ ! -d $CERTS_PATH/"$CERT_CUSTOM"/new ]; then
	                mkdir -p $CERTS_PATH/"$CERT_CUSTOM"/new;
	        fi
fi

case "$1" in
	revoke_cert)
		revoke_cert
	;;
	create_csr_config)
	  if [ $# -ne 3 ]; then echo "---------------
		CSR REQUEST config parameter needed
		---------------";usage;exit; fi
		create_csr_config
	;;
	copy_certs_to_prod)
		copy_certs_to_prod
	;;
	read_config)
		read_config
	;;
	tlsa_record)
		tlsa_record
	;;
	create_cert)
		create_cert
	;;
	create_yearly_key)
		if [ $# -ne 3 ]; then echo "---------------
		CSR REQUEST config parameter needed
		---------------";usage;exit; fi
		create_yearly_key
	;;
	create_request)
	  if [ $# -ne 3 ]; then echo "---------------
		CSR REQUEST config parameter needed
		---------------";usage;exit; fi
		create_request
	;;
	*)
	usage
	exit 3
	;;
esac
