# Install Mailserver and components
I have read through a couple of different HowTo's, tutorials pages for some particular configurations until I came up with a working mailserver setup. The setup tries to guide through the main steps of setting up a mailserver. I hope the steps are neither to highlevel nor go to deep into detail. At the end I have listed some very helpful resources where some further questions might be answered. Of course all documentations of the used software is recommended firstly for more understanding of the software itself.  
The mailserver uses virtual mailaccounts with can be managed e.g. by Postfix Admin, a web interface for the configuration of postfix users and domains as well as aliases. A manual on how to install is separately available.

### Install prerequisites

Following components are required. Check other manuals on how to install them.
- [mysql-server](./install_mysql.md)
- [nginx](./install_nginx.md)  
- [php-fpm](./install_phpfpm.md)  
- [postfixadmin](./install_postfixadmin.md)  
- [phpmyadmin](./install_phpmyadmin.md)  

In case you want to use ssl/tls --> **all steps assume that ssl/tls is used** :  
- [ssl (or snakeoil certs, works for testing)](./create_snakeoil_certs.md)    
- [optional but recommended to create a new stronger __dh key__](./create_dh_key.md)  


### Chapters  
- [Install mailserver componentes](#install_components)
- [Configure Dovecot](#configure_dovecot)
- [Configure Amavis, ClamAV, SpamAssassin, Postgrey](#configure_virusspam)
- [Configure Postfix](#configure_postfix)
- [Configure SPF](#configure_spf)
- [Configure DKIM](#configure_dkim)
- [Configure DMARC](#configure_dmarc)
- [Configure DANE](#configure_dane)
- [Install and configure SRS](#configure_srs)
- [Configure SIEVE](#configure_sieve)
- [Restart services](#restart_services)
- [References](#references)


Configure the firewall for at least these incoming/outgoing ports:  
```
------------------------------
Open at following ports
in the firewall for the mailserver:
22 (SSH)
25 (SMTP)
53 (DNS)
80 (HTTP)
110 (POP3)
143 (IMAP)
443 (HTTPS)
465 (SMTPS)
993 (IMAPS)
995 (POP3S)
------------------------------
```

### <a name="install_components"></a> Install components

At first let's install the required components for the mailserver.   
Postfix as SMTP server and dovecot for IMAP/POP3.  
Amavis with Clamav for virus protection.  
Postgrey and spamassassin for spam checks.

```bash
aptitude install mutt \
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
bsd-mailx \
aptitude install postfix-mysql \
dovecot-mysql \
postgrey \
amavis \
clamav \
clamav-daemon \
spamassassin \
libdbi-perl \
libdbd-mysql-perl \
php7.0-imap \
pyzor \
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
```

As written before postfix will use virtual users for email accounts. It would be also possible with local, real users on the server but that's not part of this installation. The users will be stored in the database. It is either mysql or postresql (that is what postfix admin supports).   
To start now we create the user vmail as a system account. Assign a home directory and created it and set the shell to nologin.  
```
useradd --system --uid 150 --gid mail --home-dir /var/vmail -s /sbin/nologin -c "Virtual maildir handler" vmail
mkdir /var/vmail
chmod 770 /var/vmail
chown vmail:mail /var/vmail
```

### <a name="configure_dovecot"></a> Configure dovecot
Now that the software is installed we start witht he configure.  

Edit `/etc/dovecot/dovecot-sql.conf.ext` and set the following settings. This tells dovecot that we use mysql and which database and user it needs to connect.
We also tell dovecot which password schema is stored in the database.

```
driver = mysql
connect = host=127.0.0.1 dbname=maildb user=maildbuser password=maildbuserpass
default_pass_scheme = MD5-CRYPT
```

Configure the password_query and user_query to reflect the two following code blocks.  
```
# Define the query to obtain a user password.
#
# Note that uid 150 is the "vmail" user and gid 8 is the "mail" group.
#
password_query = \\
SELECT username as user, password, '/var/vmail/%d/%n' as userdb_home, \\
'maildir:/var/vmail/%d/%n' as userdb_mail, 150 as userdb_uid, 8 as userdb_gid \\
FROM mailbox WHERE username = '%u' AND active = '1'
```

```
# Define the query to obtain user information.
#
# Note that uid 150 is the 'vmail' user and gid 8 is the 'mail' group.
#
user_query = \\
SELECT '/var/vmail/%d/%n' as home, 'maildir:/var/vmail/%d/%n' as mail, \\
150 AS uid, 8 AS gid, concat('dirsize:storage=', quota) AS quota \\
FROM mailbox WHERE username = '%u' AND active = '1'
```

In the file `/etc/dovecot/conf.d/10-auth.conf` set the following configuration:

```
# Disable LOGIN command and all other plaintext authentications unless
# SSL/TLS is used (LOGINDISABLED capability). Note that if the remote IP
# matches the local IP (ie. you're connecting from the same computer), the
# connection is considered secure and plaintext authentication is allowed.
disable_plaintext_auth = yes

### We use SSL so plain and login is fine
### (see explanation here https://wiki2.dovecot.org/Authentication/Mechanisms)
auth_mechanisms = plain login

### Disable sql configuration for authentication
#!include auth-system.conf.ext

### Enable sql configuration for authentication
!include auth-sql.conf.ext
```

In the file `/etc/dovecot/conf.d/10-mail.conf` set the following configuration. We tell dovecot some information about the virtual user directories and the owner and group.

```
mail_location = maildir:/var/vmail/%d/%n
mail_location = maildir:/var/vmail/%d/%n
mail_uid = vmail
mail_gid = mail
last_valid_uid = 150
first_valid_uid = 150
```


In the file `/etc/dovecot/conf.d/10-ssl.conf` set the following configuration which is required so that we get the SSL/TLS connection running:


```
ssl = yes
# you can use purchased / letsencrypt too of course
ssl_cert = </etc/ssl/certs/ssl-cert-snakeoil.pem
ssl_key = </etc/ssl/private/ssl-cert-snakeoil.key


# PEM encoded trusted certificate authority. Set this only if you intend to use
# ssl_verify_client_cert=yes. The file should contain the CA certificate(s)
# followed by the matching CRL(s). (e.g. ssl_ca = </etc/ssl/certs/ca.pem)
ssl_ca = </etc/ssl/certs/ca-bundle.crt

ssl_dh_parameters_length = 2048
ssl_protocols = !SSLv2 !SSLv3
ssl_prefer_server_ciphers = yes
ssl_cipher_list = ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA
```

In the file `/etc/dovecot/conf.d/10-master.conf` make the "service auth" section reflect this configure which adds postfix user and group:  

```
service auth {
  # auth_socket_path points to this userdb socket by default. It's typically
  # used by dovecot-lda, doveadm, possibly imap process, etc. Users that have
  # full permissions to this socket are able to get a list of all usernames and
  # get the results of everyone's userdb lookups.
  #
  # The default 0666 mode allows anyone to connect to the socket, but the
  # userdb lookups will succeed only if the userdb returns an "uid" field that
  # matches the caller process's UID. Also if caller's uid or gid matches the
  # socket's uid or gid the lookup succeeds. Anything else causes a failure.
  #
  # To give the caller full permissions to lookup all users, set the mode to
  # something else than 0666 and Dovecot lets the kernel enforce the
  # permissions (e.g. 0777 allows everyone full permissions).
  unix_listener auth-userdb {
    mode = 0666
    user = vmail
    group = mail
  }

  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    # Assuming the default Postfix user and group
    user = postfix
    group = postfix
  }
```

Edit the file `/etc/dovecot/conf.d/15-mailboxes.conf`. I add the default mailbox "archive" and set the Junk mailbox to "subscribe" too. That lets a mail application automatically use these folders for spam or archved messages.

```
mailbox Archive {
  auto = subscribe
  special_use = \Archive
}
mailbox Junk {
  auto = subscribe
  special_use = \Junk
}
```

I came accros the error message "Invalid settings: postmaster_address setting not given" in the mail log. That is fixed by setting the postmaster_address manually in `/etc/dovecot/conf.d/15-lda.conf`  
`postmaster_address = postmaster@example.com`

Set permissions on the dovecot configuration so that vmail users and dovecot can access it:  
```
# set owner/group
chown -R vmail:dovecot /etc/dovecot
# remove rwx from others
chmod -R o-rwx /etc/dovecot
```

### <a name="configure_virusspam"></a> Configure Amavis, ClamAV, SpamAssassin, Postgrey
##### Notes on amavis
This section handles the configuration for the anti spam and virus tools. The integration of these tools into postfix is described in the postfix section further below. Most of the default configuration is working fine and doesn't need much adjustment. Of course there is still potential and the possibility for creating own rules etc.


First add Amavis and ClamAV users to one another's groups to enable them to collaborate:
```bash
adduser clamav amavis
adduser amavis clamav
```

Amavis is disabled by default, enable it by uncommenting the following lines in this file `/etc/amavis/conf.d/15-content_filter_mode`:  

```
@bypass_virus_checks_maps
\%bypass_virus_checks
@bypass_spam_checks_maps
\%bypass_spam_checks
```

Configure amavis by defining for which domains it should check the mails. The database connection is configured too and some spam levels define. File: `/etc/amavis/conf.d/50-user`

```
$myauthservid = "example.com";

@local_domains_acl = ( "example.com" );

# Three concurrent processes. This should fit into the RAM available on an
# AWS micro instance. This has to match the number of processes specified
# for Amavis in /etc/postfix/master.cf.
$max_servers  = 2;

# Add spam info headers if at or above that level - this ensures they
# are always added.
$sa_tag_level_deflt  = -9999;
$sa_tag2_level_deflt = 6.31; # add 'spam detected' headers at that level

$sa_spam_subject_tag = '*** SPAM *** ';
$final_spam_destiny = D_PASS;

# Check the database to see if mail is for local delivery, and thus
# should be spam checked.
@lookup_sql_dsn = (
   ['DBI:mysql:database=maildb;host=127.0.0.1;port=3306',
    'maildbuser',
    'maildbuserpass']);
$sql_select_policy = 'SELECT domain from domain WHERE CONCAT(@,domain) IN (%k)';

# Uncomment to bump up the log level when testing.
$log_level = 2;
#$sa_debug = 1;

$hdrfrom_notify_sender = 'Postmaster example.com <postmaster@example.com>';

#------------ Do not modify anything below this line -------------
1;  # ensure a defined return
```

##### Notes on spamassassin

Now let's enable spamassassin by editing the `/etc/default/spamassassin`  
```
ENABLED=1
CRON=1
```

In `/etc/spamassassin/local.cf` add following lines at the end. This will set some scores depending on specific occurances. Later in this instruction we configure SPF, DKIM and DMARK. Depending on the results from the checks the scores fill be increased (possibly spam) or decreased (possibly no spam.) Replace the mail.examle.com mail with your own domain, watch the escape characters!

```
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
```


##### Notes on postgrey
Postgrey comes with prepared whitelist configuration files for clients and recipients. They are not enabled by default though.  There are 2 ways to trigger their usage.
1. Copy them into `/etc/postfix`  
```bash
cp /etc/postgrey/whitelist_clients /etc/postfix/postgrey_whitelist_clients
cp /etc/postgrey/whitelist_recipients /etc/postfix/postgrey_whitelist_recipients
```
2. Add them to the POSTGREY_OPTS in `/etc/default/postgrey`. I have added the loopback address, 127.0.0.1, to the "--inet" parameter as without postfix couldn't communicate with postgrey.  
```
# postgrey startup options, created for Debian

# you may want to set
#   --delay=N   how long to greylist, seconds (default: 300)
#   --max-age=N delete old entries after N days (default: 35)
# see also the postgrey(8) manpage

POSTGREY_OPTS="--inet=127.0.0.1:10023"

# the --greylist-text commandline argument can not be easily passed through
# POSTGREY_OPTS when it contains spaces.  So, insert your text here:
POSTGREY_TEXT="Mail rejected by postgrey"

POSTGREY_OPTS="$POSTGREY_OPTS --whitelist-clients=/etc/postgrey/whitelist_clients"
POSTGREY_OPTS="$POSTGREY_OPTS --whitelist-recipients=/etc/postgrey/whitelist_recipients"
```
### <a name="configure_postfix"></a> Configure Postfix

Postfix needs to be configured in a similiar way as dovecot. It needs to know where it can find information about users. For this a couple of files will be created with sql queries. In these queries the "hosts" parameter should be "127.0.0.1" instead of "localhost". I haven't tried external databases but that should work too. Only with local mysql-server there is a difference between the loopback and the the hostname. Binding mysql to the same as entered as hosts (localhost) didn't change anything for me.

Additionally we configure postfix to check the incoming mails by using the tools like clamav postgrey etc before sending the mail to dovecot and therewith to the user.


When creating these files make sure you have the spaces in some of the queries with the "WHERE" and "AND" statements.  
Create file `/etc/postfix/mysql_virtual_alias_domainaliases_maps.cf`  
```
user = maildbuser
password = maildbuserpass
hosts =  127.0.0.1
dbname = maildb
query = SELECT goto FROM alias,alias_domain
  WHERE alias_domain.alias_domain = '%d'
  AND alias.address=concat('%u', '@', alias_domain.target_domain)
  AND alias.active = 1
```

Create file `/etc/postfix/mysql_virtual_alias_maps.cf`  
```
user = maildbuser
password = maildbuserpass
hosts =  127.0.0.1
dbname = maildb
table = alias
select_field = goto
where_field = address
additional_conditions = and active = '1'
```

Create file `/etc/postfix/mysql_virtual_domains_maps.cf`  
```
user = maildbuser
password = maildbuserpass
hosts =  127.0.0.1
dbname = maildb
table = domain
select_field = domain
where_field = domain
additional_conditions = and backupmx = '0' and active = '1'
```

Create file `/etc/postfix/mysql_virtual_mailbox_domainaliases_maps.cf`  
```
user = maildbuser
password = maildbuserpass
hosts =  127.0.0.1
dbname = maildb
query = SELECT maildir FROM mailbox, alias_domain
  WHERE alias_domain.alias_domain = '%d'
  AND mailbox.username=concat('%u', '@', alias_domain.target_domain )
  AND mailbox.active = 1
```


Create file `/etc/postfix/mysql_virtual_mailbox_maps.cf`  
```
user = maildbuser
password = maildbuserpass
hosts =  127.0.0.1
dbname = maildb
table = mailbox
select_field = CONCAT(domain, '/', local_part)
where_field = username
additional_conditions = and active = '1'
```

Create file `/etc/postfix/mysql_virtual_sender_login_maps.cf`  
```
user = maildbuser
password = maildbuserpass
hosts =  127.0.0.1
dbname = maildb
query = SELECT goto FROM alias WHERE address='%s'
```

Create the file `/etc/postfix/header_checks`. Postfix can inspect the mail and based on the regexp or pcre search result an action is performed. There are templates on google which reject or discard many mails which are spam but we want to leave this to our other tools. Here the header check is deleting entries to hide some internal information before sending a message out.  
```
/^Received:/                 IGNORE
/^User-Agent:/               IGNORE
/^X-Mailer:/                 IGNORE
/^X-Originating-IP:/         IGNORE
/^x-cr-[a-z]*:/              IGNORE
/^Thread-Index:/             IGNORE
```

As next we configure the `/etc/postfix/main.cf` of postfix. This is a template and for the base configuration following values should be adjusted:   
- smtpd_tls_cert_file
- smtpd_tls_key_file
- smtpd_tls_CAfile (if available, not necessarily when using snakeoil keys)
- smtpd_tls_dh1024_param_file
- myhostname

```
# See /usr/share/postfix/main.cf.dist for a commented, more complete version

# The first text sent to a connecting process.
smtpd_banner = $myhostname ESMTP $mail_name
biff = no
# appending .domain is the MUA's job.
append_dot_mydomain = no
readme_directory = no

# ---------------------------------
# SASL parameters
# ---------------------------------

# Use Dovecot to authenticate.
smtpd_sasl_type = dovecot
# Referring to /var/spool/postfix/private/auth
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
# Enable interoperability with remote SMTP clients that implement an obsolete version of the AUTH command (RFC 4954).
# Examples of such clients are MicroSoft Outlook Express version 4 and MicroSoft Exchange version 5.0.
broken_sasl_auth_clients = no
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain =
smtpd_sasl_authenticated_header = yes

# ---------------------------------
# TLS parameters
# ---------------------------------
# Ensure we're not using no-longer-secure protocols.

tls_ssl_options = NO_COMPRESSION
tls_high_cipherlist=EDH+CAMELLIA:EDH+aRSA:EECDH+aRSA+AESGCM:EECDH+aRSA+SHA384:EECDH+aRSA+SHA256:EECDH:+CAMELLIA256:+AES256:+CAMELLIA128:+AES128:+SSLv3:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!DSS:!RC4:!SEED:!ECDSA:CAMELLIA256-SHA:AES256-SHA:CAMELLIA128-SHA:AES128-SHA
tls_random_source = dev:/dev/urandom

### outgoing connections ###
# Enable (but don't force) all outgoing smtp connections to use TLS.
smtp_tls_security_level = may

smtp_tls_mandatory_protocols = !SSLv2, !SSLv3
smtp_tls_protocols = !SSLv2, !SSLv3

smtp_tls_note_starttls_offer = yes
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache


### incoming connections ###
# Note that forcing use of TLS is going to cause breakage - most mail servers
# don't offer it and so delivery will fail, both incoming and outgoing. This is
# unfortunate given what various governmental agencies are up to these days.
#
# Enable (but don't force) all incoming smtp connections to use TLS.
smtpd_tls_security_level = may

# According to RFC 2487 this MUST NOT be applied in case of a publicly-referenced SMTP server.
smtpd_tls_auth_only = no

# The default snakeoil certificate. Comment if using a purchased
# SSL certificate.
smtpd_tls_cert_file = /var/www/mail.example.com/ssl/mail.example.com.crt
smtpd_tls_key_file = /var/www/mail.example.com/ssl/mail.example.com.key


# The snakeoil self-signed certificate has no need for a CA file. But
# if you are using your own SSL certificate, then you probably have
# a CA certificate bundle from your provider. The path to that goes
# here.
# smtpd_tls_CAfile = /etc/letsencrypt/live/www.example.com/fullchain.pem
# smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt

smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3
smtpd_tls_protocols = !SSLv2, !SSLv3
smtpd_tls_loglevel = 1
smtpd_tls_received_header = yes
smtpd_tls_session_cache_timeout = 3600s
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache

# See /usr/share/doc/postfix/TLS_README.gz in the postfix-doc package for
# information on enabling SSL in the smtp client.

# ---------------------------------
# TLS Updates relating to Logjam SSL attacks.
# See: https://weakdh.org/sysadmin.html
# ---------------------------------
smtpd_tls_exclude_ciphers = aNULL, eNULL, EXPORT, DES, RC4, MD5, PSK, aECDH, EDH-DSS-DES-CBC3-SHA, EDH-RSA-DES-CDC3-SHA, KRB5-DE5, CBC3-SHA
smtpd_tls_dh1024_param_file = /var/www/mail.example.com/ssl/dhparams.pem

### outgoing connections secure ###


### incoming connections secure ###

# ---------------------------------
# SMTPD general parameters
# ---------------------------------

# Uncomment the next line to generate "delayed mail" warnings
#delay_warning_time = 4h

# will it be a permanent error or temporary
unknown_local_recipient_reject_code = 450

# how long to keep message on queue before return as failed.
maximal_queue_lifetime = 7d

# max and min time in seconds between retries if connection failed
minimal_backoff_time = 1000s
maximal_backoff_time = 8000s

# how long to wait when servers connect before receiving rest of data
smtp_helo_timeout = 60s

# how many address can be used in one message.
# effective stopper to mass spammers, accidental copy in whole address list
# but may restrict intentional mail shots.
smtpd_recipient_limit = 16

# how many error before back off.
smtpd_soft_error_limit = 3

# how many max errors before blocking it.
smtpd_hard_error_limit = 12


# This next set are important for determining who can send mail and relay mail
# to other servers. It is very important to get this right - accidentally producing
# an open relay that allows unauthenticated sending of mail is a Very Bad Thing.
#
# You are encouraged to read up on what exactly each of these options accomplish.

# Requirements for the HELO statement
smtpd_helo_restrictions = permit_mynetworks, warn_if_reject reject_non_fqdn_hostname, reject_invalid_hostname, permit

# Requirements for the sender details. Note that the order matters.
# E.g. see http://jimsun.linxnet.com/misc/restriction_order_prelim-03.txt
smtpd_sender_restrictions = permit_mynetworks, reject_authenticated_sender_login_mismatch, permit_sasl_authenticated, warn_if_reject reject_non_fqdn_sender, reject_unknown_sender_domain, reject_unauth_pipelining, permit

# Requirements for the connecting server
smtpd_client_restrictions = reject_rbl_client sbl.spamhaus.org, reject_rbl_client cbl.abuseat.org

# Requirement for the recipient address. Note that the entry for
# "check_policy_service inet:127.0.0.1:10023" enables Postgrey.
smtpd_recipient_restrictions = reject_unauth_pipelining, permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_recipient, reject_unknown_recipient_domain, reject_unauth_destination, check_policy_service inet:127.0.0.1:10023, check_policy_service unix:private/policy-spf, permit
smtpd_data_restrictions = reject_unauth_pipelining

# This is a new option as of Postfix 2.10, and is required in addition to
# smtpd_recipient_restrictions for things to work properly in this setup.
smtpd_relay_restrictions = reject_unauth_pipelining, permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_recipient, reject_unknown_recipient_domain, reject_unauth_destination, check_policy_service inet:127.0.0.1:10023, permit

# require proper helo at connections
smtpd_helo_required = yes

# waste spammers time before rejecting them
smtpd_delay_reject = yes
disable_vrfy_command = yes

# ---------------------------------
# General host and delivery info
# ----------------------------------

myhostname = mail.example.com
myorigin = /etc/hostname

# Some people see issues when setting mydestination explicitly to the server
# subdomain, while leaving it empty generally doesn't hurt. So it is left empty here.
# mydestination = mail.example.com, localhost
mydestination =

# If you have a separate web server that sends outgoing mail through this
# mailserver, you may want to add its IP address to the space-delimited list in
# mynetworks, e.g. as 10.10.10.10/32.
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
mynetworks_style = host
message_size_limit = 20480000

# This specifies where the virtual mailbox folders will be located.
virtual_mailbox_base = /var/vmail

# This is for the mailbox location for each user. The domainaliases
# map allows us to make use of Postfix Admin's domain alias feature.
virtual_mailbox_maps = mysql:/etc/postfix/mysql_virtual_mailbox_maps.cf, mysql:/etc/postfix/mysql_virtual_mailbox_domainaliases_maps.cf

# and their user id
virtual_uid_maps = static:150

# and group id
virtual_gid_maps = static:8

# This is for aliases. The domainaliases map allows us to make
# use of Postfix Admin's domain alias feature.
virtual_alias_maps = mysql:/etc/postfix/mysql_virtual_alias_maps.cf, mysql:/etc/postfix/mysql_virtual_alias_domainaliases_maps.cf
alias_maps = hash:/etc/aliases

# This is for domain lookups.
virtual_mailbox_domains = mysql:/etc/postfix/mysql_virtual_domains_maps.cf

# Used in conjunction with reject_authenticated_sender_login_mismatch to
# verify that the sender is sending with their own address, or with one
# of the aliases mapped to that address.
smtpd_sender_login_maps = mysql:/etc/postfix/mysql_virtual_sender_login_maps.cf

# ---------------------------------
# Integration with other packages
# ---------------------------------------

# Tell postfix to hand off mail to the definition for dovecot in master.cf
virtual_transport = dovecot
dovecot_destination_recipient_limit = 1

# Use amavis for virus and spam scanning
content_filter = smtp-amavis:[127.0.0.1]:10024

# ---------------------------------
# Header manipulation
# --------------------------------------

# Getting rid of unwanted headers. See: https://posluns.com/guides/header-removal/
header_checks = regexp:/etc/postfix/header_checks

# getting rid of x-original-to
enable_original_recipient = no
```

Next configure the `/etc/postfix/master.cf` the following way:  

```
#
# Postfix master process configuration file.  For details on the format
# of the file, see the master(5) manual page (command: "man 5 master").
#
# Do not forget to execute "postfix reload" after editing this file.
#
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (yes)   (never) (100)
# ==========================================================================

# SMTP on port 25, unencrypted.
smtp       inet  n       -       -       -       -       smtpd
#smtp      inet  n       -       -       -       1       postscreen
#smtpd     pass  -       -       -       -       -       smtpd
#dnsblog   unix  -       -       -       -       0       dnsblog
#tlsproxy  unix  -       -       -       -       0       tlsproxy

# SMTP with TLS on port 587. Currently commented.
#submission inet n       -       -       -       -       smtpd
#  -o syslog_name=postfix/submission
#  -o smtpd_tls_security_level=encrypt
#  -o smtpd_sasl_auth_enable=yes
#  -o smtpd_enforce_tls=yes
#  -o smtpd_client_restrictions=permit_sasl_authenticated,reject_unauth_destination,reject
#  -o smtpd_sasl_tls_security_options=noanonymous

# SMTP over SSL on port 465.
smtps     inet  n       -       -       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject_unauth_destination,reject
  -o smtpd_sasl_security_options=noanonymous,noplaintext
  -o smtpd_sasl_tls_security_options=noanonymous

#628       inet  n       -       -       -       -       qmqpd
pickup    fifo  n       -       -       60      1       pickup
  -o content_filter=
  -o receive_override_options=no_header_body_checks
cleanup   unix  n       -       -       -       0       cleanup
qmgr      fifo  n       -       n       300     1       qmgr
#qmgr     fifo  n       -       n       300     1       oqmgr
tlsmgr    unix  -       -       -       1000?   1       tlsmgr
rewrite   unix  -       -       -       -       -       trivial-rewrite
bounce    unix  -       -       -       -       0       bounce
defer     unix  -       -       -       -       0       bounce
trace     unix  -       -       -       -       0       bounce
verify    unix  -       -       -       -       1       verify
flush     unix  n       -       -       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       -       -       -       smtp
relay     unix  -       -       -       -       -       smtp
#       -o smtp_helo_timeout=5 -o smtp_connect_timeout=5
showq     unix  n       -       -       -       -       showq
error     unix  -       -       -       -       -       error
retry     unix  -       -       -       -       -       error
discard   unix  -       -       -       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       -       -       -       lmtp
anvil     unix  -       -       -       -       1       anvil
scache    unix  -       -       -       -       1       scache
#
# ====================================================================
# Interfaces to non-Postfix software. Be sure to examine the manual
# pages of the non-Postfix software to find out what options it wants.
#
# Many of the following services use the Postfix pipe(8) delivery
# agent.  See the pipe(8) man page for information about ${recipient}
# and other message envelope options.
# ====================================================================
#
# maildrop. See the Postfix MAILDROP_README file for details.
# Also specify in main.cf: maildrop_destination_recipient_limit=1
#
maildrop  unix  -       n       n       -       -       pipe
  flags=DRhu user=vmail argv=/usr/bin/maildrop -d ${recipient}
#
# ====================================================================
#
# Recent Cyrus versions can use the existing "lmtp" master.cf entry.
#
# Specify in cyrus.conf:
#   lmtp    cmd="lmtpd -a" listen="localhost:lmtp" proto=tcp4
#
# Specify in main.cf one or more of the following:
#  mailbox_transport = lmtp:inet:localhost
#  virtual_transport = lmtp:inet:localhost
#
# ====================================================================
#
# Cyrus 2.1.5 (Amos Gouaux)
# Also specify in main.cf: cyrus_destination_recipient_limit=1
#
#cyrus     unix  -       n       n       -       -       pipe
#  user=cyrus argv=/cyrus/bin/deliver -e -r ${sender} -m ${extension} ${user}
#
# ====================================================================
# Old example of delivery via Cyrus.
#
#old-cyrus unix  -       n       n       -       -       pipe
#  flags=R user=cyrus argv=/cyrus/bin/deliver -e -m ${extension} ${user}
#
# ====================================================================
#
# See the Postfix UUCP_README file for configuration details.
#
uucp      unix  -       n       n       -       -       pipe
  flags=Fqhu user=uucp argv=uux -r -n -z -a$sender - $nexthop!rmail ($recipient)
#
# Other external delivery methods.
#
ifmail    unix  -       n       n       -       -       pipe
  flags=F user=ftn argv=/usr/lib/ifmail/ifmail -r $nexthop ($recipient)
bsmtp     unix  -       n       n       -       -       pipe
  flags=Fq. user=bsmtp argv=/usr/lib/bsmtp/bsmtp -t$nexthop -f$sender $recipient
scalemail-backend unix  -       n       n       -       2       pipe
  flags=R user=scalemail argv=/usr/lib/scalemail/bin/scalemail-store ${nexthop} ${user} ${extension}
mailman   unix  -       n       n       -       -       pipe
  flags=FR user=list argv=/usr/lib/mailman/bin/postfix-to-mailman.py
  ${nexthop} ${user}

# The next two entries integrate with Amavis for anti-virus/spam checks.
smtp-amavis      unix    -       -       -       -       2       smtp
  -o smtp_data_done_timeout=1200
  -o smtp_send_xforward_command=yes
  -o disable_dns_lookups=yes
  -o max_use=20
  -o smtp_tls_security_level=none
127.0.0.1:10025 inet    n       -       -       -       -       smtpd
  -o content_filter=
  -o local_recipient_maps=
  -o relay_recipient_maps=
  -o smtpd_restriction_classes=
  -o smtpd_delay_reject=no
  -o smtpd_client_restrictions=permit_mynetworks,reject
  -o smtpd_helo_restrictions=
  -o smtpd_sender_restrictions=
  -o smtpd_recipient_restrictions=permit_mynetworks,reject
  -o smtpd_data_restrictions=reject_unauth_pipelining
  -o smtpd_end_of_data_restrictions=
  -o mynetworks=127.0.0.0/8
  -o smtpd_error_sleep_time=0
  -o smtpd_soft_error_limit=1001
  -o smtpd_hard_error_limit=1000
  -o smtpd_client_connection_count_limit=0
  -o smtpd_client_connection_rate_limit=0
  -o receive_override_options=no_header_body_checks,no_unknown_recipient_checks,no_milters
  -o smtp_tls_security_level=none  

# Integration with Dovecot - hand mail over to it for local delivery, and
# run the process under the vmail user and mail group.
dovecot      unix   -        n      n       -       -   pipe
  flags=DRhu user=vmail:mail argv=/usr/lib/dovecot/dovecot-lda -d $(recipient)
```

Note that amavis is restricted to 2 processes. You can change this in the master.cf and the amavis configuration.

You could test the mailserver internally by now already. When sending mails out and receiving mails from the world there are some other important things to setup.   
- Make sure to configure reverse DNS otherwise mails might be rejected
- configure the mx DNS entry

And there are further specifications to make sure mails are not spam and to ensure that mails were not modified between sending and receiving. We start with SPF.


### <a name="configure_spf"></a> Configure SPF

(SPF) Sender Policy Framework advertises the domain's mailserver by an DNS entry. To check incoming mails domain's SPF DNS entry some additions have to be configured. - [SPF FAQ](http://www.openspf.org/FAQ/Common_mistakes)

`aptitude install postfix-policyd-spf-python`

Edit the file `/etc/postfix-policyd-spf-python/policyd-spf.conf`  

We want to set the HELO_reject to false so that an incoming mail is not immediately rejected but a header appended and spamassassin can inspect it later.  
```
HELO_reject = False
Mail_From_reject = False
```

Next we configure postfix for SPF. Add the following lines to the `/etc/postfix/main.cf`:  
```
# --------------------------------------
# SPF
# --------------------------------------
policy-spf_time_limit = 3600s

### this is only for the testing period
### send each mail in a blind copy to the postmaster
always_bcc = postmaster@example.com
```

In the master.cf `/etc/postfix/master.cf` add the spf policy:  
```
# --------------------------------------
# SPF
# --------------------------------------
policy-spf unix  -       n       n       -       -       spawn user=nobody
```

Depending on the way how you set DNS entries you might have following entries:
```
reate an DNS TXT entry at
@    MX    5   mail.example.com
@    TXT       v=spf1 a mx -all
@    A         IP
```


### <a name="configure_dkim"></a> Configure DKIM
DKIM (DomainKeys Identified Mail) description from [Wikipedia](https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail):  
> DomainKeys Identified Mail (DKIM) is an email authentication method designed to detect email spoofing. It allows the receiver to check that an email claimed to have come from a specific domain was indeed authorized by the owner of that domain.

To make usage of this additional mechanism we need to install first some packages:  
`aptitude install opendkim opendkim-tools`

Configure dkim `/etc/opendkim.conf` this way:  

```
Canonicalization relaxed/simple
Mode sv
Domain example.com
KeyFile /etc/postfix/dkim.key
Selector dkim
SOCKET inet:8891@127.0.0.1
```

Add the "SOCKET" configuration to the `/etc/default/opendkim`:  
```
SOCKET="inet:8891@localhost"
```

Postfix has to know about dkim too and what it should do. Add the following lines in `/etc/postfix/main.cf`  
```
#-----------------
# DKIM config
#-----------------
milter_default_action = accept
milter_protocol = 2
smtpd_milters = inet:127.0.0.1:8891,inet:127.0.0.1:8892
non_smtpd_milters = inet:127.0.0.1:8891,inet:127.0.0.1:8892
```

Now we have to generate the dkim.key with this command:  
```
opendkim-genkey --selector dkim --domain example.com
```

You have created with the above command a file dkim.key and dkim.txt. The first is the private key which is signing the mail, the second is the public key which is added as a DNS entry
Move the dkim.key into place and assign right ownership and permissions. Keep a copy for yourself in a safe place too.
```
mv dkim.private /etc/postfix/dkim.key
chmod 660 /etc/postfix/dkim.key
chown root:opendkim /etc/postfix/dkim.key
```

Read the dkim.txt and create an DNS TXT entry in the following way, notice the first "dkim" has to be the same as the selector entered before:  
```
dkim._domainkey.example.com. IN TXT "v=DKIM1; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC9rulKo58JIb5h+3MMEnYhlnbuVgRoA4w68R/X7qA2Lfv3RpdrrUb+r7KxemIo6PUIOm6uZ5OymhBgpJ0LAWBHBSJjnFmDXNajSgxMOcvkpgmVCW1/k1kxK864WVVSyFVQPyUImqklY+ws4u+mog3PSbuq2J8NFAnvSwzMg3vT1QIDAQAB"
```

### <a name="configure_dmarc"></a> Configure DMARC

Whereas SPF is telling others which domains can send from your mailserver and dkim is a way to ensure that the mail was really send from you and not somebody else is DMARC (Domain-based Message Authentication, Reporting & Conformance) more focussed on reporting and authentication.

It is helpful to use it in connection with SPF and DKIM.

Install its package.
```bash
aptitude install opendmarc
```


For DMARC reporting functionality we use a database in which a couple of information is saved (domains, ipaddr, messages, reporters, requests, signatures) and reports send to those who request it.  

```mysql
CREATE DATABASE IF NOT EXISTS opendmarc;
GRANT ALL PRIVILEGES ON opendmarc.* TO 'myuser'@'localhost' IDENTIFIED BY 'myuserpass';
```

Import the mysql schema to create the table structure. Opendmarc delivers it and is found in /usr/share/doc/opendmarc/schema.mysql.
The command looks this way:  
```bash
mysql -umyuser -pmyuserpass -hlocalhost < /usr/share/doc/opendmarc/schema.mysql
```

Edit the `/etc/opendmarc.conf` and adjust it this way or modify it to your needs - [explanations here](http://www.trusteddomain.org/opendmarc/opendmarc.conf.5.html):  

```
AuthservID mail.example.com
RejectFailures false
Syslog true
PidFile /var/run/opendmarc.pid
TrustedAuthservIDs HOSTNAME
UMask 0002
UserID opendmarc:opendmarc
HistoryFile /var/run/opendmarc/opendmarc.dat
IgnoreHosts /etc/opendmarc/ignore.hosts
IgnoreMailFrom example.com,example2.com

# For testing
SoftwareHeader true
```

Create the file `/etc/opendmarc/ignore.hosts` which we just defined in the config. Adjust the content to your needs:   
```
127.0.0.1
mail.example.com
```

Add the socket on which opendmarc should listen to the `/etc/default/opendmarc` defaults:  
```
SOCKET="inet:8892@127.0.0.1"
```

So far so good, to send out reports we need a script. We run it via cron jobs. The file can be e.g. here: `/etc/opendmarc/report_script`    
```bash
#!/usr/bin/env bash

DB_SERVER=localhost
DB_USER=myuser
DB_PASS=myuserpass
DB_NAME='opendmarc'
WORK_DIR='/run/opendmarc'
REPORT_EMAIL=abuse@example.com
REPORT_ORG=mail.example.com

mv ${WORK_DIR}/opendmarc.dat ${WORK_DIR}/opendmarc_import.dat -f
cat /dev/null > ${WORK_DIR}/opendmarc.dat

/usr/sbin/opendmarc-import --dbhost=${DB_SERVER} --dbuser=${DB_USER} --dbpasswd=${DB_PASS} --dbname=${DB_NAME} --verbose < ${WORK_DIR}/opendmarc_import.dat
/usr/sbin/opendmarc-reports --dbhost=${DB_SERVER} --dbuser=${DB_USER} --dbpasswd=${DB_PASS} --dbname=${DB_NAME} --verbose --interval=86400 --report-email $REPORT_EMAIL --report-org $REPORT_ORG
/usr/sbin/opendmarc-expire --dbhost=${DB_SERVER} --dbuser=${DB_USER} --dbpasswd=${DB_PASS} --dbname=${DB_NAME} --verbose
```

Set execution permission:  
```bash
chmod +x /etc/opendmarc/report_script
```

Create a cron job and configure it as wished. Once a day at one is fine for me.  
`crontab -e`  
```
1 0 * * * opendmarc /etc/opendmarc/report_script
```

To make it possible to receive reports from other mailserver publish a DNS TXT entry which can look this way:  
```
_dmarc.example.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:abuse@example.com; ruf=mailto:abuse@example.com; fo=0; adkim=r; aspf=r; pct=100; rf=afrf; ri=86400"
```

### <a name="configure_dane"></a> Configure DANE
DANE (DNS-based Authentication of Named Entities) is a network protocol and is intended to secure the communication between client and server when using SSL/TLS. It requires that the domain registrar offers DNSSEC. Additionally a TLSA DNS entry has to be created which will be checked by postfix and if that matches the one of server to it connects or is connected from then we have a verified TLS connection.  

In postfix `/etc/postfix/main.cf` we just have to ensure a few settings:  
```
smtp_tls_security_level = dane
smtpd_use_tls = yes
smtp_use_tls = yes
smtp_dns_support_level = dnssec
smtp_tls_loglevel = 1`
```

Before activating and using this please read the articles about dane and tlsa. Letsencrypt enables everyone to use TLS for free. The certificates have to be renewed every 90 days though. There are ways though to use also those certificates with DANE.

### <a name="configure_srs"></a> Install and configure SRS
Sometimes mails should be forwarded to other mailservers or are being forwarded to us from other mailservers. SRS (Sender Rewriting Scheme) helps to recognize this and because of this still to use SPF and forward denies of mails to the real sender. [Here it is good described](http://www.openspf.org/SRS)

For postfix we have to install the software from github code:  
```
cd /tmp
curl -L -o postsrsd.zip https://github.com/roehling/postsrsd/archive/master.zip
unzip postsrsd.zip
cd postsrsd-master
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr ../
make
make install
```


Configure postfix to use it by adding configuration to `/etc/postfix/main.cf`  
```
sender_canonical_maps = tcp:127.0.0.1:10001
sender_canonical_classes = envelope_sender
recipient_canonical_maps = tcp:127.0.0.1:10002
recipient_canonical_classes = envelope_recipient,header_recipient
```

### <a name="configure_sieve"></a> Install and configure sieve
When offering mailing services to other users via a webmail interface e.g. AfterLogic Webmail lite it is good to enable the user to configure auto responder or forward mails. Sieve helps us here.

Install dovecot-sieve:  
```
aptitude install dovecot-sieve
```

Enable the mail plugins in dovecot config `/etc/dovecot/conf.d/15-lda.conf`  
```
mail_plugins = $mail_plugins sieve
```

Configure dovecot sieve directories and files in `/etc/dovecot/conf.d/90-sieve.conf`  
```
sieve_before = /var/vmail/sieve/spam-global.sieve
sieve_dir = /var/vmail/%d/%n/sieve/scripts/
sieve = /var/vmail/%d/%n/sieve/active-script.sieve
```

Create the directory for sieve files:  
```
mkdir -p /var/vmail/sieve
```

Create the global spam rule in the new file `/var/vmail/sieve/spam-global.sieve`. It moves spam flagged mails to the Junk mailbox.  
```
require "fileinto";
if header :comparator "i;ascii-casemap" :contains "X-Spam-Flag" "YES"  {
    fileinto "Junk";
    stop;
}
```

Apply owner and group membership on the new folder:  
```
chown -R vmail:mail /var/vmail/sieve
```

The last step now is to compile the sieve rule:  
```
sievec /var/vmail/sieve/spam-global.sieve
```

### <a name="restart_services"></a> Restart services
```
systemctl enable spamassassin
systemctl enable postsrsd
systemctl restart postsrsd
systemctl restart clamav-daemon
systemctl restart amavis
systemctl restart spamassassin
systemctl restart postgrey
systemctl restart postfix
systemctl restart dovecot
systemctl restart opendmarc
systemctl restart opendkim
```



___

## <a name="references"></a>References
Information about the general setup, much credit goes to the writer of that article  
- https://www.exratione.com/2016/05/a-mailserver-on-ubuntu-16-04-postfix-dovecot-mysql/

Information about dmarc spf dkim  
- https://www.skelleton.net/2015/03/21/how-to-eliminate-spam-and-protect-your-name-with-dmarc/

Information about amavis and spamassassin  
- https://thomas-leister.de/postfix-amavis-spamfilter-spamassassin-sieve/

Information about dkim  
- https://seasonofcode.com/posts/setting-up-dkim-and-srs-in-postfix.html

Information about sieve setup  
German  
- https://legacy.thomas-leister.de/dovecot-sieve-manager-installieren-und-einrichten/

Information regarding dane tlsa  
- https://dane.sys4.de/common_mistakes
- https://community.letsencrypt.org/t/please-avoid-3-0-1-and-3-0-2-dane-tlsa-records-with-le-certificates/7022/5
- http://www.internetsociety.org/deploy360/blog/2016/01/lets-encrypt-certificates-for-mail-servers-and-dane-part-1-of-2/
- https://www.internetsociety.org/deploy360/blog/2016/03/lets-encrypt-certificates-for-mail-servers-and-dane-part-2-of-2/

German  
- https://www.heinlein-support.de/sites/default/files/e-mail_made_in_germany_broken_by_design_ueberfluessig_dank_dane.pdf
- https://legacy.thomas-leister.de/dane-und-tlsa-dns-records-erklaert/
- https://legacy.thomas-leister.de/lets-encrypt-mit-hpkp-und-dane/
- https://www.kernel-error.de/projekte/postfix/postfix-dane-tlsa
