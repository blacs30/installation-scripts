#!/bin/sh

PRINT=true
MAIL=true
ADMIN_MAIL=webmaster@example.com
LOGGER=false
warning_days=10
certs_to_check='example.com:443
imap.example.com:25
example2.com:443
example3.com:443
'

$PRINT && printf "%4s %26s   %-38s %s\n" "Days" "Expires On" "Domain" "Options"

for CERT in $certs_to_check
do
       	add_opts=''
       	if [ "$(echo "$CERT" | cut -d: -f2)" -eq 25 ]; then
       		add_opts='-starttls smtp'
       	fi
       	domain="$(echo "$CERT" | cut -d: -f1)"
       	output=$(openssl s_client -showcerts -connect "${CERT}" \
       		-servername "$domain" $add_opts < /dev/null 2>/dev/null |\
       		openssl x509 -noout -dates 2>/dev/null)

       	if [ "$?" -ne 0 ]; then
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
       		$PRINT && echo -en "\033[91m"
       		$LOGGER && logger -p local6.warn "cert [$CERT] is soon to expire ($days_to_expire days)"
       	        $MAIL && mail -s "cert [$CERT] is soon to expire ($days_to_expire days)" $ADMIN_MAIL
       	fi
       	$PRINT && printf "%4i %26s   %-38s %s\033[0m\n" "$days_to_expire" "$end_date" "$CERT" "$add_opts" | tee -a /tmp/cert_expiry.log
done
       	$MAIL && mail -s "Certificate Status" $ADMIN_MAIL < /tmp/cert_expiry.log
[[ -f /tmp/cert_expiry.log ]] && rm -f /tmp/cert_expiry.log
