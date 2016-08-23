letsencrypt config


echo "
root@lisowski-development:/opt/letsencrypt# cat /etc/letsencrypt/config/global.mailing.conf
# the domain we want to get the cert for;
# technically it's possible to have multiple of this lines, but it only worked
# with one domain for me, another one only got one cert, so I would recommend
# separate config files per domain.
domains = imap.lisowski-development.com, smtp.lisowski-development.com, imap.lisowski-photography.com, smtp.lisowski-photography.com, imap.wyzwaniemilosci.com, smtp.wyzwaniemilosci.com

# increase key size
rsa-key-size = 2048 # Or 4096

# this address will receive renewal reminders
email = webmaster@lisowski-development.com

# turn off the ncurses UI, we want this to be run as a cronjob
text = True

# authenticate by placing a file in the webroot (under .well-known/acme-challenge/)
# and then letting LE fetch it
authenticator = webroot
webroot-path = /var/www/letsencrypt/
" >> /etc/letsencrypt/config/global.mailing.conf

mkdir  /var/www/letsencrypt/

run
/opt/letsencryp/letsencrypt-auto certonly --dry-run  --config /etc/letsencrypt/config/global.mailing.conf


./letsencrypt-auto revoke --cert-path /etc/letsencrypt/live/<domain name>/cert.pem
