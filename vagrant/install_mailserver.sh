#!/usr/bin/env bash

# load variables
source /vagrant/environment.sh

echo "postfix postfix/mailname string $POSTFIX_MAILNAME" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections

# install components for postfix
$INSTALLER install --assume-yes mutt \
postfix \
libexttextcat-data \
liblockfile-bin \
gnupg-agent \
libksba8 \
libexttextcat-2.0-0 \
libgpgme11 \
libwrap0 \
dovecot-imapd \
libassuan0 \
ssl-cert \
dovecot-pop3d \
dirmngr \
ntpdate \
dovecot-core \
tcpd \
gnupg2 \
liblockfile1 \
pinentry-curses \
libnpth0 \
procmail \
libtokyocabinet9 \
bsd-mailx

$INSTALLER install --assume-yes postfix-mysql \
dovecot-mysql \
postgrey \
amavis \
clamav \
clamav-daemon \
spamassassin \
libdbi-perl \
libdbd-mysql-perl \
php7.0-imap

$INSTALLER install --assume-yes pyzor \
razor \
arj \
cabextract \
lzop \
nomarch \
p7zip-full \
ripole \
rpm2cpio \
tnef \
unzip \
unrar-free \
zip \
zoo


# vmail user setup and folder creation
useradd -r -u 150 -g mail -d /var/vmail -s /sbin/nologin -c "Virtual maildir handler" vmail
mkdir /var/vmail
chmod 770 /var/vmail
chown vmail:mail /var/vmail


# configurng dovecot
# DOVECOT_CONF=/etc/dovecot/dovecot-sql.conf.ext
sed -i "s,#driver =.*,driver = mysql," $DOVECOT_CONF
sed -i "s,#connect =.*,connect = host=$MYSQL_DB_HOST dbname=$MYSQL_DB_PFA user=$MYSQL_PFA_USER password=$MYSQL_PFA_PASS," $DOVECOT_CONF
sed -i "s,#default_pass_scheme =.*,default_pass_scheme = MD5-CRYPT," $DOVECOT_CONF

# add sql query to tell dovecot how to obtain a user password
echo "
# Define the query to obtain a user password.
#
# Note that uid 150 is the \"vmail\" user and gid 8 is the \"mail\" group.
#
password_query = \\
SELECT username as user, password, '/var/vmail/%d/%n' as userdb_home, \\
'maildir:/var/vmail/%d/%n' as userdb_mail, 150 as userdb_uid, 8 as userdb_gid \\
FROM mailbox WHERE username = '%u' AND active = '1'
" >> $DOVECOT_CONF

# add sql query to tell dovecot how to obtain user information
echo "
# Define the query to obtain user information.
#
# Note that uid 150 is the 'vmail' user and gid 8 is the 'mail' group.
#
user_query = \\
SELECT '/var/vmail/%d/%n' as home, 'maildir:/var/vmail/%d/%n' as mail, \\
150 AS uid, 8 AS gid, concat('dirsize:storage=', quota) AS quota \\
FROM mailbox WHERE username = '%u' AND active = '1'
" >> $DOVECOT_CONF

echo "set where Dovecot will read the SQL configuration files"
# DOVECOT_AUTH_CONF=/etc/dovecot/conf.d/10-auth.conf
sed -i "s,#disable_plaintext_auth =.*,disable_plaintext_auth = yes," $DOVECOT_AUTH_CONF
sed -i "s,auth_mechanisms =.*,auth_mechanisms = plain login," $DOVECOT_AUTH_CONF
sed -i 's,!include auth-system.conf.ext.*,#!include auth-system.conf.ext,' $DOVECOT_AUTH_CONF
sed -i 's,#!include auth-sql.conf.ext.*,!include auth-sql.conf.ext,' $DOVECOT_AUTH_CONF

# tell Dovecot where to put the virtual user mail directories.
# DOVECOT_VMAIL_CONF=/etc/dovecot/conf.d/10-mail.conf
sed -i "s,^mail_location =.*,mail_location = maildir:/var/vmail/%d/%n," $DOVECOT_VMAIL_CONF
sed -i "s,^mail_location =.*,mail_location = maildir:/var/vmail/%d/%n," $DOVECOT_VMAIL_CONF
sed -i "s,#mail_uid =.*,mail_uid = vmail," $DOVECOT_VMAIL_CONF
sed -i "s,#mail_gid =.*,mail_gid = mail," $DOVECOT_VMAIL_CONF
sed -i "s,#last_valid_uid =.*,last_valid_uid = 150," $DOVECOT_VMAIL_CONF
sed -i "s,#first_valid_uid =.*,first_valid_uid = 150," $DOVECOT_VMAIL_CONF

