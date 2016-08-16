<?php
// Configuration options here override those in config.inc.php.
 
// You have to set $CONF['configured'] = true; before the
// application will run.
$CONF['configured'] = true;
 
// Postfix Admin Path
// Set the location of your Postfix Admin installation here.
// YOU MUST ENTER THE COMPLETE URL e.g. http://domain.tld/postfixadmin
$CONF['postfix_admin_url'] = 'https://mail.example.com/postfixadmin';
 
// Database connection details.
$CONF['database_type'] = 'mysqli';
$CONF['database_host'] = 'localhost';
$CONF['database_user'] = 'mail';
$CONF['database_password'] = 'mailpassword';
$CONF['database_name'] = 'mail';
 
// Site Admin
// Define the Site Admin's email address below.
// This will be used to send emails from to create mailboxes and
// from Send Email / Broadcast message pages.
// Leave blank to send email from the logged-in Admin's Email address.
$CONF['admin_email'] = 'admin@example.com';
 
// Mail Server
// Hostname (FQDN) of your mail server.
// This is used to send email to Postfix in order to create mailboxes.
$CONF['smtp_server'] = 'localhost';
$CONF['smtp_port'] = '25';
 
// Encrypt
// In what way do you want the passwords to be crypted?
// md5crypt = internal postfix admin md5
$CONF['encrypt'] = 'md5crypt';
 
// Default Aliases
// The default aliases that need to be created for all domains.
$CONF['default_aliases'] = array (
    'abuse' => 'admin@example.com',
    'hostmaster' => 'admin@example.com',
    'postmaster' => 'admin@example.com',
    'webmaster' => 'admin@example.com'
);
 
// Footer
// Below information will be on all pages.
// If you don't want the footer information to appear set this to 'NO'.
$CONF['show_footer_text'] = 'YES';
$CONF['footer_text'] = 'Return to mail.example.com';
$CONF['footer_link'] = 'https://mail.example.com';
 
// Mailboxes
// If you want to store the mailboxes per domain set this to 'YES'.
// Examples:
//   YES: /usr/local/virtual/domain.tld/username@domain.tld
//   NO:  /usr/local/virtual/username@domain.tld
$CONF['domain_path'] = 'NO';
// If you don't want to have the domain in your mailbox set this to 'NO'.
// Examples:
//   YES: /usr/local/virtual/domain.tld/username@domain.tld
//   NO:  /usr/local/virtual/domain.tld/username
// Note: If $CONF['domain_path'] is set to NO, this setting will be forced to YES.
$CONF['domain_in_mailbox'] = 'YES';
 
// Specify '' for Dovecot and 'INBOX.' for Courier.
$CONF['create_mailbox_subdirs_prefix']='';
