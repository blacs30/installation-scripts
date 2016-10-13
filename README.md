# installation-scripts
Scripts that simplify the installation

### minstall.sh
use this way: minstall.sh function

The file minstall.sh consists of multiple functions. 
This is a list of callable functions:
- base_server_setup_and_security
- disable_ipv6
- set_hostname
- ssh_server
- csf_config
- csf_add_syslogs
- csf_add_logfiles
- csf_add_pignore
- install_base_components
- install_mysql
- install_phpmyadmin
- install_webmail_lite
- install_wordpress
- install_owncloud
- install_nextcloud
- install_redis
- install_nginx
- install_php_fpm
- install_unbound
- install_bbs
- install_cops
- install_monit
- install_mailserver
- install_postfix_and_co
- install_postfixadmin
- install_php
- configure_mail_security
- configure_spf
- configure_dkim
- configure_dmarc
- configure_sieve
- configure_opensrsd
- configure_postfix
- configure_dovecot
- create_mysql_db
- create_dh_param
- create_snakeoil_certs
- create_nginx_vhost
- create_php_pool

### manage_certs.sh
use this way: manage_certs.sh function

The file minstall.sh consists of multiple functions. 
This is a list of callable functions:
- create_csr_config (needs CSR_REQUEST.conf parameter, will write this will)
- create_yearly_key (needs CSR_REQUEST.conf parameter, reads this file)
                    (calls create_request,create_cert,tlsa_record)
- create_request (needs CSR_REQUEST.conf parameter, reads this file)
              	 (calls create_cert,tlsa_record)
- create_cert
- tlsa_record (needs file chaingen.bash)
- copy_certs
- revoke_cert
- check_expiry
- read_config


# LICENSE

The MIT License (MIT)

Copyright (c) 2013-2016 Claas Lisowski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