# ensure that some SSL protocols that are no longer secure are not used
# DOVECOT_SSL_CONF=/etc/dovecot/conf.d/10-ssl.conf
sed -i "s,ssl = no.*,ssl = yes," $DOVECOT_SSL_CONF
sed -i "s,#ssl_cert =.*,ssl_cert = <$TLS_CERT_FILE," $DOVECOT_SSL_CONF
sed -i "s,#ssl_key =.*,ssl_key = <$TLS_KEY_FILE," $DOVECOT_SSL_CONF
sed -i "s,#ssl_ca =.*,ssl_ca = <$SSL_CA_WITH_CRL_FULLCHAIN," $DOVECOT_SSL_CONF
sed -i "s,#ssl_dh_parameters_length =.*,ssl_dh_parameters_length = 2048," $DOVECOT_SSL_CONF
sed -i 's,#ssl_protocols =.*,ssl_protocols = !SSLv2 !SSLv3,' $DOVECOT_SSL_CONF
sed -i "s,#ssl_prefer_server_ciphers =.*,ssl_prefer_server_ciphers = yes," $DOVECOT_SSL_CONF
sed -i 's,#ssl_cipher_list =.*,ssl_cipher_list = ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA,' $DOVECOT_SSL_CONF

# add the Postfix option
# DOVECOT_MASTER_CONF=/etc/dovecot/conf.d/10-master.conf
perl -i -p0e 's/unix_listener auth-userdb {.*?}/unix_listener auth-userdb {
mode = 0666
user = vmail
group = mail
}/s' $DOVECOT_MASTER_CONF

perl -i -p0e 's/# Postfix smtp-auth.*?}/# Postfix smtp-auth
unix_listener \/var\/spool\/postfix\/private\/auth {
mode = 0666
# Assuming the default Postfix user and group
user = postfix
group = postfix
}/s' $DOVECOT_MASTER_CONF

# DOVECOT_MAILBOXES_CONF=/etc/dovecot/conf.d/15-mailboxes.conf
sed -i "/mailbox Junk {/i   mailbox Archive { \\
auto = subscribe \\
special_use = \\\Archive \\
}" $DOVECOT_MAILBOXES_CONF

sed -i "/mailbox Junk {/a auto = subscribe" $DOVECOT_MAILBOXES_CONF

perl -i -p0e 's/#unix_listener \/var\/spool\/postfix\/private\/auth {.*?}/unix_listener \/var\/spool\/postfix\/private\/auth {
mode = 0666
# Assuming the default Postfix user and group
user = postfix
group = postfix
}/s' $DOVECOT_MAILBOXES_CONF

# DOVECOT_LDA_CONF=/etc/dovecot/conf.d/15-lda.conf
echo "
# Address to use when sending rejection mails.
# Default is postmaster@<your domain>.
postmaster_address = $POSTMASTER_DOVECOT
" >> $DOVECOT_LDA_CONF

# set permissions for dovecot configuration
chown -R vmail:dovecot /etc/dovecot
chmod -R o-rwx /etc/dovecot


# add clamav and amavis user to each others groups
adduser clamav amavis
adduser amavis clamav


# AMAVIS_CONF=/etc/amavis/conf.d/15-content_filter_mode
sed -i "s,#@bypass_virus_checks_maps,@bypass_virus_checks_maps," $AMAVIS_CONF
sed -i 's,#   \\%bypass_virus_checks,   \\%bypass_virus_checks,' $AMAVIS_CONF
sed -i "s,#@bypass_spam_checks_maps,@bypass_spam_checks_maps," $AMAVIS_CONF
sed -i 's,#   \\%bypass_spam_checks,   \\%bypass_spam_checks,' $AMAVIS_CONF

# AMAVIS_DEFAULTS_CONF=/etc/amavis/conf.d/20-debian_defaults
sed -i "s,\$sa_spam_subject_tag.*,\$sa_spam_subject_tag = '***SPAM*** ';," $AMAVIS_DEFAULTS_CONF
sed -i "s,\$sa_tag_level_deflt.*,\$sa_tag_level_deflt  = undef;," $AMAVIS_DEFAULTS_CONF
sed -i "s,\$sa_tag2_level_deflt.*,\$sa_tag2_level_deflt = 5;," $AMAVIS_DEFAULTS_CONF
sed -i "s,\$sa_kill_level_deflt.*,\$sa_kill_level_deflt = 20;," $AMAVIS_DEFAULTS_CONF
sed -i "s,\$sa_dsn_cutoff_level.*,\$sa_dsn_cutoff_level = 10;   # spam level beyond which a DSN is not sent," $AMAVIS_DEFAULTS_CONF


# AMAVIS_USER_ACCESS_CONF=/etc/amavis/conf.d/50-user
sed -i "s,#@bypass_virus_checks_maps,@bypass_virus_checks_maps," $AMAVIS_USER_ACCESS_CONF
sed -i -e '12,13d' $AMAVIS_USER_ACCESS_CONF

# amavis database connection to check for new mails
echo "
\$myauthservid = \"$AMAVIS_DOMAIN\";

@local_domains_acl = ( $AMAVIS_LOCAL_DOMAINS_ACL );

# Three concurrent processes. This should fit into the RAM available on an
# AWS micro instance. This has to match the number of processes specified
# for Amavis in /etc/postfix/master.cf.
\$max_servers  = 4;

# Add spam info headers if at or above that level - this ensures they
# are always added.
\$sa_tag_level_deflt  = -9999;
\$sa_tag2_level_deflt = 6.31; # add 'spam detected' headers at that level

\$sa_spam_subject_tag = '*** SPAM *** ';
\$final_spam_destiny = D_PASS;

# Check the database to see if mail is for local delivery, and thus
# should be spam checked.
@lookup_sql_dsn = (
   ['DBI:mysql:database=$MYSQL_DB_PFA;host=$MYSQL_DB_HOST;port=3306',
    '$MYSQL_PFA_USER',
    '$MYSQL_PFA_PASS']);
\$sql_select_policy = 'SELECT domain from domain WHERE CONCAT(\"@\",domain) IN (%k)';

# Uncomment to bump up the log level when testing.
\$log_level = 2;
#\$sa_debug = 1;

\$hdrfrom_notify_sender = 'Postmaster $AMAVIS_DOMAIN <$POSTMASTER_AMAVIS>';

#------------ Do not modify anything below this line -------------
1;  # ensure a defined return
" >> $AMAVIS_USER_ACCESS_CONF


# activate amavis
# SAPMASSASSIN_DEFAULT=/etc/default/spamassassin
sed -i 's,ENABLED=0,ENABLED=1,' $SAPMASSASSIN_DEFAULT
sed -i 's,CRON=0,CRON=1,' $SAPMASSASSIN_DEFAULT

#SPAMASSASSIN_LOCAL=/etc/spamassassin/local.cf
echo "
#Adjust scores for SPF FAIL
score SPF_FAIL 4.0
score SPF_HELO_FAIL 4.0
score SPF_HELO_SOFTFAIL 3.0
score SPF_SOFTFAIL 3.0

#adjust DKIM scores
score DKIM_ADSP_ALL 3.0
score DKIM_ADSP_DISCARD  10.0
score DKIM_ADSP_NXDOMAIN 3.0

#dmarc fail
header CUST_DMARC_FAIL Authentication-Results =~ /mail\.example\.com; dmarc=fail/
score CUST_DMARC_FAIL 5.0

#dmarc pass
header CUST_DMARC_PASS Authentication-Results =~ /mail\.example\.com; dmarc=pass/
score CUST_DMARC_PASS -1.0

meta CUST_DKIM_SIGNED_INVALID DKIM_SIGNED && !(DKIM_VALID || DKIM_VALID_AU)
score CUST_DKIM_SIGNED_INVALID 6.0
" >> $SPAMASSASSIN_LOCAL

ESCAPED_DOMAIN_APP_NAME=$(printf "%s" "$SPAMASSASSIN_DOMAIN" | sed 's|\.|\\\\\\.|g')
sed -i  "s;mail\\\.example\\\.com;$ESCAPED_DOMAIN_APP_NAME;g" $SPAMASSASSIN_LOCAL

freshclam

# Add Postgrey whitelists
#POSTGREY_DEFAULT=/etc/default/postgrey
echo "
POSTGREY_OPTS=\"\$POSTGREY_OPTS --whitelist-clients=/etc/postgrey/whitelist_clients\"
POSTGREY_OPTS=\"\$POSTGREY_OPTS --whitelist-recipients=/etc/postgrey/whitelist_recipients\"
" >> $POSTGREY_DEFAULT


systemctl restart clamav-daemon
systemctl restart amavis
systemctl restart spamassassin
systemctl restart postgrey


# configure postfix
#POSTFIX_MYSQL_VIRTUAL_ALIAS_DOMAIN=/etc/postfix/mysql_virtual_alias_domainaliases_maps.cf
echo "
user = $MYSQL_PFA_USER
password = $MYSQL_PFA_PASS
hosts =  $MYSQL_DB_HOST
dbname = $MYSQL_DB_PFA
query = SELECT goto FROM alias,alias_domain
WHERE alias_domain.alias_domain = '%d'
AND alias.address=concat('%u', '@', alias_domain.target_domain)
AND alias.active = 1
" >> $POSTFIX_MYSQL_VIRTUAL_ALIAS_DOMAIN

#POSTIFX_MYSQL_VIRTUAL_ALIAS=/etc/postfix/mysql_virtual_alias_maps.cf
echo "
user = $MYSQL_PFA_USER
password = $MYSQL_PFA_PASS
hosts =  $MYSQL_DB_HOST
dbname = $MYSQL_DB_PFA
table = alias
select_field = goto
where_field = address
additional_conditions = and active = '1'
" >> $POSTIFX_MYSQL_VIRTUAL_ALIAS

#POSTIFX_MYSQL_VIRTUAL_DOMAINS=/etc/postfix/mysql_virtual_domains_maps.cf
echo "
user = $MYSQL_PFA_USER
password = $MYSQL_PFA_PASS
hosts =  $MYSQL_DB_HOST
dbname = $MYSQL_DB_PFA
table = domain
select_field = domain
where_field = domain
additional_conditions = and backupmx = '0' and active = '1'
" >> $POSTIFX_MYSQL_VIRTUAL_DOMAINS

#POSTFIX_VIRTUAL_MAILBOX_DOMAIN_ALIAS=/etc/postfix/mysql_virtual_mailbox_domainaliases_maps.cf
echo "
user = $MYSQL_PFA_USER
password = $MYSQL_PFA_PASS
hosts =  $MYSQL_DB_HOST
dbname = $MYSQL_DB_PFA
query = SELECT maildir FROM mailbox, alias_domain
WHERE alias_domain.alias_domain = '%d'
AND mailbox.username=concat('%u', '@', alias_domain.target_domain )
AND mailbox.active = 1
" >> $POSTFIX_VIRTUAL_MAILBOX_DOMAIN_ALIAS

#POSTFIX_VIRTUAL_MAILBOX=/etc/postfix/mysql_virtual_mailbox_maps.cf
echo "
user = $MYSQL_PFA_USER
password = $MYSQL_PFA_PASS
hosts =  $MYSQL_DB_HOST
dbname = $MYSQL_DB_PFA
table = mailbox
select_field = CONCAT(domain, '/', local_part)
where_field = username
additional_conditions = and active = '1'
" >> $POSTFIX_VIRTUAL_MAILBOX

#POSTFIX_VIRTUAL_SENDER=/etc/postfix/mysql_virtual_sender_login_maps.cf
echo "
user = $MYSQL_PFA_USER
password = $MYSQL_PFA_PASS
hosts =  $MYSQL_DB_HOST
dbname = $MYSQL_DB_PFA
query = SELECT goto FROM alias WHERE address='%s'
" >> $POSTFIX_VIRTUAL_SENDER

# contains some directives to remove certain headers when relaying mail.
# POSTIFX_HEADERS=/etc/postfix/header_checks
echo "
/^Received:/                 IGNORE
/^User-Agent:/               IGNORE
/^X-Mailer:/                 IGNORE
/^X-Originating-IP:/         IGNORE
/^x-cr-[a-z]*:/              IGNORE
/^Thread-Index:/             IGNORE
" >> $POSTIFX_HEADERS


## TODO(work with postconf -e as much as possible)
# download main.cf fro postfix from github
# POSTFIX_MAIN=/etc/postfix/main.cf
mv $POSTFIX_MAIN $POSTFIX_MAIN.orig
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/template_main.cf --no-check-certificate -O $POSTFIX_MAIN

postconf -e "smtpd_tls_cert_file = $TLS_CERT_FILE"
postconf -e "smtpd_tls_key_file = $TLS_KEY_FILE"
postconf -e "smtpd_tls_CAfile = $SSL_CA_WITH_CRL_FULLCHAIN"
postconf -# "smtpd_tls_CAfile"
postconf -e "smtpd_tls_dh1024_param_file = $DH_PARAMS_FILE"
postconf -e "myhostname = $POSTFIX_MAILNAME"
postconf -e "smtpd_tls_auth_only = no"

# ====================
# TLSA DANE support
# -------------------
postconf -e "smtp_tls_security_level = dane"
postconf -e "smtpd_use_tls = yes"
postconf -e "smtp_use_tls = yes"
postconf -e "smtp_dns_support_level = dnssec"
postconf -e "smtp_tls_loglevel = 1"

# download master.cf fro postfix from github
# POSTFIX_MASTER=/etc/postfix/master.cf
mv $POSTFIX_MASTER $POSTFIX_MASTER.orig
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/template_master.cf --no-check-certificate -O $POSTFIX_MASTER
