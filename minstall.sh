#!/bin/sh
# Multi Installation Script
# mailserver
# help for basic setup https://www.exratione.com/2016/05/a-mailserver-on-ubuntu-16-04-postfix-dovecot-mysql/
# help for spf dkim and dmarc setup https://www.skelleton.net/2015/03/21/how-to-eliminate-spam-and-protect-your-name-with-dmarc/
# help for amavis configuration https://thomas-leister.de/postfix-amavis-spamfilter-spamassassin-sieve/
# https://seasonofcode.com/posts/setting-up-dkim-and-srs-in-postfix.html
# dane help
# https://www.heinlein-support.de/sites/default/files/e-mail_made_in_germany_broken_by_design_ueberfluessig_dank_dane.pdf
# https://dane.sys4.de/common_mistakes
# https://community.letsencrypt.org/t/please-avoid-3-0-1-and-3-0-2-dane-tlsa-records-with-le-certificates/7022/5
# http://www.internetsociety.org/deploy360/blog/2016/01/lets-encrypt-certificates-for-mail-servers-and-dane-part-1-of-2/
# https://www.internetsociety.org/deploy360/blog/2016/03/lets-encrypt-certificates-for-mail-servers-and-dane-part-2-of-2/
# https://thomas-leister.de/dane-und-tlsa-dns-records-erklaert/
# https://thomas-leister.de/lets-encrypt-mit-hpkp-und-dane/
# https://www.kernel-error.de/postfix/postfix-dane-tlsa
# https://thomas-leister.de/dovecot-sieve-manager-installieren-und-einrichten/

# "run minstall.sh" to see the usage
Pause() {
  (tty_state=$(stty -g)
  stty -icanon
  LC_ALL=C dd bs=1 count=1 >/dev/null 2>&1
  stty "$tty_state"
  ) </dev/tty
}

set_vars() {
echo "
*********************************************
Setting variables
*********************************************"
WWWPATH=/var/www
WWWPATHHTML=$WWWPATH/$DOMAIN_APP_NAME/public_html
WWWLOGDIR=/var/www/log
CERTS_PATH=/var/www/ssl
SCRIPTS_DIR=/var/scripts
PERMISSIONFILES=/var/www/permissions
printf "
---------------------------------------
Adjust the WWWPATH and CERTS_PATH and comment out this line
Press any key to exit
---------------------------------------"
Pause

exit 1
}

check_installer() {
echo "
*********************************************
Checking the installer
*********************************************"
if [ "$INSTALLER_APP" = "aptitude" ];
then
if [ -z "$(which "$INSTALLER_APP")" ]; then
  echo "ERROR: $INSTALLER_APP not found"
  printf "Installing %s, press return to continue. \n" "$INSTALLER_APP"
  Pause
  apt-get update
  apt-get install -y aptitude
else
  echo "Using $INSTALLER_APP";
fi
if [ ! -z "$(which "$INSTALLER_APP")" ]; then
  echo "Found $INSTALLER_APP"
else
  printf "ERROR: %s still not found, exit! \n" "$INSTALLER_APP"
  Pause
  exit 1
fi
elif [ "$INSTALLER_APP" = "apt-get" ];
then
if [ ! -z "$(which "$INSTALLER_APP")" ]; then
  echo "Using $INSTALLER_APP"
else
  ( prinft "ERROR: %s not found, exit! \n" "$INSTALLER_APP" && Pause && exit 1 );
fi
fi

while true; do
  echo "
  ------------------------------
  Do you want to update the REPO of the installer now?
  ------------------------------ [Y/n]"
  read -r yn
    case $yn in
        [Yy]* ) echo "Updating $INSTALLER_APP repos"; $INSTALLER_APP update; break;;
        [Nn]* ) echo "Skipping update of $INSTALLER_APP"; break;;
        * ) echo "Please answer y or n.";;
    esac
done
}

set_installer() {
echo "
*********************************************
Setting the installer
*********************************************"

while true; do
  echo "
  ---------------------------------------
  Do you want to use 'apt-get' or 'aptitude' as installer (e.g.: aptitude)
  ---------------------------------------"
  read -r answer
    case $answer in
        aptitude) INSTALLER_APP=aptitude; check_installer; break;;
        apt-get) INSTALLER_APP=apt-get; check_installer; break;;
        * ) echo "ERROR: Invalid option!";;
    esac
done

}

check_if_root() {
echo "
*********************************************
Checking if you are root
*********************************************"
if [ "$(whoami)" != "root" ];
then
echo "
------------------------------
Sorry, you are not root.
You must be root to execute this function'
------------------------------"
exit 1
fi
}

base_server_setup_and_security() {
echo "
*********************************************
Running Server Base Setup and Security
*********************************************"
install_base_components

echo "
------------------------------
Setup timezone information
------------------------------"
dpkg-reconfigure tzdata

echo "
------------------------------
enable Spoof protection
------------------------------"
sed -i -r -e "s/.*net.ipv4.conf.all.rp_filter=.*/net.ipv4.conf.all.rp_filter=1/g" /etc/sysctl.conf
if grep -Fq '1' /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts; then
echo "/proc/sys/net/ipv4/icmp_echo_ignore_broadcasts activated already"
else
echo "0" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
fi

echo "
------------------------------
Install apticron
------------------------------"
$INSTALLER_APP install -y apticron
echo "
------------------------------
Enter update notification mail address
------------------------------"
mail=
printf "e.g. admin@example.com \n"
read -r mail
sed -i -r -e "s/^EMAIL=.*/EMAIL=\"$mail\"/g" /etc/apticron/apticron.conf

echo "
------------------------------
Install CSF firewall
------------------------------"
echo  "
------------------------------
- Install required perl modules
------------------------------"
$INSTALLER_APP install -y libwww-perl

cd /tmp || echo 'Could not change directory to /tmp' #This should not happen as /tmp is a normally existend
if ! wget --no-check-certificate https://download.configserver.com/csf.tgz; then echo 'ERROR downloading csf from the internet';fi
if  ! tar -xzf csf.tgz; then echo 'ERROR extracting csf.tgz';fi

echo "
------------------------------
- disable ufw in case it's enabled
------------------------------"
ufw disable

echo "
------------------------------
- run csf/install.sh
------------------------------"
cd csf || echo 'Could not change directory to /tmp/csf' #This should not happen as we've just downloaded and extracted csf
sh install.sh

echo "
------------------------------
Run csf_config
------------------------------"
csf_config

echo "
------------------------------
Apply changes and restart CSF
------------------------------"
csf -r

echo "
------------------------------
If applicable add nfs share to /etc/fstab ro or rw
------------------------------"
}

disable_ipv6() {
echo "
*********************************************
Disabling IPV6
*********************************************"
# Disable IPv6
echo "
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.eth0.disable_ipv6 = 1
" >> /etc/sysctl.conf

sysctl -p
}

set_hostname() {
echo "
*********************************************
Setting the hostname
*********************************************"
host_name=$(cat /etc/hostname)
echo "
------------------------------
Please enter the hostname, it can be a new one.
Hostname now: $host_name
------------------------------"
read -r host_name
echo "$host_name" > /etc/hostname
bash /etc/init.d/hostname.sh

echo "$host_name" > /etc/mailname

sed -i -e 's/127.0.0.1.*/# &/' -e "/^# 127.0.0.1.*/ a 127.0.0.1 $host_name" /etc/hosts
}

ssh_server() {
echo "
*********************************************
Installing SSH Server
*********************************************"
set_hostname

echo "
------------------------------
Enter an administrative user to use for ssh - instead of root - and press RETURN
------------------------------"
adminuser=
read -r adminuser
adduser "$adminuser"

$INSTALLER_APP install -y openssh-server

SSHD_CONFIG=/etc/ssh/sshd_config
sed -i -r -e "s/^PermitRootLogin.*/PermitRootLogin no/g" $SSHD_CONFIG
sed -i -r -e "s/^X11Forwarding.*/X11Forwarding no/g" $SSHD_CONFIG

if grep -Fq '.*AllowUsers.*' $SSHD_CONFIG; then
grep '.*AllowUsers.* ' $SSHD_CONFIG
else
echo "AllowUsers $adminuser" >> $SSHD_CONFIG
fi

service ssh restart

echo "
------------------------------
Run the next command on your local computer to create ssh keys
The goal is to use ssh keys to login and no passwords
ssh-keygen
This commands copies your local public key to your (this) server.
ssh-copy-id -i ~/.ssh/id_rsa.pub remote-host
adjust the /etc/ssh/sshd_config to disable password login
------------------------------"
}

csf_config() {
echo "
*********************************************
CSF - Setting config
*********************************************"
CSF_CONFIG_FILE=/etc/csf/csf.conf
if [ ! -f $CSF_CONFIG_FILE ]; then
        printf "Where is your csf configuration location? Please enter the full path: e.g. /etc/csf/csf.conf \n"
        read -r CSF_CONFIG_FILE
fi
echo "
------------------------------
- Check the result of the next command (perl /usr/local/csf/bin/csftest.pl)
install missing perl modules to use all functions.
------------------------------"
perl /usr/local/csf/bin/csftest.pl

echo "
------------------------------
Enter all IP addresses, space separated, which should be added to csf.allow file
------------------------------"
ip=
read -r ip
for i in $ip
do
csf -a "$i"
done

sed -i -r -e 's/^RESTRICT_SYSLOG[ |=].*/# &/' -e '/^# RESTRICT_SYSLOG[ |=].*/ a RESTRICT_SYSLOG = "3"' "$CSF_CONFIG_FILE"

sed -i -r -e 's/^RESTRICT_UI[ |=].*/# &/' -e '/^# RESTRICT_UI[ |=].*/ a RESTRICT_UI = "2"' "$CSF_CONFIG_FILE"

sed -i -r -e 's/^SMTP_BLOCK[ |=].*/# &/' -e '/^# SMTP_BLOCK[ |=].*/ a SMTP_BLOCK = "1"' "$CSF_CONFIG_FILE"

sed -i -r -e 's/^AT_ALERT[ |=].*/# &/' -e '/^# AT_ALERT[ |=].*/ a AT_ALERT = "1"' "$CSF_CONFIG_FILE"

echo "
------------------------------
Enter all TCP_IN ports, comma separated without spaces, colon for range is possible
e.g. 25,53,80,110,143,443,465,587,993,995,24441,24500:26000
------------------------------"
TCP_IN=
read -r TCP_IN
sed -i -r -e "s/^TCP_IN.*/# &/" -e "/^# TCP_IN.*/ a TCP_IN = \"$TCP_IN\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Enter all TCP_OUT ports, comma separated without spaces, colon for range is possible
e.g. 25,53,80,110,113,443,587,993,995,2703,24500:26000
------------------------------"
TCP_OUT=
read -r TCP_OUT
sed -i -r -e "s/^TCP_OUT =.*/# &/" -e "/^# TCP_OUT =.*/ a TCP_OUT = \"$TCP_OUT\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Enter all UDP_IN ports, comma separated without spaces, colon for range is possible
e.g. 53,24500:26000
------------------------------"
UDP_IN=
read -r UDP_IN
sed -i -r -e "s/^UDP_IN =.*/# &/" -e "/^# UDP_IN =.*/ a UDP_IN = \"$UDP_IN\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Enter all UDP_OUT ports, comma separated without spaces, colon for range is possible
e.g. 53,113,123,24441,24500:26000
------------------------------"
UDP_OUT=
read -r UDP_OUT
sed -i -r -e "s/^UDP_OUT.*/# &/" -e "/^# UDP_OUT.*/ a UDP_OUT = \"$UDP_OUT\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Disable IPv6
------------------------------"
sed -i -r "s/^IPV6[ |=].*/IPV6 = \"0\"/g" "$CSF_CONFIG_FILE"

echo "
------------------------------
Check if SYSLOG is running - Enter the value in seconds (0 to disable)
------------------------------"
SYSLOG_CHECK=
read -r SYSLOG_CHECK
sed -i -r -e "s/^SYSLOG_CHECK =.*/# &/" -e "/^# SYSLOG_CHECK =.*/ a SYSLOG_CHECK = \"$SYSLOG_CHECK\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Limit the number of IP's kept in the /etc/csf/csf.deny file - enter a value (e.g. 200)
------------------------------"
DENY_IP_LIMIT=
read -r DENY_IP_LIMIT
sed -i -r -e "s/^DENY_IP_LIMIT.*/# &/" -e "/^# DENY_IP_LIMIT.*/ a DENY_IP_LIMIT = \"$DENY_IP_LIMIT\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Limit the number of IP's kept in the temprary IP ban list. - Enter a value (e.g. 100)
------------------------------"
DENY_TEMP_IP_LIMIT=
read -r DENY_TEMP_IP_LIMIT
sed -i -r -e "s/^DENY_TEMP_IP_LIMIT.*/# &/" -e "/^# DENY_TEMP_IP_LIMIT.*/ a DENY_TEMP_IP_LIMIT = \"$DENY_TEMP_IP_LIMIT\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Enter LF Alert mail address - Leave empty if mailaddress in template should be used.
------------------------------"
LF_ALERT_TO=
read -r LF_ALERT_TO
sed -i -r -e "s/^LF_ALERT_TO.*/# &/" -e "/^# LF_ALERT_TO.*/ a LF_ALERT_TO = \"$LF_ALERT_TO\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Country allow access to specific ports, enter country codes, comma separated (e.g. CH,DE,PL)
Leave empty if you don't want to use this function.
------------------------------"
CC_ALLOW_PORTS=
read -r CC_ALLOW_PORTS
sed -i -r -e "s/^CC_ALLOW_PORTS[ |=].*/# &/" -e "/^# CC_ALLOW_PORTS[ |=].*/ a CC_ALLOW_PORTS = \"$CC_ALLOW_PORTS\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Specify TCP ports to allow for entered countries, comma separated (e.g. 21,22)
Leave empty if you don't want to use this function.
------------------------------"
CC_ALLOW_PORTS_TCP=
read -r CC_ALLOW_PORTS_TCP
sed -i -r -e "s/^CC_ALLOW_PORTS_TCP.*/# &/" -e "/^# CC_ALLOW_PORTS_TCP.*/ a CC_ALLOW_PORTS_TCP = \"$CC_ALLOW_PORTS_TCP\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Specify UDP ports to allow for entered countries, comma separated (e.g. 53)
Leave empty if you don't want to use this function.
------------------------------"
CC_ALLOW_PORTS_UDP=
read -r CC_ALLOW_PORTS_UDP
sed -i -r -e "s/^CC_ALLOW_PORTS_UDP.*/# &/" -e "/^# CC_ALLOW_PORTS_UDP.*/ a CC_ALLOW_PORTS_UDP = \"$CC_ALLOW_PORTS_UDP\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Country deny access to specific ports, enter country codes, comma separated
(e.g.: AE,AF,AL,AM,AZ,BA,BD,BG,BY,CD,CF,CN,GR,HK,IL,IQ,IR,JO,KE,KG,KR,KZ,LB,LY,MA,MD,ME,MN,OM,PK,RU,SA,SD,SN,SY,TJ,TM,TN,TW,UA,UZ,VN)
Make empty if you don't want to use this function.
------------------------------"
CC_DENY_PORTS=
read -r CC_DENY_PORTS
sed -i -r -e "s/^CC_DENY_PORTS =.*/# &/" -e "/^# CC_DENY_PORTS =.*/ a CC_DENY_PORTS = \"$CC_DENY_PORTS\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Specify TCP ports to deny for entered countries, comma separated (e.g.: 25,110,143,465,587,993,995)
Make empty if you don't want to use this function.
------------------------------"
CC_DENY_PORTS_TCP=
read -r CC_DENY_PORTS_TCP
sed -i -r -e "s/^CC_DENY_PORTS_TCP.*/# &/" -e "/^# CC_DENY_PORTS_TCP.*/ a CC_DENY_PORTS_TCP = \"$CC_DENY_PORTS_TCP\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Specify UDP ports to deny for entered countries, comma separated (e.g.: 113,123)
Make empty if you don't want to use this function.
------------------------------"
CC_DENY_PORTS_UDP=
read -r CC_DENY_PORTS_UDP
sed -i -r -e "s/^CC_DENY_PORTS_UDP.*/# &/" -e "/^# CC_DENY_PORTS_UDP.*/ a CC_DENY_PORTS_UDP = \"$CC_DENY_PORTS_UDP\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Set LF_TRIGGER on (1) or off (0) (e.g.: 0)
------------------------------"
LF_TRIGGER=
read -r LF_TRIGGER
sed -i -r -e "s/^LF_TRIGGER =.*/# &/" -e "/^# LF_TRIGGER =.*/ a LF_TRIGGER = \"$LF_TRIGGER\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Enable login failure detection of pop3 connections - enter number of failed logins to block  (e.g.: 0)
------------------------------"
LF_POP3D=
read -r LF_POP3D
sed -i -r -e "s/^LF_POP3D[ |=].*/# &/" -e "/^# LF_POP3D[ |=].*/ a LF_POP3D = \"$LF_POP3D\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Enable login failure detection of imap connections - enter number of failed logins to block  (e.g.: 0)
------------------------------"
LF_IMAPD=
read -r LF_IMAPD
sed -i -r -e "s/^LF_IMAPD =.*/# &/" -e "/^# LF_IMAPD =.*/ a LF_IMAPD = \"$LF_IMAPD\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Block IMAP logins if greater than LT_IMAPD times per hour per account per IP - enter value (e.g.: 0)
------------------------------"
LT_IMAPD=
read -r LT_IMAPD
sed -i -r -e "s/^LT_IMAPD =.*/# &/" -e "/^# LT_IMAPD =.*/ a LT_IMAPD = \"$LT_IMAPD\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Port Scan Tracking. This feature tracks port blocks logged by iptables to
syslog. If an IP address generates a port block that is logged more than
PS_LIMIT (10) within PS_INTERVAL seconds, the IP address will be blocked. - enter value in seconds (recommended 60-300, e.g.: 0)
------------------------------"
PS_INTERVAL=
read -r PS_INTERVAL
sed -i -r -e "s/^PS_INTERVAL.*/# &/" -e "/^# PS_INTERVAL.*/ a PS_INTERVAL = \"$PS_INTERVAL\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
User ID Tracking. This feature tracks UID blocks logged by iptables to
syslog. If a UID generates a port block that is logged more than UID_LIMIT
times within UID_INTERVAL seconds, an alert will be sent. - enter value in seconds, (recommended 120, e.g.: 0)
------------------------------"
UID_INTERVAL=
read -r UID_INTERVAL
sed -i -r -e "s/^UID_INTERVAL.*/# &/" -e "/^# UID_INTERVAL.*/ a UID_INTERVAL = \"$UID_INTERVAL\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Do you want to enable port knocking, e.g. for SSH access - yes(1)/no(0): (e.g.: 1)
------------------------------"
PORTKNOCKING_ALERT=
read -r PORTKNOCKING_ALERT
if [ -z "$PORTKNOCKING_ALERT" ] || [ "$PORTKNOCKING_ALERT" -eq "1" ];
then
PORTKNOCKING_ALERT=1;
sed -i -r -e "s/^PORTKNOCKING_ALERT.*/# &/" -e "/^# PORTKNOCKING_ALERT.*/ a PORTKNOCKING_ALERT = \"$PORTKNOCKING_ALERT\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Enter following information as in the example:
openport;protocol;timeout;kport1;kport2;kport3[...;kportN],...
e.g.: 22;TCP;20;100;200;300;400
------------------------------"
PORTKNOCKING=
read -r PORTKNOCKING
sed -i -r -e "s/^PORTKNOCKING[ |=].*/# &/" -e "/^# PORTKNOCKING[ |=].*/ a PORTKNOCKING = \"$PORTKNOCKING\"" "$CSF_CONFIG_FILE"
fi

echo "
------------------------------
Do you want to enable the logscanner, it will send regularly log reports- yes(1)/no(0): (e.g.: 1)
------------------------------"
LOGSCANNER=
read -r LOGSCANNER
if [ -z "$LOGSCANNER" ] || [ "$LOGSCANNER" -eq "1" ];
then
LOGSCANNER=1;
sed -i -r -e "s/^LOGSCANNER[ |=].*/# &/" -e "/^# LOGSCANNER[ |=].*/ a LOGSCANNER = \"$LOGSCANNER\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
The interval can be set to:
hourly - sent on the hour
daily  - sent at midnight (00:00)
manual - sent whenever 'csf --logrun' is run. This allows for scheduling
via cron job
(e.g.: manual)
------------------------------"
LOGSCANNER_INTERVAL=
read -r LOGSCANNER_INTERVAL
sed -i -r -e "s/^LOGSCANNER_INTERVAL.*/# &/" -e "/^# LOGSCANNER_INTERVAL.*/ a LOGSCANNER_INTERVAL = \"$LOGSCANNER_INTERVAL\"" "$CSF_CONFIG_FILE"
if [ "$LOGSCANNER_INTERVAL" = "manual" ];
then
  while true; do
    echo "
    ------------------------------
    Do you want to set the cron job now?
    ------------------------------ [Y/n]"
    read -r yn
      case $yn in
          [Yy]* )
          echo "
          ------------------------------
          To what times do you want to run the LOGSCANNER cron job? (e.g. midnight: 0 0 * * *)
          ------------------------------"
          read -r cronvar
          if (crontab -l 2>/dev/null; echo "$cronvar $(which csf) --logrun") | crontab -; then
          echo "crontab created: $cronvar $(which csf) --logrun"
          fi
          break;;
          [Nn]* ) echo "Set a cron job later for '$(which csf) --logrun'"; break;;
          * ) echo "Please answer y or n.";;
      esac
  done
fi

echo "
------------------------------
Set the maximum number of lines in the report before it is truncated
1000-100000 (e.g.: 5000)
------------------------------"
LOGSCANNER_LINES=
read -r LOGSCANNER_LINES
sed -i -r -e "s/^LOGSCANNER_LINES.*/# &/" -e "/^# LOGSCANNER_LINES.*/ a LOGSCANNER_LINES = \"$LOGSCANNER_LINES\"" "$CSF_CONFIG_FILE"

echo "
------------------------------
Check the file /etc/csf/csf.logfiles and add all log files which should be included for the LOGSCANNER report function.
------------------------------"
fi

echo "
------------------------------
Check the file /etc/csf/csf.syslogs and add all log files which should be searched too.
------------------------------"

echo "
------------------------------
CSF Firewall testing enabled, change to 0 to disable testing if CSF works well
------------------------------"
sed -i -r -e "s/^TESTING[ |=].*/TESTING = \"1\"/g" "$CSF_CONFIG_FILE"

}

csf_add_syslogs() {
echo "
*********************************************
CSF - Adding syslogs files
*********************************************"
csf_syslogs=
if [ -z "$1" ]
then
echo "
------------------------------
Usage:
csf_add_syslogs /path/to/file.log
csf_add_syslogs \"/var/log with space/file.err\"
------------------------------"
else
csf_syslogs=$1
if [ -f /etc/csf/csf.syslogs ];
then
echo "$csf_syslogs" >> /etc/csf/csf.syslogs
echo "
------------------------------
Added $csf_syslogs to csf.pignore, please restart csf and lfd
e.g. csf -x && csf -e or csf -r
------------------------------"
else
echo "File /etc/csf/csf.syslogs does not exist"
fi
fi
}

csf_add_logfiles() {
echo "
*********************************************
CSF - Adding logfiles to LOGSCANNER
*********************************************"
csf_logfiles=
if [ -z "$1" ]
then
echo "
------------------------------
Usage:
csf_add_logfiles /path/to/file.log
csf_add_logfiles \"/var/log with space/file.err\"
------------------------------"
else
csf_logfiles=$1
if [ -f /etc/csf/csf.logfiles ];
then
echo "$csf_logfiles" >> /etc/csf/csf.logfiles
echo "
------------------------------
Added $csf_logfiles to csf.pignore, please restart csf and lfd
e.g. csf -x && csf -e or csf -r
------------------------------"
else
echo "File /etc/csf/csf.logfiles does not exist"
fi
fi
}

csf_add_pignore() {
echo "
*********************************************
CSF - Adding pignore entries
*********************************************"
pcmd_cmd_exe=
if [ -z "$1" ]
then
echo "
------------------------------
Usage:
csf_add_pignore exe:/path/to/executable
csf_add_pignore (p)cmd:/usr/sbin/amavisd-new.*
csf_add_pignore \"pcmd:php /var/space in path/cron.php\"
------------------------------"
else
if [ -f /etc/csf/csf.pignore ];
then
pcmd_cmd_exe=$1
echo "$pcmd_cmd_exe" >> /etc/csf/csf.pignore
echo "
------------------------------
Added $pcmd_cmd_exe to csf.pignore, please restart csf and lfd
e.g. csf -x && csf -e or csf -r
------------------------------"
else
echo "File /etc/csf/csf.pignore does not exist"
fi
fi
}

install_base_components() {
echo "
*********************************************
Installing Base Components
*********************************************"
install_components 'wget unzip rsync vim bzip2 cron rsyslog curl ed'
start_service 'rsyslog cron'
}

install_components() {
update=false
components=$1
echo "
------------------------------
Installing following components:
$components

Press return to continue.
------------------------------"
Pause
if [ ! "$(grep -Fc 'deb http://mirrors.linode.com/debian/ jessie-updates main contrib non-free' /etc/apt/sources.list)" -ge "1" ];
then echo "deb http://mirrors.linode.com/debian/ jessie-updates main contrib non-free" >> /etc/apt/sources.list; update=true; fi
if [ ! "$(grep -Fc 'deb-src http://mirrors.linode.com/debian/ jessie-updates main contrib non-free' /etc/apt/sources.list)" -ge "1" ];
then echo "deb-src http://mirrors.linode.com/debian/ jessie-updates main contrib non-free" >> /etc/apt/sources.list; update=true; fi
if [ ! "$(grep -Fc 'deb http://security.debian.org/ jessie/updates main contrib non-free' /etc/apt/sources.list)" -ge "1" ];
then echo "deb http://security.debian.org/ jessie/updates main contrib non-free" >> /etc/apt/sources.list; update=true; fi
if [ ! "$(grep -Fc 'deb-src http://security.debian.org/ jessie/updates main non-free' /etc/apt/sources.list)" -ge "1" ];
then echo "deb-src http://security.debian.org/ jessie/updates main non-free" >> /etc/apt/sources.list; update=true; fi
if [ ! "$(grep -Fc 'deb http://mirrors.linode.com/debian/ jessie main contrib non-free' /etc/apt/sources.list)" -ge "1" ];
then echo "deb http://mirrors.linode.com/debian/ jessie main contrib non-free" >> /etc/apt/sources.list; update=true; fi
if [ ! "$(grep -Fc 'deb-src http://mirrors.linode.com/debian/ jessie main contrib non-free' /etc/apt/sources.list)" -ge "1" ];
then echo "deb-src http://mirrors.linode.com/debian/ jessie main contrib non-free" >> /etc/apt/sources.list; update=true; fi
if [ ! -z "$(which wget)" ]; then
if [ ! "$(grep -Fc 'deb http://packages.dotdeb.org jessie all' /etc/apt/sources.list)" -ge "1" ];
then echo "deb http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list; update=true; fi
if [ ! "$(grep -Fc 'deb-src http://packages.dotdeb.org jessie all' /etc/apt/sources.list)" -ge "1" ];
then echo "deb-src http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list; update=true; fi
$update && wget http://www.dotdeb.org/dotdeb.gpg && apt-key add dotdeb.gpg && rm -f dotdeb.gpg
fi
$update && echo "Updating $INSTALLER_APP repos" && $INSTALLER_APP update
$INSTALLER_APP install -y $components
}

install_mysql() {
echo "
*********************************************
Installing MYSQL and securing it
*********************************************"
i=1
pass=1
while [ $pass != "0" ]
do
MYSQL_ROOT_PASS=
if [ $i = "1" ]; then
echo "
------------------------------
Please enter the mysql root password you want to use
------------------------------"
else
echo "
------------------------------
ERRPR:
The password was wrong.
Please enter the correct mysql root password.
------------------------------"
fi
i=$((i+1))
stty -echo
read -r MYSQL_ROOT_PASS
stty echo
printf "\n"
if [ ! -z "$(which mysql)" ]; then
if [ ! -z "$MYSQL_ROOT_PASS" ] && ( echo exit | mysql -uroot -p"$MYSQL_ROOT_PASS" >/dev/null 2>&1 ); then pass=0; fi
else
pass=0
fi
done

command -v mysql >/dev/null 2>&1 || { echo >&2

install_components "debconf-utils expect"
echo mysql-server mysql-server/root_password password "$MYSQL_ROOT_PASS" | debconf-set-selections
echo mysql-server mysql-server/root_password_again password "$MYSQL_ROOT_PASS" | debconf-set-selections

install_components mysql-server

start_service mysql

echo "Run expect for mysql_secure_installation"
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root:\"
send \"$MYSQL_ROOT_PASS\r\"
expect \"Would you like to setup VALIDATE PASSWORD plugin?\"
send \"n\r\"
expect \"Change the password for root ?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
export SECURE_MYSQL
echo "$SECURE_MYSQL"
unset SECURE_MYSQL

echo "Remove expect and config files"
$INSTALLER_APP -y purge expect

start_service mysql
}

if ! grep -Fq "sql_mode" /etc/mysql/my.cnf; then
    echo "sql_mode=ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION" >> /etc/mysql/my.cnf
fi
}

install_phpmyadmin() {
echo "
*********************************************
Installing phpMyAdmin
*********************************************"
SOFTWARE_URL=https://files.phpmyadmin.net/phpMyAdmin/4.6.4/phpMyAdmin-4.6.4-all-languages.zip
SOFTWARE_ZIP=$(basename $SOFTWARE_URL)
SOFTWARE_DIR=$(printf '%s' "$SOFTWARE_ZIP" | sed -e 's/.zip//')

install_base_components

install_components "php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-mcrypt php7.0-gd php7.0-json php7.0-mysql php7.0-opcache php7.0-readline php7.0-mbstring"

create_base_dirs

DOMAIN_APP_NAME=mysql.example.com
echo "
------------------------------
Enter a name for installation.
It can contain the domain/subdomain name.
You can add phpMyAdmin to an existing installation/domain.
The base installation directory would be then e.g. $WWWPATH/$DOMAIN_APP_NAME

e.g.: $DOMAIN_APP_NAME
------------------------------"
read -r DOMAIN_APP_NAME

# reload variables to set the $DOMAIN_APP_NAME in $WWWPATHHTML
set_vars

echo "
------------------------------
Enter the full path for the installation directory,
The default is '$WWWPATH' followed by the entered name $DOMAIN_APP_NAME,
Per default a 'public_html' directory will be created for the application.

The default path would be then e.g.: $WWWPATHHTML
------------------------------"
read -r WWWPATHHTML

if [ ! -d "$WWWPATHHTML" ]; then
  mkdir -p "$WWWPATHHTML"
fi

install_mysql

install_nginx

install_php_fpm

create_snakeoil_certs

create_dh_param

create_service_user phpmyadmin

create_php_pool

create_nginx_vhost phpmyadmin

echo "Copy application files"
wget $SOFTWARE_URL -O /tmp/"$SOFTWARE_ZIP"
unzip /tmp/"$SOFTWARE_ZIP"
mkdir -p "$WWWPATHHTML"/phpmyadmin
cp -rT "$SOFTWARE_DIR" "$WWWPATHHTML"/phpmyadmin
if [ -d /tmp/"$SOFTWARE_DIR" ]; then
  rm -rf /tmp/"$SOFTWARE_DIR"
fi
if [ -f "$SOFTWARE_ZIP" ]; then
  rm -f "$SOFTWARE_ZIP"
fi

PHPMYADMIN_CONF=$WWWPATHHTML/phpmyadmin/config.inc.php
cp "$WWWPATHHTML"/phpmyadmin/config.sample.inc.php "$PHPMYADMIN_CONF"

BLOWFISH_PASS=$(< /dev/urandom tr -dc "a-zA-Z0-9@#*=" | fold -w "$SHUF" | head -n 1)
sed -i "s/.*'blowfish_secret'.*/\$cfg['blowfish_secret'] = '$BLOWFISH_PASS';/g" "$PHPMYADMIN_CONF"
sed -i "s/localhost/127.0.0.1/g" "$PHPMYADMIN_CONF"
sed -i "/AllowNoPassword/a \$cfg['ForceSSL'] = 'true';" "$PHPMYADMIN_CONF"

echo "Set permissions to files and directories"
chown -R "$service_user":www-data "$WWWPATHHTML"/
find "$WWWPATHHTML" -type d -exec chmod 750 {} \;
find "$WWWPATHHTML" -type f -exec chmod 640 {} \;

start_service "nginx php7.0-fpm mysql"

if [ ! -d $SCRIPTS_DIR ]; then
  mkdir -p $SCRIPTS_DIR
fi
echo "Write root password into file $SCRIPTS_DIR/$DOMAIN_APP_NAME-pass.txt, delete it soon!"
echo "MYSQL ROOT Password is $MYSQL_ROOT_PASS" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
chmod 600 $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt

echo "Installation succeded...
Press ENTER to finish"
Pause
}

create_mysql_db() {
MYSQL_DB_NAME=
MYSQL_DB_USER=

while true; do
  echo "
  ------------------------------
  MYSQL Database:
  do you want to create a new database -
  or connect to an existing one? [new/existing]
  ------------------------------"
  read -r answer
    case $answer in
        new) new_db=true; break;;
        existing) new_db=false; break;;
        * ) echo "ERROR: Invalid option!";;
    esac
done

if [ $new_db = true ]; then
echo "
*************************************
Creating a new mysql database
*************************************"
conn=false
init=true
while [ $conn != true ]
do
if [ $init = false ]; then
echo "
------------------------------
ERROR:
There was an error testing the connection.
Please check the entered data:
------------------------------"
fi

if [ -z "$MYSQL_HOST" ]; then
  MYSQL_HOST=127.0.0.1
fi
echo "
------------------------------
Enter the hostname for the mysql server:

e.g. $MYSQL_HOST
------------------------------"
read -r MYSQL_HOST

MYSQL_ROOT_PASS=
echo "
------------------------------
Enter the root password for the mysql database:
------------------------------"
stty -echo
read -r MYSQL_ROOT_PASS
stty echo
printf "\n"

if echo exit | mysql -uroot -p"$MYSQL_ROOT_PASS" >/dev/null 2>&1; then
  conn=true
else
  init=false
fi
done

conn=false
init=true
while [ $conn != true ]
do
if [ $init = false ]; then
echo "
------------------------------
ERROR: Cannot create the database as it already exists.
Please enter a database which does not exists yet.
------------------------------"
fi

request_mysql_user_credentials "$1"

if [ "$(echo "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$MYSQL_DB_NAME' ;" | \
mysql -uroot -p"$MYSQL_ROOT_PASS" -h"$MYSQL_HOST" | grep -c SCHEMA_NAME)" -gt "0" ];
then
init=false
else
conn=true
fi
done

echo "
------------------------------
Creating database now.
------------------------------"
echo "CREATE DATABASE IF NOT EXISTS $MYSQL_DB_NAME;
GRANT ALL PRIVILEGES ON $MYSQL_DB_NAME.* TO '$MYSQL_DB_USER'@'127.0.0.1' IDENTIFIED BY '$MYSQL_DB_PASSWORD';
quit" >> /tmp/createdb.sql
if mysql -u root -p"$MYSQL_ROOT_PASS" -h"$MYSQL_HOST" < /tmp/createdb.sql; then
  echo "Created database $MYSQL_DB_NAME successfully "
fi
rm -f /tmp/createdb.sql

else
echo "
*************************************
Connecting to existing mysql database
*************************************"

if [ -z "$MYSQL_HOST" ]; then
  MYSQL_HOST=127.0.0.1
fi
echo "
------------------------------
Enter the hostname for the mysql server:

e.g. $MYSQL_HOST
------------------------------"
read -r MYSQL_HOST

conn=false
init=true
while [ $conn != true ]
do
if [ $init = false ];
then
echo "
------------------------------
ERROR: Cannot connect to the database.
Please enter the correct credentials for the database
you want to use.
------------------------------"
fi

request_mysql_user_credentials "$1"

if echo exit | mysql -u$MYSQL_DB_USER -p"$MYSQL_DB_PASSWORD" -h"$MYSQL_HOST" >/dev/null 2>&1; then
  echo "Connected successfully to database $MYSQL_DB_NAME."
  conn=true
else
  init=false
fi
done

fi

export MYSQL_DB_NAME
export MYSQL_DB_USER
export MYSQL_DB_PASSWORD
export MYSQL_HOST
}

request_mysql_user_credentials() {
if [ ! -z "$1" ]; then
  MYSQL_DB_NAME=$1
else
  MYSQL_DB_NAME=$MYSQL_DB_NAME
fi
echo "
------------------------------
Enter a database name for the mysql database

e.g. $MYSQL_DB_NAME
------------------------------"
read -r MYSQL_DB_NAME

if [ ! -z $MYSQL_DB_USER ]; then
  MYSQL_DB_USER=$MYSQL_DB_USER
else
  MYSQL_DB_USER=$MYSQL_DB_NAME
fi

echo "
------------------------------
Enter the username for the mysql database $MYSQL_DB_NAME.

e.g. $MYSQL_DB_USER
------------------------------"
read -r MYSQL_DB_USER

MYSQL_DB_PASSWORD=
echo "
------------------------------
Enter the password for the mysql database  $MYSQL_DB_NAME for user $MYSQL_DB_USER.
------------------------------"
stty -echo
read -r MYSQL_DB_PASSWORD
stty echo
printf "\n"
}

install_webmail_lite() {
echo "
*********************************************
Installing Webmail Lite
*********************************************"
AL_WEBMAIL_URL=http://www.afterlogic.org/download/webmail_php.zip
AL_WEBMAIL_ZIP=webmail_php.zip
install_base_components

install_components "software-properties-common php7.0 php7.0-mcrypt php7.0-curl php7.0-gd php7.0-mbstring php-xml-parser php7.0-common php7.0-cli php7.0-json	php7.0-readline	php7.0-mysql"

create_base_dirs

DOMAIN_APP_NAME=webmail.example.com
echo "
------------------------------
Enter a name for installation.
It can contain the domain/subdomain name.
The base installation directory would be then e.g. $WWWPATH/$DOMAIN_APP_NAME

e.g: $DOMAIN_APP_NAME
------------------------------"
read -r DOMAIN_APP_NAME

# reload variables to set the $DOMAIN_APP_NAME in $WWWPATHHTML
set_vars

echo "
------------------------------
Enter the full path for the installation directory,
The default is '$WWWPATH' followed by the entered name $DOMAIN_APP_NAME,
Per default a 'public_html' directory will be created for the application.

The default path would be then e.g.: $WWWPATHHTML
------------------------------"
read -r WWWPATHHTML

if [ ! -d "$WWWPATHHTML" ]; then
  mkdir -p "$WWWPATHHTML"
fi

create_service_user webmail

install_mysql

install_nginx

install_php_fpm

create_snakeoil_certs

create_dh_param

create_php_pool

create_nginx_vhost webmail

echo "Copy Webmail Lite application"
wget $AL_WEBMAIL_URL -O /tmp/$AL_WEBMAIL_ZIP
unzip /tmp/$AL_WEBMAIL_ZIP
cp -rT webmail "$WWWPATHHTML"/
if [ -d /tmp/webmail ]; then
  rm -rf /tmp/webmail
fi

echo "Set permissions to files and directories"
chown -R "$service_user":www-data "$WWWPATHHTML"/
find "$WWWPATHHTML" -type d -exec chmod 750 {} \;
find "$WWWPATHHTML" -type f -exec chmod 640 {} \;

create_mysql_db webmail_db

start_service "nginx php7.0-fpm"

echo "
open to install https://$DOMAIN_APP_NAME/install/
Delete the install directory

ADMINPanel: https://$DOMAIN_APP_NAME/adminpanel/
Adminuser:  mailadm Password: 12345

Users login:      https://$DOMAIN_APP_NAME/index.php

Then press any key to continue
"
Pause

if [ ! -d $SCRIPTS_DIR ]; then
  mkdir -p $SCRIPTS_DIR
fi

echo "Write root password into file $SCRIPTS_DIR/m-r-pass.txt, delete it soon!"
echo "MYSQL ROOT Password is $MYSQL_ROOT_PASS" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
echo "Webmail Lite MYSQL DB PASSWORD is $MYSQL_DB_PASSWORD" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
chmod 600 $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt

echo "Installation succeded...
Press ENTER to finish"
Pause
}

install_wordpress() {
echo "
*********************************************
Installing Wordpress
*********************************************"
SOFTWARE_URL=https://wordpress.org/latest.zip
SOFTWARE_ZIP=$(basename $SOFTWARE_URL)
PLUGIN1_URL=https://downloads.wordpress.org/plugin/gotmls.4.16.39.zip
PLUGIN1_ZIP=$(basename $PLUGIN1_URL)
PLUGIN2_URL=https://downloads.wordpress.org/plugin/better-wp-security.5.6.2.zip
PLUGIN2_ZIP=$(basename $PLUGIN2_URL)
PLUGIN3_URL=https://downloads.wordpress.org/plugin/redis-cache.1.3.4.zip
PLUGIN3_ZIP=$(basename $PLUGIN3_URL)
PLUGIN4_URL=https://downloads.wordpress.org/plugin/two-factor-authentication.1.2.13.zip
PLUGIN4_ZIP=$(basename $PLUGIN4_URL)

install_base_components

install_components "php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-gd php7.0-json php7.0-mysql php7.0-opcache php7.0-readline"

create_base_dirs

DOMAIN_APP_NAME=wordpress.example.com
echo "
------------------------------
Enter a name for installation.
It can contain the domain/subdomain name.
The base installation directory would be then e.g. $WWWPATH/$DOMAIN_APP_NAME

E.g.: $DOMAIN_APP_NAME
------------------------------"
read -r DOMAIN_APP_NAME

# reload variables to set the $DOMAIN_APP_NAME in $WWWPATHHTML
set_vars

echo "
------------------------------
Enter the full path for the installation directory,
The default is '$WWWPATH' followed by the entered name $DOMAIN_APP_NAME,
Per default a 'public_html' directory will be created for the application.

The default path would be then e.g.: $WWWPATHHTML
------------------------------"
read -r WWWPATHHTML

if [ ! -d "$WWWPATHHTML" ]; then
  mkdir -p "$WWWPATHHTML"
fi

install_mysql

install_nginx

use_redis=
while true; do
  echo "
  ------------------------------
  Do you want to use redis as cache? [Yes/No]
  ------------------------------"
  read -r yn
    case $yn in
        [Yy]* ) use_redis=true; break;;
        [Nn]* ) use_redis=false; break;;
        * ) echo "Please answer y or n.";;
    esac
done

$use_redis && install_redis
$use_redis && install_components php7.0-redis

install_php_fpm

create_snakeoil_certs

create_dh_param

create_service_user wordpress

create_php_pool

create_nginx_vhost wordpress

echo "Copy application files"
wget $SOFTWARE_URL -O /tmp/"$SOFTWARE_ZIP"
unzip /tmp/"$SOFTWARE_ZIP"
cp -rT wordpress "$WWWPATHHTML"/
if [ -d /tmp/wordpress ]; then
  rm -rf /tmp/wordpress
fi
if [ -f "$SOFTWARE_ZIP" ]; then
  rm -f "$SOFTWARE_ZIP"
fi

create_mysql_db wordpress

TABLE_PREFIX=
echo "
------------------------------
Enter a table prefix for this wordpress installation

e.g.:  wp1_
------------------------------"
read -r TABLE_PREFIX

echo "Adjust wordpress config file"
cp "$WWWPATHHTML"/wp-config-sample.php "$WWWPATHHTML"/wp-config.php
sed -i "s/^\$table_prefix.*;/\$table_prefix  = '$TABLE_PREFIX';/g" "$WWWPATHHTML"/wp-config.php
sed -i "s/^define('DB_HOST', '.*');/define('DB_HOST', '$MYSQL_HOST');/g" "$WWWPATHHTML"/wp-config.php
sed -i "s/^define('DB_USER', '.*');/define('DB_USER', '$MYSQL_DB_USER');/g" "$WWWPATHHTML"/wp-config.php
sed -i "s/^define('DB_NAME', '.*');/define('DB_NAME', '$MYSQL_DB_NAME');/g" "$WWWPATHHTML"/wp-config.php
sed -i "s/^define('DB_PASSWORD', '.*');/define('DB_PASSWORD', '$MYSQL_DB_PASSWORD');/g" "$WWWPATHHTML"/wp-config.php

echo "
/** Disallow theme editor for WordPress. */
define( 'DISALLOW_FILE_EDIT', true );" >> "$WWWPATHHTML"/wp-config.php

echo "
/** Disallow error reportin for php. */
error_reporting(0);
@ini_set(‘display_errors’, 0);" >> "$WWWPATHHTML"/wp-config.php

echo "
------------------------------
Setting wordpress salt strings
------------------------------"
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s "$WWWPATHHTML"/wp-config.php

echo "
------------------------------
Downloading and installing security plugins
------------------------------"
cd /tmp || echo 'Could not change directory to /tmp' #This should not happen as /tmp is a normally existend
wget $PLUGIN1_URL
unzip -q "$PLUGIN1_ZIP" -d "$WWWPATHHTML"/wp-content/plugins
if [ -f "$PLUGIN1_ZIP" ]; then
  rm -f "$PLUGIN1_ZIP"
fi

wget $PLUGIN2_URL
unzip -q "$PLUGIN2_ZIP" -d "$WWWPATHHTML"/wp-content/plugins
if [ -f "$PLUGIN2_ZIP" ]; then
  rm -f "$PLUGIN2_ZIP"
fi

wget $PLUGIN4_URL
unzip -q "$PLUGIN4_ZIP" -d "$WWWPATHHTML"/wp-content/plugins
if [ -f "$PLUGIN4_ZIP" ]; then
  rm -f "$PLUGIN4_ZIP"
fi

if $use_redis; then
echo "
------------------------------
Install redis object cache plugin for wordpress
------------------------------"
wget $PLUGIN3_URL
unzip -q "$PLUGIN3_ZIP" -d "$WWWPATHHTML"/wp-content/plugins
if [ -f "$PLUGIN3_ZIP" ]; then
  rm -f "$PLUGIN3_ZIP"
fi

sed -i "/^\$table_prefix.*/ a\\
\\
/** Redis config */ \\
define( 'WP_REDIS_CLIENT', 'pecl'); \\
define( 'WP_REDIS_SCHEME', 'unix'); \\
define( 'WP_REDIS_PATH', '/var/run/redis/redis.sock'); \\
define( 'WP_REDIS_DATABASE', '0'); \\
define( 'WP_REDIS_PASSWORD', '$REDIS_PASS'); \\
define( 'WP_REDIS_KEY_SALT', '${service_user}_');" "$WWWPATHHTML"/wp-config.php

add_user_to_group "$service_user" redis
fi

echo "write permission file for wordpress permissions"
echo "
[[ ! -d $WWWPATHHTML/wp-content/uploads ]] && \
mkdir -p $WWWPATHHTML/wp-content/uploads
chown -R $service_user:www-data $WWWPATHHTML/
find $WWWPATHHTML -type d -exec chmod 750 {} \;
find $WWWPATHHTML -type f -exec chmod 640 {} \;
chmod 600 $WWWPATHHTML/wp-config.php
" > $PERMISSIONFILES/"$DOMAIN_APP_NAME"-permission.sh

echo "set permissions for wordpress"
bash $PERMISSIONFILES/"$DOMAIN_APP_NAME"-permission.sh

start_service "nginx php7.0-fpm"

if [ ! -d $SCRIPTS_DIR ]; then
  mkdir -p $SCRIPTS_DIR
fi

echo "Write root password into file $SCRIPTS_DIR/$DOMAIN_APP_NAME-pass.txt, delete it soon!"
echo "MYSQL ROOT Password is $MYSQL_ROOT_PASS" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
$use_redis && echo "REDIS Server Password is $REDIS_PASS" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
echo "Wordpress MYSQL DB PASSWORD is $MYSQL_DB_PASSWORD" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
chmod 600 $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt

echo "Installation succeded...
Press ENTER to finish"
Pause
}

install_owncloud() {
echo "
*********************************************
Installing Owncloud
*********************************************"
SOFTWARE_URL=https://download.owncloud.org/community/owncloud-9.1.0.tar.bz2
SOFTWARE_ZIP=$(basename $SOFTWARE_URL)

install_base_components

install_components "software-properties-common php7.0 php7.0-common php7.0-mbstring php7.0-xmlwriter php7.0-mysql php7.0-intl php7.0-mcrypt php7.0-ldap php7.0-imap php7.0-cli php7.0-gd php7.0-json php7.0-curl php7.0-xmlrpc php7.0-zip libsm6 libsmbclient"

create_base_dirs

DOMAIN_APP_NAME=owncloud.example.com
echo "
------------------------------
Enter a name for installation.
It can contain the domain/subdomain name.
The base installation directory would be then e.g. $WWWPATH/$DOMAIN_APP_NAME

E.g.: $DOMAIN_APP_NAME
------------------------------"
read -r DOMAIN_APP_NAME
export DOMAIN_APP_NAME

# reload variables to set the $DOMAIN_APP_NAME in $WWWPATHHTML
set_vars

echo "
------------------------------
Enter the full path for the installation directory,
The default is '$WWWPATH' followed by the entered name $DOMAIN_APP_NAME,
Per default a 'public_html' directory will be created for the application.

The default path would be then e.g.: $WWWPATHHTML
------------------------------"
read -r WWWPATHHTML
export WWWPATHHTML
if [ ! -d "$WWWPATHHTML" ]; then
  mkdir -p "$WWWPATHHTML"
fi

install_mysql

install_nginx

while true; do
  echo "
  ------------------------------
  Do you want to use redis as cache? [Yes/No]
  ------------------------------"
  read -r yn
    case $yn in
        [Yy]* ) use_redis=true; break;;
        [Nn]* ) use_redis=false; break;;
        * ) echo "Please answer y or n.";;
    esac
done

$use_redis && install_redis
$use_redis && install_components php7.0-redis

APP_TIMEZONE=Europe/Berlin
echo "
------------------------------
Please enter your owncloud timezone (e.g. for owncloud internal log entries)

E.g.: $APP_TIMEZONE
------------------------------"
read -r APP_TIMEZONE

install_php_fpm "$APP_TIMEZONE"

create_snakeoil_certs

create_dh_param

create_service_user owncloud

create_php_pool

create_nginx_vhost owncloud

create_mysql_db owncloud

TABLE_PREFIX=
echo "
------------------------------
Enter a table prefix for this owncloud installation

E.g.: oc1_
------------------------------"
read -r TABLE_PREFIX
export TABLE_PREFIX

start_service "nginx"

echo "Copy application files"
cd /tmp || echo 'Could not change directory to /tmp' #This should not happen as /tmp is a normally existend
wget $SOFTWARE_URL -O /tmp/"$SOFTWARE_ZIP"
tar -xjf  /tmp/"$SOFTWARE_ZIP"
cp -rT owncloud "$WWWPATHHTML"
if [ -f  /tmp/"$SOFTWARE_ZIP" ]; then
  rm -f /tmp/"$SOFTWARE_ZIP"
fi
if [ -d /tmp/owncloud ]; then
  rm -rf /tmp/owncloud
fi

echo "Download secure permission file from github"
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/setup_secure_permissions_owncloud.sh -O $PERMISSIONFILES/"$DOMAIN_APP_NAME"-secure-permission.sh
sed -i "s,OWNCLOUDPATH,$WWWPATHHTML," $PERMISSIONFILES/"$DOMAIN_APP_NAME"-secure-permission.sh
sed -i "s,HTUSER,$service_user," $PERMISSIONFILES/"$DOMAIN_APP_NAME"-secure-permission.sh
chmod +x $PERMISSIONFILES/"$DOMAIN_APP_NAME"-secure-permission.sh

wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/update_set_permission.sh -O $PERMISSIONFILES/"$DOMAIN_APP_NAME"-permission_update.sh
sed -i "s,OWNCLOUDPATH,$WWWPATHHTML," $PERMISSIONFILES/"$DOMAIN_APP_NAME"-permission_update.sh
chmod +x $PERMISSIONFILES/"$DOMAIN_APP_NAME"-permission_update.sh

echo "set setup permissions"
bash $PERMISSIONFILES/"$DOMAIN_APP_NAME"-permission_update.sh

echo "
------------------------------
Installing owncloud
------------------------------"
#echo "su www-data -s /bin/bash -c 'php $WWWPATHHTML/occ maintenance:install -vvv --database "mysql" --database-name "$MYSQL_DB_NAME" --database-table-prefix "$TABLE_PREFIX" --database-user "$MYSQL_DB_USER" --database-pass "$MYSQL_DB_PASSWORD" --admin-user "admin" --admin-pass "admin"'"
su www-data -s /bin/bash -c "php $WWWPATHHTML/occ maintenance:install -vvv --database mysql --database-name $MYSQL_DB_NAME --database-table-prefix $TABLE_PREFIX --database-user $MYSQL_DB_USER --database-pass $MYSQL_DB_PASSWORD --admin-user admin --admin-pass admin"

echo "
------------------------------
Configuring owncloud
------------------------------"
cp "$WWWPATHHTML"/config/config.php "$WWWPATHHTML"/config/config.php.orig_"$(date +%F-%T)"

if ! grep  -Fq "'$DOMAIN_APP_NAME'" "$WWWPATHHTML"/config/config.php
then
su www-data -s /bin/bash -c "php $WWWPATHHTML/occ config:system:set trusted_domains 2 --value=$DOMAIN_APP_NAME"
fi

if ! grep -Fq "'https://$DOMAIN_APP_NAME'" "$WWWPATHHTML"/config/config.php
then
su www-data -s /bin/bash -c "php $WWWPATHHTML/occ config:system:set overwrite.cli.url --value=https://$DOMAIN_APP_NAME"
fi

sed -i "s,UTC,$APP_TIMEZONE,"  "$WWWPATHHTML"/config/config.php

echo "
------------------------------
add owncloud background crontab entry for $service_user user
------------------------------"
su www-data -s /bin/bash -c "php $WWWPATHHTML/occ background:cron"

(crontab -l -u "$service_user"  2>/dev/null; echo "*/15 * * * * php $WWWPATHHTML/cron.php") | crontab -u "$service_user" -


# TODO Default mail server
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpmode --value="smtp"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpauth --value="1"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpport --value="465"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtphost --value="smtp.gmail.com"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpauthtype --value="LOGIN"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_from_address --value="www.en0ch.se"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_domain --value="gmail.com"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpsecure --value="ssl"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpname --value="www.en0ch.se@gmail.com"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtppassword --value="techandme_se"' www-data

if $use_redis; then

echo "
------------------------------
Owncloud Redis config
------------------------------"
sed -i '$ d' "$WWWPATHHTML"/config/config.php
{
echo "'filelocking.enabled' => true,
'memcache.local' => '\OC\Memcache\Redis',
'memcache.locking' => '\OC\Memcache\Redis',
'redis' => array(
   'host' => '/var/run/redis/redis.sock',
   'port' => 0,
   'timeout' => 0.0,
   'password' => '$REDIS_PASS',
    ), "
} >> "$WWWPATHHTML"/config/config.php

add_user_to_group "$service_user" redis
fi

echo "set permissions"
bash $PERMISSIONFILES/"$DOMAIN_APP_NAME"-secure-permission.sh

start_service "nginx php7.0-fpm"

if [ ! -d $SCRIPTS_DIR ]; then
  mkdir -p $SCRIPTS_DIR
fi

echo "Write root password into file $SCRIPTS_DIR/$DOMAIN_APP_NAME-pass.txt, delete it soon!"
printf "Writing passwords at $(date) for installation %s" "$DOMAIN_APP_NAME" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
echo "MYSQL ROOT Password is $MYSQL_ROOT_PASS" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
$use_redis && echo "REDIS Server Password is $REDIS_PASS" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
echo "Owncloud MYSQL DB PASSWORD is $MYSQL_DB_PASSWORD" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
chmod 600 $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt

echo "
User: admin
Password: admin
Please change it soon!

Installation succeded...
Press ENTER to finish"
Pause
}

install_nextcloud() {
echo "
*********************************************
Installing Nextcloud
*********************************************"
SOFTWARE_URL=https://download.nextcloud.com/server/releases/nextcloud-10.0.1.tar.bz2
SOFTWARE_ZIP=$(basename $SOFTWARE_URL)

install_base_components

install_components "software-properties-common php7.0 php7.0-common php7.0-mbstring php7.0-xmlwriter php7.0-mysql php7.0-intl php7.0-mcrypt php7.0-ldap php7.0-imap php7.0-cli php7.0-gd php7.0-json php7.0-curl php7.0-xmlrpc php7.0-zip libsm6 libsmbclient"

create_base_dirs

DOMAIN_APP_NAME=nextcloud.example.com
echo "
------------------------------
Enter a name for installation.
It can contain the domain/subdomain name.
The base installation directory would be then e.g. $WWWPATH/$DOMAIN_APP_NAME

E.g.: $DOMAIN_APP_NAME
------------------------------"
read -r DOMAIN_APP_NAME
export DOMAIN_APP_NAME

# reload variables to set the $DOMAIN_APP_NAME in $WWWPATHHTML
set_vars

echo "
------------------------------
Enter the full path for the installation directory,
The default is '$WWWPATH' followed by the entered name $DOMAIN_APP_NAME,
Per default a 'public_html' directory will be created for the application.

The default path would be then e.g.: $WWWPATHHTML
------------------------------"
read -r WWWPATHHTML
export WWWPATHHTML
if [ ! -d "$WWWPATHHTML" ]; then
  mkdir -p "$WWWPATHHTML"
fi

install_mysql

install_nginx

use_redis=
while true; do
  echo "
  ------------------------------
  Do you want to use redis as cache? [Yes/No]
  ------------------------------"
  read -r yn
    case $yn in
        [Yy]* ) use_redis=true; break;;
        [Nn]* ) use_redis=false; break;;
        * ) echo "Please answer y or n.";;
    esac
done

$use_redis && install_redis
$use_redis && install_components php7.0-redis

APP_TIMEZONE=Europe/Berlin
echo "
------------------------------
Please enter your owncloud timezone (e.g. for owncloud internal log entries)

E.g.: $APP_TIMEZONE
------------------------------"
read -r APP_TIMEZONE

install_php_fpm "$APP_TIMEZONE"

create_snakeoil_certs

create_dh_param

create_service_user nextcloud

create_php_pool

create_nginx_vhost nextcloud

create_mysql_db nextcloud

TABLE_PREFIX=
echo "
------------------------------
Enter a table prefix for this nextcloud installation

E.g.: nc1_
------------------------------"
read -r TABLE_PREFIX
export TABLE_PREFIX

start_service "nginx"

echo "Copy application files"
cd /tmp || echo 'Could not change directory to /tmp' #This should not happen as /tmp is a normally existend
wget $SOFTWARE_URL -O /tmp/"$SOFTWARE_ZIP"
tar -xjf  /tmp/"$SOFTWARE_ZIP"
cp -rT nextcloud "$WWWPATHHTML"
if [ -f  /tmp/"$SOFTWARE_ZIP" ]; then
  rm -f /tmp/"$SOFTWARE_ZIP"
fi

if [ -d /tmp/nextcloud ]; then
  rm -rf /tmp/nextcloud
fi

echo "Download secure permission file from github"
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/setup_secure_permissions_owncloud.sh -O $PERMISSIONFILES/"$DOMAIN_APP_NAME"-secure-permission.sh
sed -i "s,OWNCLOUDPATH,$WWWPATHHTML," $PERMISSIONFILES/"$DOMAIN_APP_NAME"-secure-permission.sh
sed -i "s,HTUSER,$service_user," $PERMISSIONFILES/"$DOMAIN_APP_NAME"-secure-permission.sh
chmod +x $PERMISSIONFILES/"$DOMAIN_APP_NAME"-secure-permission.sh

wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/update_set_permission.sh -O $PERMISSIONFILES/"$DOMAIN_APP_NAME"-permission_update.sh
sed -i "s,OWNCLOUDPATH,$WWWPATHHTML," $PERMISSIONFILES/"$DOMAIN_APP_NAME"-permission_update.sh
chmod +x $PERMISSIONFILES/"$DOMAIN_APP_NAME"-permission_update.sh

echo "set setup permissions"
bash $PERMISSIONFILES/"$DOMAIN_APP_NAME"-permission_update.sh

echo "
------------------------------
Installing nextcloud
------------------------------"
#echo "su www-data -s /bin/bash -c 'php $WWWPATHHTML/occ maintenance:install -vvv --database "mysql" --database-name "$MYSQL_DB_NAME" --database-table-prefix "$TABLE_PREFIX" --database-user "$MYSQL_DB_USER" --database-pass "$MYSQL_DB_PASSWORD" --admin-user "admin" --admin-pass "admin"'"
su www-data -s /bin/bash -c "php $WWWPATHHTML/occ maintenance:install -vvv --database mysql --database-name $MYSQL_DB_NAME --database-table-prefix $TABLE_PREFIX --database-user $MYSQL_DB_USER --database-pass $MYSQL_DB_PASSWORD --admin-user admin --admin-pass admin"

echo "
------------------------------
Configuring nextcloud
------------------------------"
cp "$WWWPATHHTML"/config/config.php "$WWWPATHHTML"/config/config.php.orig_"$(date +%F-%T)"

if ! grep -Fq "'$DOMAIN_APP_NAME'" "$WWWPATHHTML"/config/config.php
then
su www-data -s /bin/bash -c "php $WWWPATHHTML/occ config:system:set trusted_domains 2 --value=$DOMAIN_APP_NAME"
fi

if ! grep -Fq "'https://$DOMAIN_APP_NAME'" "$WWWPATHHTML"/config/config.php
then
su www-data -s /bin/bash -c "php $WWWPATHHTML/occ config:system:set overwrite.cli.url --value=https://$DOMAIN_APP_NAME"
fi

sed -i "s,UTC,$APP_TIMEZONE,"  "$WWWPATHHTML"/config/config.php

echo "
------------------------------
add nextcloud background crontab entry for $service_user user
------------------------------"
su www-data -s /bin/bash -c "php $WWWPATHHTML/occ background:cron"

(crontab -l -u "$service_user"  2>/dev/null; echo "*/15 * * * * php $WWWPATHHTML/cron.php") | crontab -u "$service_user" -


# TODO Default mail server
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpmode --value="smtp"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpauth --value="1"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpport --value="465"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtphost --value="smtp.gmail.com"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpauthtype --value="LOGIN"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_from_address --value="www.en0ch.se"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_domain --value="gmail.com"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpsecure --value="ssl"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtpname --value="www.en0ch.se@gmail.com"' www-data
# su -s /bin/sh -c 'php $WWWPATHHTML/occ config:system:set mail_smtppassword --value="techandme_se"' www-data

if $use_redis; then

echo "
------------------------------
Owncloud Redis config
------------------------------"
sed -i '$ d' "$WWWPATHHTML"/config/config.php
{
echo "'filelocking.enabled' => true,
'memcache.local' => '\OC\Memcache\Redis',
'memcache.locking' => '\OC\Memcache\Redis',
'redis' => array(
   'host' => '/var/run/redis/redis.sock',
   'port' => 0,
   'timeout' => 0.0,
   'password' => '$REDIS_PASS',
    ), "
} >> "$WWWPATHHTML"/config/config.php

add_user_to_group "$service_user" redis
fi

echo "set permissions"
bash $PERMISSIONFILES/"$DOMAIN_APP_NAME"-secure-permission.sh

start_service "nginx php7.0-fpm"

if [ ! -d $SCRIPTS_DIR ]; then
  mkdir -p $SCRIPTS_DIR
fi

echo "Write root password into file $SCRIPTS_DIR/$DOMAIN_APP_NAME-pass.txt, delete it soon!"
printf "Writing passwords at $(date) for installation %s" "$DOMAIN_APP_NAME" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
echo "MYSQL ROOT Password is $MYSQL_ROOT_PASS" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
$use_redis && echo "REDIS Server Password is $REDIS_PASS" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
echo "Owncloud MYSQL DB PASSWORD is $MYSQL_DB_PASSWORD" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
chmod 600 $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt

echo "
User: admin
Password: admin
Please change it soon!

Install TOTP with this manual:
https://help.nextcloud.com/t/10-0rc1-how-to-enable-2fa/2447/8

Installation succeded...
Press ENTER to finish"
Pause
}

install_redis() {
echo "
*********************************************
Installing Redis-Server
*********************************************"

install_components "redis-server"

echo "
------------------------------
Configure redis-server for using socket end set password
------------------------------"
REDIS_CONF=/etc/redis/redis.conf
REDIS_PASS=
if grep -Fq '# requirepass' $REDIS_CONF; then
echo "
------------------------------
Enter a password for the redis cache communication
------------------------------"
stty -echo
read -r REDIS_PASS
stty echo
printf "\n"
else
REDIS_PASS=$(grep 'requirepass ' $REDIS_CONF | cut -d " " -f 2)

pw_len=${#REDIS_PASS}
sub_pw_len=$(awk "BEGIN {print $pw_len - 3}")
masked_redis_pw=
count=1

while [ "$count" -le "$sub_pw_len" ]; do
  masked_redis_pw="${masked_redis_pw}"X
  count=$((count + 1))
done

echo "
------------------------------
The password was found and loaded from the redis.conf file.
------------------------------"
shown_pw_part=$(echo | awk ' { print substr("'"${REDIS_PASS}"'","'"$((pw_len-2))"'")  }')
echo $masked_redis_pw"${shown_pw_part}" && echo "Press return to continue." && Pause
fi

cp $REDIS_CONF ${REDIS_CONF}.orig_"$(date +%F-%T)"
sed -i 's/^port .*/port 0/' $REDIS_CONF
sed -i "/requirepass .*/c\requirepass $REDIS_PASS" $REDIS_CONF

if ! grep -Fq "^unixsocket /var/run/redis/redis.sock" $REDIS_CONF
then
echo 'unixsocket /var/run/redis/redis.sock' >> $REDIS_CONF
fi
if ! grep -Fq "^unixsocketperm 770" $REDIS_CONF
then
echo 'unixsocketperm 770' >> $REDIS_CONF
fi

if [ ! -d /var/run/redis ]; then
  mkdir /var/run/redis
fi
chown redis:redis /var/run/redis
chmod 755 /var/run/redis
if [ -d /etc/tmpfiles.d ]
then
echo 'd  /var/run/redis  0755  redis  redis  10d  -' >> /etc/tmpfiles.d/redis.conf
fi

add_user_to_group www-data redis

start_service "redis-server"
}

install_nginx() {
echo "
*********************************************
Installing NGINX with GEOIP Database
*********************************************"
command -v wget >/dev/null 2>&1 || install_components wget

install_components "nginx geoip-database libgeoip1 apache2-utils"

echo "Download latest geoip database."
mv /usr/share/GeoIP/GeoIP.dat /usr/share/GeoIP/GeoIP.dat_bak
cd /usr/share/GeoIP || echo "Couldn't change directory to /usr/share/GeoIP"
wget https://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
gunzip GeoIP.dat.gz

if [ ! -d /etc/nginx/global ]; then
  mkdir -p /etc/nginx/global
fi
if [ ! -f /etc/nginx/global/geoip_settings.conf ]; then
  wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/geoip_settings.conf -O /etc/nginx/global/geoip_settings.conf
fi
if [ ! -f /etc/nginx/global/restrictions.conf ]; then
  wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/restrictions.conf -O /etc/nginx/global/restrictions.conf
fi
if [ ! -f /etc/nginx/global/secure_ssl.conf ]; then
  wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/secure_ssl.conf -O /etc/nginx/global/secure_ssl.conf
fi
if [ ! -f /etc/nginx/global/wordpress.conf ]; then
  wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/wordpress.conf -O /etc/nginx/global/wordpress.conf
fi

echo "Disable nginx default config"
NGINX_DIR=/etc/nginx
if [ ! -d $NGINX_DIR ]; then
  printf "Where is your nginx location? Please enter the path: "
  printf "E.g.: %s " "$NGINX_DIR"
  read -r NGINX_DIR
fi
if [ -f "$NGINX_DIR"/sites-enabled/default ]; then
  rm -rf "$NGINX_DIR"/sites-enabled/default
fi

NGINX_CONF=$NGINX_DIR/nginx.conf
if [ ! -f "$NGINX_CONF" ]; then
  printf "Where is your nginx configuration location? Please enter the full path: "
  printf "E.g.: %s" "$NGINX_DIR/nginx.conf"
  read -r NGINX_CONF;
fi

if [ "$(grep -Fc 'worker_processes 4;' "$NGINX_CONF")" -eq "0" ];
then
sed -i -r -e 's/worker_processes.*/# &/' "$NGINX_CONF"
awk '/worker_processes/{p++} /worker_processes/ && p==1 {$0= $0"\nworker_processes 4;"}1' "$NGINX_CONF" > "$NGINX_CONF".tmp
mv "$NGINX_CONF".tmp "$NGINX_CONF"
fi

if [ "$(grep -Fc 'worker_connections 1024' "$NGINX_CONF")" -eq "0" ];
then
sed -i -r -e 's/worker_connections.*/# &/' "$NGINX_CONF"
awk '/worker_connections/{p++} /worker_connections/ && p==1 {$0= $0"\nworker_connections 1024;"}1' "$NGINX_CONF" > "$NGINX_CONF".tmp
mv "$NGINX_CONF".tmp "$NGINX_CONF"
fi

# disabled nginx server header information display
sed -i -r -e 's/.*server_tokens.*/        server_tokens off;/' "$NGINX_CONF"

if [ "$(grep -Fc 'geoip_settings.conf' "$NGINX_CONF")" -eq "0" ];
then sed -i -e '/^http {/ a include /etc/nginx/global/geoip_settings.conf;' "$NGINX_CONF"; fi
}

install_php_fpm() {
echo "
*********************************************
Installing PHP FPM
*********************************************"
install_components "php7.0-fpm"

if [ ! -d /var/run/php ]; then
  mkdir -p /var/run/php
fi
if [ ! -d /var/log/php ]; then
  mkdir -p /var/log/php
fi

echo "Configure php fpm"
PHP_TIMEZONE=$1
if [ -z "$PHP_TIMEZONE" ]; then
  PHP_TIMEZONE=Europe/Berlin
fi
PHP_CONFIG_FILE=/etc/php/7.0/fpm/php.ini
PHPFPM_CONFIG_FILE=/etc/php/7.0/fpm/php-fpm.conf
echo "
------------------------------
Please enter your timezone for php
------------------------------

E.g.: $PHP_TIMEZONE
"
read -r PHP_TIMEZONE
if [ ! -f $PHP_CONFIG_FILE ]; then
  echo "
  ------------------------------
  Where is your fpm php.ini file located? Please enter the full path
  ------------------------------
  E.g.: /etc/php/7.0/fpm/php.ini
  "
  read -r PHP_CONFIG_FILE
else
  cp "$PHP_CONFIG_FILE" "$PHP_CONFIG_FILE".bkp
fi

if [ ! -f $PHPFPM_CONFIG_FILE ]; then
  echo "
  ------------------------------
  Where is your fpm php-fpm.conf file located? Please enter the full path
  ------------------------------

  E.g.: /etc/php/7.0/fpm/php-fpm.conf
  "
  read -r PHPFPM_CONFIG_FILE
else
  cp "$PHPFPM_CONFIG_FILE" "$PHPFPM_CONFIG_FILE".bkp
fi

if [ -f /etc/php/7.0/fpm/pool.d/www.conf ]; then
  mv /etc/php/7.0/fpm/pool.d/www.conf /etc/php/7.0/fpm/pool.d/www.off
fi

if [ "$(grep -Fc 'cgi.fix_pathinfo = 0' "$PHP_CONFIG_FILE")" -eq "0" ];
then
sed -i -r -e 's/.*cgi.fix_pathinfo.*/; &/' "$PHP_CONFIG_FILE"
awk '/cgi.fix_pathinfo/{p++} /cgi.fix_pathinfo/ && p==1 {$0= $0"\ncgi.fix_pathinfo = 0"}1' "$PHP_CONFIG_FILE" > "$PHP_CONFIG_FILE".tmp
mv "$PHP_CONFIG_FILE".tmp "$PHP_CONFIG_FILE"
fi

if [ "$(grep -Fc "date.timezone = $PHP_TIMEZONE" "$PHP_CONFIG_FILE")" -eq "0" ];
then
sed -i -r -e 's/.*date.timezone =.*/; &/' "$PHP_CONFIG_FILE"
awk -v php_tz="$PHP_TIMEZONE" '/date.timezone/{p++} /date.timezone/ && p==1 {$0= $0"\ndate.timezone = " php_tz}1' "$PHP_CONFIG_FILE" > "$PHP_CONFIG_FILE".tmp
mv "$PHP_CONFIG_FILE".tmp "$PHP_CONFIG_FILE"
fi

if [ "$(grep -Fc 'opcache.enable = 1' "$PHP_CONFIG_FILE")" -eq "0" ];
then
sed -i -r -e 's/.*opcache.enable[ |=].*/; &/' "$PHP_CONFIG_FILE"
awk '/opcache.enable/{p++} /opcache.enable/ && p==1 {$0= $0"\nopcache.enable = 1"}1' "$PHP_CONFIG_FILE" > "$PHP_CONFIG_FILE".tmp
mv "$PHP_CONFIG_FILE".tmp "$PHP_CONFIG_FILE"
fi

if [ "$(grep -Fc 'pid = /var/run/php/php7.0-fpm.pid' "$PHPFPM_CONFIG_FILE")" -eq "0" ]
then
sed -i -r -e 's/.*pid =.*/; &/' "$PHP_CONFIG_FILE"
awk '/pid =/{p++} /pid =/ && p==1 {$0= $0"\npid = /var/run/php/php7.0-fpm.pid"}1' "$PHPFPM_CONFIG_FILE" > "$PHPFPM_CONFIG_FILE".tmp
mv "$PHPFPM_CONFIG_FILE".tmp "$PHPFPM_CONFIG_FILE"
fi

if [ "$(grep -Fc 'events.mechanism = epoll' "$PHPFPM_CONFIG_FILE")" -eq "0" ];
then
sed -i -r -e 's/.*events.mechanism =.*/; &/' "$PHP_CONFIG_FILE"
awk '/events.mechanism/{p++} /events.mechanism/ && p==1 {$0= $0"\nevents.mechanism = epoll"}1' "$PHPFPM_CONFIG_FILE" > "$PHPFPM_CONFIG_FILE".tmp
mv "$PHPFPM_CONFIG_FILE".tmp "$PHPFPM_CONFIG_FILE"
fi

if [ "$(grep -Fc 'emergency_restart_threshold = 10' "$PHPFPM_CONFIG_FILE")" -eq "0" ];
then
sed -i -r -e 's/.*emergency_restart_threshold =.*/; &/' "$PHP_CONFIG_FILE"
awk '/emergency_restart_threshold/{p++} /emergency_restart_threshold/ && p==1 {$0= $0"\nemergency_restart_threshold = 10"}1' "$PHPFPM_CONFIG_FILE" > "$PHPFPM_CONFIG_FILE".tmp
mv "$PHPFPM_CONFIG_FILE".tmp "$PHPFPM_CONFIG_FILE"
fi

if [ "$(grep -Fc 'emergency_restart_interval = 1m' "$PHPFPM_CONFIG_FILE")" -eq "0" ];
then
sed -i -r -e 's/.*emergency_restart_interval =.*/; &/' "$PHP_CONFIG_FILE"
awk '/emergency_restart_interval/{p++} /emergency_restart_interval/ && p==1 {$0= $0"\nemergency_restart_interval = 1m"}1' "$PHPFPM_CONFIG_FILE" > "$PHPFPM_CONFIG_FILE".tmp
mv "$PHPFPM_CONFIG_FILE".tmp "$PHPFPM_CONFIG_FILE"
fi

if [ "$(grep -Fc 'process_control_timeout = 10s' "$PHPFPM_CONFIG_FILE")" -eq "0" ];
then
sed -i -r -e 's/.*process_control_timeout =/; &/' "$PHP_CONFIG_FILE"
awk '/process_control_timeout/{p++} /process_control_timeout/ && p==1 {$0= $0"\nprocess_control_timeout = 10s"}1' "$PHPFPM_CONFIG_FILE" > "$PHPFPM_CONFIG_FILE".tmp
mv "$PHPFPM_CONFIG_FILE".tmp "$PHPFPM_CONFIG_FILE"
fi

if [ "$(grep -Fc 'error_log = /var/log/php/php7.0-fpm.log' "$PHPFPM_CONFIG_FILE")" -eq "0" ];
then
sed -i -r -e 's/.*error_log =.*/; &/' "$PHP_CONFIG_FILE"
awk '/error_log =/{p++} /error_log =/ && p==1 {$0= $0"\nerror_log = /var/log/php/php7.0-fpm.log"}1' "$PHPFPM_CONFIG_FILE" > "$PHPFPM_CONFIG_FILE".tmp
mv "$PHPFPM_CONFIG_FILE".tmp "$PHPFPM_CONFIG_FILE"
fi
}

install_unbound() {
echo "
*********************************************
Installing Unbound
*********************************************"
install_components "unbound"

unbound-anchor
unbound_trust_file=/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf
newrk=/usr/local/etc/unbound/runtime/root.key
mkdir -p "$(dirname $newrk)"
chown unbound:unbound "$(dirname $newrk)"
if [ -f /etc/unbound/root.key ]; then
  mv /etc/unbound/root.key $newrk
  chown unbound:unbound $newrk
fi

if [ -f $unbound_trust_file ]; then
  sed -i "s,auto-trust-anchor-file.*,auto-trust-anchor-file: \"$newrk\"," $unbound_trust_file
else
  echo "ERROR: file not found: $unbound_trust_file. Please fix this issue later. Press any key to continue."
  Pause
fi
echo "Configure unbound"
echo "server:
interface: 127.0.0.1
do-ip6: no
directory: \"/etc/unbound\"
username: unbound
harden-below-nxdomain: yes
harden-referral-path: yes
# not yet available            harden-algo-downgrade: no # false positives with improperly configured zones
use-caps-for-id: no # makes lots of queries fail
hide-identity: yes
hide-version: yes
prefetch: yes
prefetch-key: yes
msg-cache-size: 128k
msg-cache-slabs: 2
rrset-cache-size: 8m
rrset-cache-slabs: 2
key-cache-size: 32m
key-cache-slabs: 2
cache-min-ttl: 3600
num-threads: 2
val-log-level: 2
use-syslog: yes
verbosity: 1
remote-control:
control-enable: no
#            control-interface: 127.0.0.1
" > /etc/unbound/unbound.conf.d/dns_setting.conf

start_service unbound

UNBOUNDISSTARTED=$(pgrep -c unbound)

echo "Change resolv.conf to use 127.0.0.1 (aka localhost)"
if [ "$UNBOUNDISSTARTED" -ge "1" ];
then
sed -i 's/^/# /g' /etc/resolv.conf
echo "nameserver 127.0.0.1" >> /etc/resolv.conf
nameservers_to_add=
echo "
*********************************************
Please enter all nameservers you want to add
space separated
*********************************************"
read -r nameservers_to_add
for i in $nameservers_to_add
do
echo "nameserver $i" >> /etc/resolv.conf
done

echo "
*********************************************
Unbound was installed
*********************************************"
else
echo "ERROR: Unbound did not start"
service unbound status
fi
}

install_bbs() {
echo "
*********************************************
Installing BBS ( BicBucStriim )
*********************************************"
BBSZIPFILEPATH=https://github.com/rvolz/BicBucStriim/archive/v1.3.6.zip
BBSZIPFILE=$(basename $BBSZIPFILEPATH)
BBSUNZIPNAME=BicBucStriim-$(echo "$BBSZIPFILE" | sed -r 's/v([0-9].[0-9].[0-9].?[0-9]?).zip/\1/')

install_base_components
install_components "php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-gd php7.0-intl php7.0-json php7.0-mcrypt php7.0-opcache php7.0-sqlite3 php7.0-xml"

create_base_dirs

echo "Download and unzip bbs"
cd /tmp || echo 'Could not change directory to /tmp' #This should not happen as /tmp is a normally existend
wget $BBSZIPFILEPATH
unzip "$BBSZIPFILE"
rm "$BBSZIPFILE"

DOMAIN_APP_NAME=ebooks.example.com
echo "
------------------------------
Enter a name for installation.
It can contain the domain/subdomain name.
The base installation directory would be then e.g. $WWWPATH/$DOMAIN_APP_NAME

E.g.: $DOMAIN_APP_NAME
------------------------------"
read -r DOMAIN_APP_NAME

# reload variables to set the $DOMAIN_APP_NAME in $WWWPATHHTML
set_vars

echo "
------------------------------
Enter the full path for the installation directory,
The default is '$WWWPATH' followed by the entered name $DOMAIN_APP_NAME,
Per default a 'public_html' directory will be created for the application.

The default path would be then e.g.: $WWWPATHHTML
------------------------------"
read -r WWWPATHHTML

if [ ! -d "$WWWPATHHTML" ]; then
  mkdir -p "$WWWPATHHTML"
fi

echo "Copy bbs"
cp -rT "$BBSUNZIPNAME" "$WWWPATHHTML"
if [ -f /tmp/"$BBSUNZIPNAME" ]; then
  rm -f /tmp/"$BBSUNZIPNAME"
fi

create_service_user ebooks

add_user_to_group "$service_user" www-data,ownclouduser

install_nginx

install_php_fpm

create_snakeoil_certs

create_dh_param

create_php_pool

create_nginx_vhost bbs

echo "Set permissions to files and directories"
chown -R "$service_user":www-data "$WWWPATHHTML"/
find "$WWWPATHHTML" -type d -exec chmod 750 {} \;
find "$WWWPATHHTML" -type f -exec chmod 640 {} \;

start_service "nginx php7.0-fpm"

}

install_cops() {
echo "
*********************************************
Installing COPS (Calibre OPDS PHP Server)
*********************************************"
COPSZIPFILEPATH=https://github.com/seblucas/cops/releases/download/1.0.0/cops-1.0.0.zip
COPSZIPFILE=$(basename $COPSZIPFILEPATH)

install_base_components
install_components "php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-gd php7.0-intl php7.0-json php7.0-mcrypt php7.0-opcache php7.0-sqlite3 php7.0-xml php7.0-mbstring"

create_base_dirs

echo "Download and unzip COPS"
cd /tmp || echo 'Could not change directory to /tmp' #This should not happen as /tmp is a normally existend
wget $COPSZIPFILEPATH
unzip "$COPSZIPFILE" -d /tmp/cops
if [ -f "$COPSZIPFILE" ]; then
  rm "$COPSZIPFILE"
fi

DOMAIN_APP_NAME=ebooks.example.com
echo "
------------------------------
Enter a name for installation.
It can contain the domain/subdomain name.
The base installation directory would be then e.g. $WWWPATH/$DOMAIN_APP_NAME

E.g.: $DOMAIN_APP_NAME
------------------------------"
read -r DOMAIN_APP_NAME

# reload variables to set the $DOMAIN_APP_NAME in $WWWPATHHTML
set_vars

echo "
------------------------------
Enter the full path for the installation directory,
The default is '$WWWPATH' followed by the entered name $DOMAIN_APP_NAME,
Per default a 'public_html' directory will be created for the application.

The default path would be then e.g.: $WWWPATHHTML
------------------------------"
read -r WWWPATHHTML

if [ ! -d "$WWWPATHHTML" ]; then
  mkdir -p "$WWWPATHHTML"
fi

echo "Copy COPS"
cp -rT /tmp/cops "$WWWPATHHTML"
if [ -d /tmp/cops ]; then
  rm -rf /tmp/cops
fi

create_service_user ebooks2

add_user_to_group "$service_user" www-data,ownclouduser

install_nginx

install_php_fpm

create_snakeoil_certs

create_dh_param

create_php_pool

create_nginx_vhost cops

cp "$WWWPATHHTML"/config_local.php.example "$WWWPATHHTML"/config_local.php
sed -i "s,.*config\['calibre_directory'\] =.*;,\$config['calibre_directory'] = '$CALIBRE_LIBRARY/';," "$WWWPATHHTML"/config_local.php


echo "Set permissions to files and directories"
chown -R "$service_user":www-data "$WWWPATHHTML"/
find "$WWWPATHHTML" -type d -exec chmod 750 {} \;
find "$WWWPATHHTML" -type f -exec chmod 640 {} \;

start_service "nginx php7.0-fpm"

}

install_monit() {
echo "
*********************************************
Installing monit
*********************************************"

install_base_components

create_base_dirs

install_components monit

create_service_user monit

install_nginx

install_php_fpm

if [ -z "$DOMAIN_APP_NAME" ]; then
  DOMAIN_APP_NAME=monit.example.com
fi

echo "
------------------------------
Enter a name for installation.
It can contain the domain/subdomain name.
The base installation directory would be then e.g. $WWWPATH/$DOMAIN_APP_NAME

E.g.: monit.example.com
------------------------------"
read -r DOMAIN_APP_NAME

create_snakeoil_certs

create_dh_param


while true; do
  echo "
  ------------------------------
  Do you want to create combination of key and certificate?
  ------------------------------ [Y/n]"
  read -r yn
    case $yn in
        [Yy]* )
        cat $CERTS_PATH/"$KEY_COMMON_NAME".key > $CERTS_PATH/"${KEY_COMMON_NAME}"_combined.pem
        cat $CERTS_PATH/"$KEY_COMMON_NAME".crt >> $CERTS_PATH/"${KEY_COMMON_NAME}"_combined.pem
        chmod 600 $CERTS_PATH/"${KEY_COMMON_NAME}"_combined.pem
        break;;
        [Nn]* ) break;;
        * ) echo "Please answer y or n.";;
    esac
done

USER=user
echo "
------------------------------
Enter a username for the web interface access.

E.g.: $USER
------------------------------"
read -r USER

PASSWORD=
echo "
------------------------------
Enter a password for the web interface access.
------------------------------"
stty -echo
read -r PASSWORD
stty echo
printf "\n"

# the PEMFILE should be a chain of the public key and cert use cat >>  to achive this
PEMFILE=$CERTS_PATH/${KEY_COMMON_NAME}_combined.pem
if [ ! -f "$PEMFILE" ]; then
echo "
------------------------------
Enter the full path to the combined file ob public key and certificate for the HTTPS connection to MONIT.

E.g.: $PEMFILE
------------------------------"
read -r PEMFILE
fi

MAILSERVER=127.0.0.1
echo "
------------------------------
Enter a mailserver to receive notifications from MONIT.

E.g.: $MAILSERVER
------------------------------"
read -r MAILSERVER

# reload variables to set the $DOMAIN_APP_NAME in $WWWPATHHTML
set_vars

if [ -z "$POSTMASTER" ]; then
POSTMASTER=admin@$DOMAIN_APP_NAME
echo "
------------------------------
Enter the mail address for the alert receiver.

E.g.: $POSTMASTER
------------------------------"
read -r POSTMASTER
fi

MONITRC=/etc/monit/monitrc
sed -i -r -e "s/# set alert sysadm@foo.*/set alert $POSTMASTER # receive all alerts/" $MONITRC
sed -i -r -e "s/# set httpd port 2812 and/set httpd port 2812 and/" $MONITRC
sed -i "/httpd port 2812 and/aSSL ENABLE\nPEMFILE PEMFILE_REPLACE\nALLOWSELFCERTIFICATION" $MONITRC
sed -i -r -e "s,PEMFILE_REPLACE,$PEMFILE," $MONITRC
sed -i -r -e "s/#    use address localhost/use address 127.0.0.1/" $MONITRC
sed -i -r -e "s/#    allow localhost/allow 127.0.0.1/" $MONITRC
sed -i -r -e "s/#    allow admin:monit/allow $USER:$PASSWORD/" $MONITRC
sed -i -r -e "s/.*set mailserver.*/set mailserver $MAILSERVER/" $MONITRC


echo "
*********************************************
Writing default monit checks
*********************************************"


while true; do
  echo "
  ------------------------------
  Do you want to create basic MONIT configs?
  ------------------------------ [Y/n]"
  read -r yn
    case $yn in
        [Yy]* ) answer=true; break;;
        [Nn]* ) answer=false; break;;
        * ) echo "Please answer y or n.";;
    esac
done

if $answer; then
MONIT_CONF_DIR=/etc/monit/conf.d
echo "
check process amavisd with pidfile /var/run/amavis/amavisd.pid
every 5 cycles
group mail
start program = \"/etc/init.d/amavis start\"
stop  program = \"/etc/init.d/amavis stop\"
if failed port 10024 protocol smtp then restart
if 5 restarts within 25 cycles then timeout
" > $MONIT_CONF_DIR/amavis

echo "
check process nginx with pidfile /var/run/nginx.pid
group www
group nginx
start program = \"/etc/init.d/nginx start\"
stop program = \"/etc/init.d/nginx stop\"
if children > 255 for 5 cycles then alert
if cpu usage > 95% for 3 cycles then alert
check host $DOMAIN_APP_NAME with address $DOMAIN_APP_NAME
if failed port 443 protocol https with timeout 30 seconds then alert
if failed port 80 protocol http with timeout 30 seconds then alert
if 5 restarts within 5 cycles then timeout

depend nginx_bin
depend nginx_rc
check file nginx_bin with path /usr/sbin/nginx
group nginx
include /etc/monit/templates/rootbin

check file nginx_rc with path /etc/init.d/nginx
group nginx
include /etc/monit/templates/rootbin
" > $MONIT_CONF_DIR/nginx

echo "
check process dovecot with pidfile /var/run/dovecot/master.pid
group mail
start program = \"/etc/init.d/dovecot start\"
stop program = \"/etc/init.d/dovecot stop\"
group mail
# We'd like to use this line, but see:
# http://serverfault.com/questions/610976/monit-failing-to-connect-to-dovecot-over-ssl-imap
if failed port 993 type tcpssl protocol imap for 5 cycles then restart
# if failed port 993 for 5 cycles then restart
if 5 restarts within 25 cycles then timeout
" > $MONIT_CONF_DIR/dovecot

echo "
check process mysqld with pidfile /var/run/mysqld/mysqld.pid
group database
start program = \"/etc/init.d/mysql start\"
stop program = \"/etc/init.d/mysql stop\"
if failed host 127.0.0.1 port 3306 protocol mysql then restart
if 5 restarts within 5 cycles then timeout
" > $MONIT_CONF_DIR/mysql

echo "
check process postfix with pidfile /var/spool/postfix/pid/master.pid
group mail
start program = \"/etc/init.d/postfix start\"
stop  program = \"/etc/init.d/postfix stop\"
if failed port 25 protocol smtp then restart
if failed port 465 type tcpssl protocol smtp for 5 cycles then restart
if 5 restarts within 5 cycles then timeout
" > $MONIT_CONF_DIR/postfix

echo "
check process spamassassin with pidfile /var/run/spamassassin.pid
group mail
start program = \"service spamassassin start\"
stop  program = \"service spamassassin stop\"
if 5 restarts within 5 cycles then timeout
" > $MONIT_CONF_DIR/spamassassin

echo "
check process php-fpm with pidfile /var/run/php/php7.0-fpm.pid
group www-data #change accordingly
start program = \"/etc/init.d/php7.0-fpm start\"
stop program  = \"/etc/init.d/php7.0-fpm stop\"
if failed unixsocket $listen_pool then restart
if 3 restarts within 5 cycles then timeout
" > $MONIT_CONF_DIR/php-fpm

echo "
check process sshd with pidfile /var/run/sshd.pid
start program \"/etc/init.d/ssh start\"
stop program \"/etc/init.d/ssh stop\"
if failed host 127.0.0.1 port 22 protocol ssh then restart
if 5 restarts within 5 cycles then timeout
" > $MONIT_CONF_DIR/sshd

echo "create config to check the host system"
echo "
check system localhost
if loadavg (1min) > 8 then alert
if loadavg (5min) > 6 for 3 cycles then alert
if memory usage > 90% then alert
if cpu usage (user) > 80% then alert
if cpu usage (system) > 30% then alert
if cpu usage (wait) > 80% for 3 cycles then alert
" > $MONIT_CONF_DIR/system

echo "create config to check rsyslog service"
echo "
check process syslogd with pidfile /var/run/rsyslogd.pid
start program = \"/etc/init.d/rsyslog start\"
stop program = \"/etc/init.d/rsyslog stop\"

check file syslogd_file with path /var/log/syslog
if timestamp > 65 minutes then alert # Have you seen "-- MARK --"?
"  > $MONIT_CONF_DIR/rsyslog

echo "create config to check postgrey service"
echo '
check process postgrey with pidfile /var/run/postgrey.pid
group postgrey
start program = "/etc/init.d/postgrey start"
stop  program = "/etc/init.d/postgrey stop"
if failed host 127.0.0.1 port 10023 type tcp then restart
if 5 restarts within 5 cycles then timeout
' > $MONIT_CONF_DIR/postgrey

echo "create config to check opendmarc service"
echo '
check process opendmarc with pidfile /var/run/opendmarc/opendmarc.pid
group opendmarc
start program = "/etc/init.d/opendmarc start"
stop  program = "/etc/init.d/opendmarc stop"
if failed host 127.0.0.1 port 8892 type tcp then restart
if 5 restarts within 5 cycles then timeout
' > $MONIT_CONF_DIR/opendmarc

echo "create config to check opendkim service"
echo '
check process opendkim with pidfile /var/run/opendkim/opendkim.pid
group opendkim
start program = "/etc/init.d/opendkim start"
stop  program = "/etc/init.d/opendkim stop"
if failed host 127.0.0.1 port 8891 type tcp then restart
if 5 restarts within 5 cycles then timeout
' > $MONIT_CONF_DIR/opendkim

echo "create config to check cron"
echo '
# Cron
check process cron with pidfile /var/run/crond.pid
start program = "/etc/init.d/cron start"
stop  program = "/etc/init.d/cron stop"
group system
depends cron_init, cron_bin
check file cron_init with path /etc/init.d/cron
group system
check file cron_bin with path /usr/sbin/cron
group system
' > $MONIT_CONF_DIR/cron

echo "create config to check redis"
echo '
check process redis-server
with pidfile "/var/run/redis/redis-server.pid"
start program = "/etc/init.d/redis-server start"
stop program = "/etc/init.d/redis-server stop"
if 2 restarts within 3 cycles then timeout
if totalmem > 100 Mb then alert
if children > 255 for 5 cycles then stop
if cpu usage > 95% for 3 cycles then restart
if 5 restarts within 5 cycles then timeout
' > $MONIT_CONF_DIR/redis

echo "create config to check clamav"
echo '
check process clamavd
matching "clamd"
start program = "/etc/init.d/clamav-daemon start"
stop  program = "/etc/init.d/clamav-daemon stop"
if failed unixsocket /var/run/clamav/clamd.ctl then restart
if 5 restarts within 5 cycles then timeout
' > $MONIT_CONF_DIR/clamav

echo "create config to check free hard drive"
echo '
check device disk with path /
if SPACE usage > 80% for 8 cycles then alert
check device nfs with path /root/snapshot
if SPACE usage > 80% then alert
' > $MONIT_CONF_DIR/disk-space

echo "create config to check clamav"
echo '
check process unbound with pidfile /var/run/unbound.pid
group unbound
start program = "/etc/init.d/unbound start"
stop  program = "/etc/init.d/unbound stop"
if failed host 127.0.0.1 port 53 type tcp then restart
if 5 restarts within 5 cycles then timeout
' > $MONIT_CONF_DIR/unbound
fi

create_php_pool

create_nginx_vhost monit

echo "Set permissions to files and directories"
chown -R "$service_user":www-data "$WWWPATHHTML"/
find "$WWWPATHHTML" -type d -exec chmod 750 {} \;
find "$WWWPATHHTML" -type f -exec chmod 640 {} \;

start_service "monit nginx php7.0-fpm"
}

install_mailserver() {
echo "
*********************************************
Installing Mailserver
*********************************************"
set_hostname

if [ ! -z "$(which csf)" ]; then
echo "
------------------------------
Open at following ports
in CFS or UFW for the mailserver:
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
------------------------------"
fi

install_base_components

install_components "software-properties-common php7.0 php7.0-mcrypt php7.0-curl php7.0-gd php7.0-mbstring php-xml-parser php7.0-common php7.0-cli php7.0-json php7.0-readline php7.0-mysql"

create_base_dirs

DOMAIN_APP_NAME=mail.example.com
echo "
------------------------------
Enter a name for installation.
It can contain the domain/subdomain name.
The base installation directory would be then e.g. $WWWPATH/$DOMAIN_APP_NAME

E.g.: $DOMAIN_APP_NAME
------------------------------"
read -r DOMAIN_APP_NAME

# reload variables to set the $DOMAIN_APP_NAME in $WWWPATHHTML
set_vars

echo "
------------------------------
Enter the full path for the installation directory.
It will be used for the POSTFIXADMIN
The default is '$WWWPATH' followed by the entered name $DOMAIN_APP_NAME,
Per default a 'public_html' directory will be created for the application.

The default path would be then e.g.: $WWWPATHHTML
------------------------------"
read -r WWWPATHHTML
export WWWPATHHTML

if [ ! -d "$WWWPATHHTML" ]; then
  mkdir -p "$WWWPATHHTML"
fi

create_service_user postfixadmin

install_mysql

install_nginx

install_php_fpm

create_snakeoil_certs

create_dh_param

create_php_pool

create_nginx_vhost postfixadmin

install_postfix_and_co

install_postfixadmin skip_init

echo "Add vmail user"
useradd -r -u 150 -g mail -d /var/vmail -s /sbin/nologin -c "Virtual maildir handler" vmail
mkdir /var/vmail
chmod 770 /var/vmail
chown vmail:mail /var/vmail

configure_dovecot

configure_mail_security

start_service "clamav-daemon amavis spamassassin postgrey"

configure_postfix

configure_spf

configure_dkim

configure_dmarc

configure_sieve

configure_opensrsd

start_service "postfix spamassassin clamav-daemon amavis dovecot postgrey opendkim opendmarc postgrey"

echo "A lost comment from one of the pages
Great guide to get started with SPF/DKIM/DMARC, thanks!

It is however missing the AddAllSignatureResults setting for opendkim.conf. Without it only the first Authentication-Result header is parsed, and DMARC might not see the DKIM results. This is the default in opendkim 2.10.0, but jessie has 2.9.2 for now. http://sourceforge.net/p/opendkim/feature-requests/182/

Something that should probably be added is that Postfix skips the first header when passing mail to milters. So the Received-SPF header will get lost. See this discussion for a solution:
http://www.trusteddomain.org/pipermail/opendmarc-users/2014-September/000404.html
http://www.trusteddomain.org/pipermail/opendmarc-users/2014-September/000439.html

Another thing worth mentioning is the IgnoreAuthenticatedClients setting in opendmarc.conf to prevent flagging SMTP clients as failing DMARC. You do need opendmarc 1.3.1 (from stretch) though because of http://sourceforge.net/p/opendmarc/tickets/103/"

if [ ! -d $SCRIPTS_DIR ]; then
  mkdir -p $SCRIPTS_DIR
fi

echo "Write root password into file $SCRIPTS_DIR/m-r-pass.txt, delete it soon!"
echo "MYSQL ROOT Password is $MYSQL_ROOT_PASS" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
echo "Webmail Lite MYSQL DB PASSWORD is $MYSQL_DB_PASSWORD" >> $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt
chmod 600 $SCRIPTS_DIR/"$DOMAIN_APP_NAME"-pass.txt

echo "Installation succeded...
Press ENTER to finish"
Pause
}

configure_mail_security() {
echo "add clamav and amavis user to each others groups"
adduser clamav amavis
adduser amavis clamav

HOSTNAME=$(hostname)

echo "AllowSupplementaryGroups was removed from clamav"
# adjust clamav config
# echo "adjust clamav config"
# echo "
# # Needed to allow things to work with Amavis, when both amavis and clamav
# # users are added to one another's groups.
# AllowSupplementaryGroups true
# " >> /etc/clamav/clamd.conf

AMAVIS_CONF=/etc/amavis/conf.d/15-content_filter_mode
sed -i "s,#@bypass_virus_checks_maps,@bypass_virus_checks_maps," $AMAVIS_CONF
sed -i 's,#   \\%bypass_virus_checks,   \\%bypass_virus_checks,' $AMAVIS_CONF
sed -i "s,#@bypass_spam_checks_maps,@bypass_spam_checks_maps," $AMAVIS_CONF
sed -i 's,#   \\%bypass_spam_checks,   \\%bypass_spam_checks,' $AMAVIS_CONF

AMAVIS_DEFAULTS_CONF=/etc/amavis/conf.d/20-debian_defaults
sed -i "s,\$sa_spam_subject_tag.*,\$sa_spam_subject_tag = '***SPAM*** ';," $AMAVIS_DEFAULTS_CONF
sed -i "s,\$sa_tag_level_deflt.*,\$sa_tag_level_deflt  = undef;," $AMAVIS_DEFAULTS_CONF
sed -i "s,\$sa_tag2_level_deflt.*,\$sa_tag2_level_deflt = 5;," $AMAVIS_DEFAULTS_CONF
sed -i "s,\$sa_kill_level_deflt.*,\$sa_kill_level_deflt = 20;," $AMAVIS_DEFAULTS_CONF
sed -i "s,\$sa_dsn_cutoff_level.*,\$sa_dsn_cutoff_level = 10;   # spam level beyond which a DSN is not sent," $AMAVIS_DEFAULTS_CONF

if [ -z "$POSTMASTER" ]; then
POSTMASTER=admin@$DOMAIN_APP_NAME
echo "
------------------------------
Enter the mail address for the postmaster.

E.g.: $POSTMASTER
------------------------------"
read -r POSTMASTER
fi

echo "amavis database connection to check for new mails"
AMAVIS_USER_ACCESS_CONF=/etc/amavis/conf.d/50-user
sed -i "s,#@bypass_virus_checks_maps,@bypass_virus_checks_maps," $AMAVIS_USER_ACCESS_CONF
sed -i -e '12,13d' $AMAVIS_USER_ACCESS_CONF

echo "
\$myauthservid = \"$HOSTNAME\";

@local_domains_acl = ( \"$HOSTNAME\", \"127.0.0.1\" );

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
   ['DBI:mysql:database=$MYSQL_DB_NAME;host=127.0.0.1;port=3306',
    '$MYSQL_DB_USER',
    '$MYSQL_DB_PASSWORD']);
\$sql_select_policy = 'SELECT domain from domain WHERE CONCAT(\"@\",domain) IN (%k)';

# Uncomment to bump up the log level when testing.
\$log_level = 2;
#\$sa_debug = 1;

\$hdrfrom_notify_sender = 'Postmaster $DOMAIN_APP_NAME <$POSTMASTER>';

#------------ Do not modify anything below this line -------------
1;  # ensure a defined return
" >> $AMAVIS_USER_ACCESS_CONF

# adtivate amavis
echo "activate spamassassin"
SAPMASSASSIN_CONF=/etc/default/spamassassin
sed -i 's,ENABLED=0,ENABLED=1,' $SAPMASSASSIN_CONF
sed -i 's,CRON=0,CRON=1,' $SAPMASSASSIN_CONF

echo "configure spamassassin"
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
" >> /etc/spamassassin/local.cf

ESCAPED_DOMAIN_APP_NAME=$(printf "%s" "$DOMAIN_APP_NAME" | sed 's|\.|\\\\\\.|g')
sed -i  "s;mail\\\.example\\\.com;$ESCAPED_DOMAIN_APP_NAME;g" /etc/spamassassin/local.cf

echo "Update ClamAV database"
freshclam

# Add Postgrey whitelists
echo "add postgrey whitelists"
echo "
POSTGREY_OPTS=\"\$POSTGREY_OPTS --whitelist-clients=/etc/postgrey/whitelist_clients\"
POSTGREY_OPTS=\"\$POSTGREY_OPTS --whitelist-recipients=/etc/postgrey/whitelist_recipients\"
" >> /etc/default/postgrey
}

configure_spf() {
install_components "postfix-policyd-spf-python"

sed -i "s,HELO_reject =.*,HELO_reject = False," /etc/postfix-policyd-spf-python/policyd-spf.conf
sed -i "s,Mail_From_reject =.*,Mail_From_reject = False," /etc/postfix-policyd-spf-python/policyd-spf.conf

postconf -e "policy-spf_time_limit = 3600s"
postconf -e "sender_bcc_maps = hash:/etc/postfix/bcc_map"
postconf -# "sender_bcc_maps"
postconf -e "always_bcc = postman@example.com"

echo "
# --------------------------------------
# SPF
# --------------------------------------
policy-spf  unix  -       n       n       -       -       spawn
     user=nobody argv=/usr/bin/policyd-spf
" >> /etc/postfix/master.cf
}

configure_dkim() {
install_components "opendkim opendkim-tools"

if [ -z "$POSTMASTER" ]; then
POSTMASTER=admin@$DOMAIN_APP_NAME
echo "
------------------------------
Enter the mail address for the postmaster.

E.g.: $POSTMASTER
------------------------------"
read -r POSTMASTER
fi

HOSTNAME=$(hostname)
OPENDKIM_CONF=/etc/opendkim.conf
sed -i "s,#Canonicalization.*,Canonicalization relaxed/simple," $OPENDKIM_CONF
sed -i "s,#Mode.*,Mode sv," $OPENDKIM_CONF
echo "
Domain *
KeyFile /etc/postfix/dkim.key
Selector dkim
SOCKET inet:8891@127.0.0.1" >> $OPENDKIM_CONF

echo "SOCKET=\"inet:8891@127.0.0.1\"" >> /etc/default/opendkim

postconf -e "milter_default_action = accept"
postconf -e "milter_protocol = 2"
postconf -e "smtpd_milters = inet:127.0.0.1:8891,inet:127.0.0.1:8892"
postconf -e "non_smtpd_milters = inet:127.0.0.1:8891,inet:127.0.0.1:8892"

opendkim-genkey -t -s dkim -d "$DOMAIN_APP_NAME"
mv dkim.private /etc/postfix/dkim.key
chmod 660 /etc/postfix/dkim.key
chown root:opendkim /etc/postfix/dkim.key

if [ ! -d $SCRIPTS_DIR ]; then
  mkdir -p $SCRIPTS_DIR
fi

cp /etc/postfix/dkim.key $SCRIPTS_DIR/
mv dkim.txt $SCRIPTS_DIR/
chmod 600 $SCRIPTS_DIR/dkim.txt $SCRIPTS_DIR/dkim.key

dkim_dns=$(sed -e 's/" ) ; -----.*//' -e 's/IN //' -e 's/( "//' -e 's/"//g' < $SCRIPTS_DIR/dkim.txt )

echo "
------------------------------
Enter an DNS TXT entry at
$dkim_dns

and an DNS TXT entry at
_adsp._domainkey
with content:
dkim=all

Press any key to continue.
------------------------------"
Pause
}

configure_dmarc() {
install_components opendmarc
HOSTNAME=$(hostname)
OPENDMARC_CONF=/etc/opendmarc.conf
sed -i "s,# AuthservID.*,AuthservID $HOSTNAME," $OPENDMARC_CONF
sed -i "s,# TrustedAuthservIDs.*,TrustedAuthservIDs HOSTNAME," $OPENDMARC_CONF

{
echo "HistoryFile /var/run/opendmarc/opendmarc.dat
IgnoreHosts /etc/opendmarc/ignore.hosts
IgnoreMailFrom $DOMAIN_APP_NAME

# For testing
SoftwareHeader true"
} >> $OPENDMARC_CONF

mkdir /etc/opendmarc/
echo "127.0.0.1" >> /etc/opendmarc/ignore.hosts
echo "$HOSTNAME" >> /etc/opendmarc/ignore.hosts
echo "SOCKET=\"inet:8892@127.0.0.1\"" >> /etc/default/opendmarc

if [ -z "$POSTMASTER" ]; then
  POSTMASTER=dmarc@$DOMAIN_APP_NAME
fi

echo "
------------------------------
Enter the mail address for dmarc report receiver.

E.g.: $POSTMASTER
------------------------------"
read -r DMARC_MAIL

echo "Now create a new database with name opendmarc,
or just choose an existing one
enter the usernane and the password"

create_mysql_db opendmarc

mysql -u"$MYSQL_DB_USER" -p"$MYSQL_DB_PASSWORD" -h"$MYSQL_HOST" < /usr/share/doc/opendmarc/schema.mysql

echo "
#!/bin/bash

DB_SERVER='$MYSQL_HOST'
DB_USER='$MYSQL_DB_USER'
DB_PASS='$MYSQL_DB_PASSWORD'
DB_NAME='opendmarc'
WORK_DIR='/var/run/opendmarc'
REPORT_EMAIL='$DMARC_MAIL'
REPORT_ORG='$HOSTNAME'

mv \${WORK_DIR}/opendmarc.dat \${WORK_DIR}/opendmarc_import.dat -f
cat /dev/null > \${WORK_DIR}/opendmarc.dat

/usr/sbin/opendmarc-import --dbhost=\${DB_SERVER} --dbuser=\${DB_USER} --dbpasswd=\${DB_PASS} --dbname=\${DB_NAME} --verbose < \${WORK_DIR}/opendmarc_import.dat
/usr/sbin/opendmarc-reports --dbhost=\${DB_SERVER} --dbuser=\${DB_USER} --dbpasswd=\${DB_PASS} --dbname=\${DB_NAME} --verbose --interval=86400 --report-email \$REPORT_EMAIL --report-org \$REPORT_ORG
/usr/sbin/opendmarc-expire --dbhost=\${DB_SERVER} --dbuser=\${DB_USER} --dbpasswd=\${DB_PASS} --dbname=\${DB_NAME} --verbose
" >> /etc/opendmarc/report_script

chmod +x /etc/opendmarc/report_script

echo "1 0 * * * opendmarc /etc/opendmarc/report-script" >> /etc/crontab

postconf -e "always_bcc = $POSTMASTER"


echo "
------------------------------
Enter an DNS TXT entry at
_dmarc.
with content:
v=DMARC1; p=quarantine; rua=mailto:$POSTMASTER; ruf=mailto:$POSTMASTER; fo=0; adkim=r; aspf=r; pct=100; rf=afrf; ri=86400

Press any key to continue.
------------------------------"
Pause
}

configure_sieve() {
echo "
*********************************************
Configuring sieve for dovecot
*********************************************"
install_components dovecot-sieve

sed -i "s,#mail_plugins =.*,mail_plugins = \$mail_plugins sieve," /etc/dovecot/conf.d/15-lda.conf
sed -i "s,#sieve_before =.*,sieve_before = /var/vmail/sieve/spam-global.sieve," /etc/dovecot/conf.d/90-sieve.conf
sed -i "s,sieve_dir =.*,sieve_dir = /var/vmail/%d/%n/sieve/scripts/," /etc/dovecot/conf.d/90-sieve.conf
sed -i "s,sieve =.*,sieve = /var/vmail/%d/%n/sieve/active-script.sieve," /etc/dovecot/conf.d/90-sieve.conf

mkdir -p /var/vmail/sieve

echo 'require "fileinto";
if header :contains "X-Spam-Flag" "YES" {
  fileinto "Spam";
}
' >> /var/vmail/sieve/spam-global.sieve

chown -R vmail:mail /var/vmail/sieve/

sievec /var/vmail/sieve/spam-global.sieve
}


configure_opensrsd() {
echo "
*********************************************
Configuring OpenSRSD
*********************************************"
# Dependencies.
install_components "unzip cmake"

# Download and extract source code from GitHub.
cd /tmp || echo 'Could not change directory to /tmp' #This should not happen as /tmp is a normally existend
curl -L -o postsrsd.zip https://github.com/roehling/postsrsd/archive/master.zip
unzip postsrsd.zip

# Build and install.
cd postsrsd-master || echo 'Could not change directory to /tmp/postsrsd-master'
mkdir build
cd build  || echo 'Could not change directory to /tmp/postsrsd-master/build'
cmake -DCMAKE_INSTALL_PREFIX=/usr ../
make
make install

postconf -e "sender_canonical_maps = tcp:127.0.0.1:10001"
postconf -e "sender_canonical_classes = envelope_sender"
postconf -e "recipient_canonical_maps = tcp:127.0.0.1:10002"
postconf -e "recipient_canonical_classes = envelope_recipient,header_recipient"

systemctl enable postsrsd

cd /tmp || echo 'Could not change directory to /tmp' #This should not happen as /tmp is a normally existend
if [ -f /tmp/postsrsd.zip ]; then
  rm -f /tmp/postsrsd.zip
fi

if [ -d /tmp/postsrsd-master ]; then
  rm -rf /tmp/postsrsd-master
fi

start_service postsrsd

}


configure_postfix() {
echo "
*********************************************
Configuring postfix
*********************************************"

echo "
user = $MYSQL_DB_USER
password = $MYSQL_DB_PASSWORD
hosts = 127.0.0.1
dbname = $MYSQL_DB_NAME
query = SELECT goto FROM alias,alias_domain
WHERE alias_domain.alias_domain = '%d'
AND alias.address=concat('%u', '@', alias_domain.target_domain)
AND alias.active = 1
" >> /etc/postfix/mysql_virtual_alias_domainaliases_maps.cf

echo "
user = $MYSQL_DB_USER
password = $MYSQL_DB_PASSWORD
hosts = 127.0.0.1
dbname = $MYSQL_DB_NAME
table = alias
select_field = goto
where_field = address
additional_conditions = and active = '1'
" >> /etc/postfix/mysql_virtual_alias_maps.cf

echo "
user = $MYSQL_DB_USER
password = $MYSQL_DB_PASSWORD
hosts = 127.0.0.1
dbname = $MYSQL_DB_NAME
table = domain
select_field = domain
where_field = domain
additional_conditions = and backupmx = '0' and active = '1'
" >> /etc/postfix/mysql_virtual_domains_maps.cf

echo "
user = $MYSQL_DB_USER
password = $MYSQL_DB_PASSWORD
hosts = 127.0.0.1
dbname = $MYSQL_DB_NAME
query = SELECT maildir FROM mailbox, alias_domain
WHERE alias_domain.alias_domain = '%d'
AND mailbox.username=concat('%u', '@', alias_domain.target_domain )
AND mailbox.active = 1
" >> /etc/postfix/mysql_virtual_mailbox_domainaliases_maps.cf

echo "
user = $MYSQL_DB_USER
password = $MYSQL_DB_PASSWORD
hosts = 127.0.0.1
dbname = $MYSQL_DB_NAME
table = mailbox
select_field = CONCAT(domain, '/', local_part)
where_field = username
additional_conditions = and active = '1'
" >> /etc/postfix/mysql_virtual_mailbox_maps.cf

echo "
user = $MYSQL_DB_USER
password = $MYSQL_DB_PASSWORD
hosts = 127.0.0.1
dbname = $MYSQL_DB_NAME
query = SELECT goto FROM alias WHERE address='%s'
" >> /etc/postfix/mysql_virtual_sender_login_maps.cf

# contains some directives to remove certain headers when relaying mail.
echo "contains some directives to remove certain headers when relaying mail."
echo "
/^Received:/                 IGNORE
/^User-Agent:/               IGNORE
/^X-Mailer:/                 IGNORE
/^X-Originating-IP:/         IGNORE
/^x-cr-[a-z]*:/              IGNORE
/^Thread-Index:/             IGNORE
" >> /etc/postfix/header_checks

# download main.cf fro postfix from github
POSTFIX_CONF=/etc/postfix/main.cf
mv $POSTFIX_CONF $POSTFIX_CONF.orig
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/template_main.cf -O $POSTFIX_CONF
sed -i "s,myhostname = mail.example.com,myhostname = $DOMAIN_APP_NAME," $POSTFIX_CONF
sed -i "s,^smtpd_tls_cert_file=.*,smtpd_tls_cert_file=$CERTS_PATH/$KEY_COMMON_NAME.crt," $POSTFIX_CONF
sed -i "s,^smtpd_tls_key_file=.*,smtpd_tls_key_file=$CERTS_PATH/$KEY_COMMON_NAME.key," $POSTFIX_CONF
sed -i "s,# smtpd_tls_cert_file=.*,# smtpd_tls_cert_file=$CERTS_PATH/www.$DOMAIN_PART/fullchain.pem," $POSTFIX_CONF
sed -i "s,# smtpd_tls_key_file=.*,# smtpd_tls_key_file=$CERTS_PATH/www.$DOMAIN_PART/privkey.pem," $POSTFIX_CONF
sed -i "s,# smtpd_tls_CAfile=.*,# smtpd_tls_CAfile=$CERTS_PATH/www.$DOMAIN_PART/chain.pem," $POSTFIX_CONF
sed -i "s,^smtpd_tls_dh1024_param_file =.*,smtpd_tls_dh1024_param_file = $CERTS_PATH/${DOMAIN_PART}_dhparams.pem," $POSTFIX_CONF

postconf -e "smtpd_tls_auth_only = no"

# ====================
# TLSA DANE support
# -------------------
postconf -# "smtp_tls_security_level"
postconf -e "smtp_tls_security_level = dane"
postconf -e "smtpd_use_tls = yes"
postconf -e "smtp_use_tls = yes"
postconf -e "smtp_dns_support_level = dnssec"
postconf -e "smtp_tls_loglevel = 1"


# download master.cf fro postfix from github
mv /etc/postfix/master.cf /etc/postfix/master.cf.orig
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/template_master.cf  -O /etc/postfix/master.cf

# recommendation regarding postfix configuration file
echo "Please check the Postfix configuration later"
}

configure_dovecot() {
echo "
*********************************************
Configuring dovecot
*********************************************"

echo "Dovecot configuration"
DOVECOT_CONF=/etc/dovecot/dovecot-sql.conf.ext
sed -i "s,#driver =.*,driver = mysql," $DOVECOT_CONF
sed -i "s,#connect =.*,connect = host=127.0.0.1 dbname=$MYSQL_DB_NAME user=$MYSQL_DB_USER password=$MYSQL_DB_PASSWORD," $DOVECOT_CONF
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
DOVECOT_AUTH_CONF=/etc/dovecot/conf.d/10-auth.conf
sed -i "s,#disable_plaintext_auth =.*,disable_plaintext_auth = yes," $DOVECOT_AUTH_CONF
sed -i "s,auth_mechanisms =.*,auth_mechanisms = plain login," $DOVECOT_AUTH_CONF
sed -i 's,!include auth-system.conf.ext.*,#!include auth-system.conf.ext,' $DOVECOT_AUTH_CONF
sed -i 's,#!include auth-sql.conf.ext.*,!include auth-sql.conf.ext,' $DOVECOT_AUTH_CONF

# tell Dovecot where to put the virtual user mail directories.
echo "tell Dovecot where to put the virtual user mail directories."
DOVECOT_VMAIL_CONF=/etc/dovecot/conf.d/10-mail.conf
sed -i "s,^mail_location =.*,mail_location = maildir:/var/vmail/%d/%n," $DOVECOT_VMAIL_CONF
sed -i "s,^mail_location =.*,mail_location = maildir:/var/vmail/%d/%n," $DOVECOT_VMAIL_CONF
sed -i "s,#mail_uid =.*,mail_uid = vmail," $DOVECOT_VMAIL_CONF
sed -i "s,#mail_gid =.*,mail_gid = mail," $DOVECOT_VMAIL_CONF
sed -i "s,#last_valid_uid =.*,last_valid_uid = 150," $DOVECOT_VMAIL_CONF
sed -i "s,#first_valid_uid =.*,first_valid_uid = 150," $DOVECOT_VMAIL_CONF

# ensure that some SSL protocols that are no longer secure are not used
echo "ensure that some SSL protocols that are no longer secure are not used"
DOVECOT_SSL_CONF=/etc/dovecot/conf.d/10-ssl.conf
sed -i "s,ssl = no.*,ssl = yes," $DOVECOT_SSL_CONF
sed -i "s,#ssl_cert =.*,ssl_cert = <$CERTS_PATH/$KEY_COMMON_NAME.crt," $DOVECOT_SSL_CONF
sed -i "s,#ssl_key =.*,ssl_key = <$CERTS_PATH/$KEY_COMMON_NAME.key," $DOVECOT_SSL_CONF
echo "set the ssl_ca = when using letsencrypt in $DOVECOT_SSL_CONF"
sed -i "s,#ssl_dh_parameters_length =.*,ssl_dh_parameters_length = 2048," $DOVECOT_SSL_CONF
sed -i 's,#ssl_protocols =.*,ssl_protocols = !SSLv2 !SSLv3,' $DOVECOT_SSL_CONF
sed -i "s,#ssl_prefer_server_ciphers =.*,ssl_prefer_server_ciphers = yes," $DOVECOT_SSL_CONF
sed -i 's,#ssl_cipher_list =.*,ssl_cipher_list = ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA,' $DOVECOT_SSL_CONF

# add the Postfix option
echo "add the Postfix option"
DOVECOT_MASTER_CONF=/etc/dovecot/conf.d/10-master.conf
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

echo "Add auto subscribe to junk and archive mailbox"
DOVECOT_MASTER_CONF=/etc/dovecot/conf.d/15-mailboxes.conf
sed -i "/mailbox Junk {/i   mailbox Archive { \\
auto = subscribe \\
special_use = \\\Archive \\
}" $DOVECOT_MASTER_CONF

sed -i "/mailbox Junk {/a auto = subscribe" $DOVECOT_MASTER_CONF

perl -i -p0e 's/#unix_listener \/var\/spool\/postfix\/private\/auth {.*?}/unix_listener \/var\/spool\/postfix\/private\/auth {
mode = 0666
# Assuming the default Postfix user and group
user = postfix
group = postfix
}/s' $DOVECOT_MASTER_CONF

if [ -z "$POSTMASTER" ]; then
POSTMASTER=admin@$DOMAIN_APP_NAME
echo "
------------------------------
Enter the mail address for the postmaster.

E.g.: $POSTMASTER
------------------------------"
read -r POSTMASTER
fi

echo "
# Address to use when sending rejection mails.
# Default is postmaster@<your domain>.
postmaster_address = $POSTMASTER
" >> /etc/dovecot/conf.d/15-lda.conf

# set permissions for dovecot configuration
echo "set permissions for dovecot configuration"
chown -R vmail:dovecot /etc/dovecot
chmod -R o-rwx /etc/dovecot
}

install_postfix_and_co() {
echo "postfix postfix/mailname string $HOSTNAME" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections

install_components "mutt postfix libexttextcat-data liblockfile-bin gnupg-agent libksba8 libexttextcat-2.0-0 libgpgme11 libwrap0 dovecot-imapd libassuan0 ssl-cert dovecot-pop3d dirmngr ntpdate dovecot-core tcpd gnupg2 liblockfile1 pinentry-curses libnpth0 procmail libtokyocabinet9 bsd-mailx"

install_components "postfix-mysql dovecot-mysql postgrey amavis clamav clamav-daemon spamassassin libdbi-perl libdbd-mysql-perl php7.0-imap"

install_components "pyzor razor arj cabextract lzop nomarch p7zip-full ripole rpm2cpio tnef unzip unrar-free zip zoo"
}

install_postfixadmin() {
echo "
*********************************************
Installing postfixadmin
*********************************************"
SOFTWARE_URL=http://downloads.sourceforge.net/project/postfixadmin/postfixadmin/postfixadmin-2.93/postfixadmin-2.93.tar.gz
SOFTWARE_ZIP=$(basename $SOFTWARE_URL)
SOFTWARE_DIR=$(printf "%s" "$SOFTWARE_ZIP" | sed -e 's/.tar.gz//')

if [ "$1" != "skip_init" ]; then
install_base_components

install_components "software-properties-common php7.0 php7.0-mcrypt php7.0-curl php7.0-gd php7.0-mbstring php-xml-parser php7.0-common php7.0-cli php7.0-json php7.0-readline php7.0-mysql"

create_base_dirs

if [ -z "$DOMAIN_APP_NAME" ]; then
DOMAIN_APP_NAME=mail.example.com
echo "
------------------------------
Enter a name for installation.
It can contain the domain/subdomain name.
The base installation directory would be then e.g. $WWWPATH/$DOMAIN_APP_NAME

E.g.: $DOMAIN_APP_NAME
------------------------------"
read -r DOMAIN_APP_NAME
fi

# reload variables to set the $DOMAIN_APP_NAME in $WWWPATHHTML
set_vars

if [ -z "$WWWPATHHTML" ]; then
echo "
------------------------------
Enter the full path for the installation directory.
It will be used for the POSTFIXADMIN
The default is '$WWWPATH' followed by the entered name $DOMAIN_APP_NAME,
Per default a 'public_html' directory will be created for the application.

The default path would be then e.g.: $WWWPATHHTML
------------------------------"
read -r WWWPATHHTML
fi

if [ ! -d "$WWWPATHHTML" ];then
  mkdir -p "$WWWPATHHTML"
fi

install_mysql

install_nginx

install_php_fpm

create_snakeoil_certs

create_dh_param

create_php_pool

create_nginx_vhost postfixadmin
fi

create_mysql_db postfixadmin

start_service "mysql php7.0-fpm nginx"

echo "Copy application files"
cd /tmp || echo 'Could not change directory to /tmp' #This should not happen as /tmp is a normally existend
wget $SOFTWARE_URL
tar -xf /tmp/"$SOFTWARE_ZIP"
mv "$SOFTWARE_DIR" "$WWWPATHHTML"/postfixadmin
chown -R "$service_user":www-data "$WWWPATHHTML"/postfixadmin
[ -f /tmp/"$SOFTWARE_ZIP" ] && rm -f /tmp/"$SOFTWARE_ZIP"

echo "create new empty postfix local config file"
POSTFIXADM_CONF_FILE=$WWWPATHHTML/postfixadmin/config.local.php
touch "$POSTFIXADM_CONF_FILE"
chown "$service_user":www-data "$POSTFIXADM_CONF_FILE"

echo "download postfixadmin template"
wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/configs/postfixadmin.config.local.php -O "$POSTFIXADM_CONF_FILE"

if [ -z "$POSTMASTER" ]; then
POSTMASTER=admin@$DOMAIN_APP_NAME
echo "
------------------------------
Enter the mail address for the postmaster.

E.g.: $POSTMASTER
------------------------------"
read -r POSTMASTER
fi

echo "adjust postfixadmin template config"
sed -i "s,.*'postfix_admin_url'.*,\$CONF['postfix_admin_url'] = 'https://$DOMAIN_APP_NAME/postfixadmin';," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'database_user'.*,\$CONF['database_user'] = '$MYSQL_DB_USER';," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'database_password'.*,\$CONF['database_password'] = '$MYSQL_DB_PASSWORD';," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'database_name'.*,\$CONF['database_name'] = '$MYSQL_DB_NAME';," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'admin_email'.*,\$CONF['admin_email'] = '$POSTMASTER';," "$POSTFIXADM_CONF_FILE"
sed -i "s,'admin@example.com','$POSTMASTER'," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'footer_text'.*,\$CONF['footer_text'] = 'Return to $DOMAIN_APP_NAME';," "$POSTFIXADM_CONF_FILE"
sed -i "s,.*'footer_link'.*,\$CONF['footer_link'] = 'https://$DOMAIN_APP_NAME';," "$POSTFIXADM_CONF_FILE"

mysql --version | awk '{ print $5 }'
MYSQLVERSION=$(mysql --version | awk '{ print $5 }' | cut -c 1-3)
if [ "$MYSQLVERSION" = "5.5" ];
        then
        sed -i 's/"FROM_BASE64(###KEY###)"/"###KEY###"/' "$WWWPATHHTML"/postfixadmin/model/PFAHandler.php
fi

# Read website setup generate hash
echo "visit https://$DOMAIN_APP_NAME/postfixadmin/setup.php enter the password and copy the generated has here and press RETURN"
read -r SETUP_HASH
echo "
// In order to setup Postfixadmin, you MUST specify a hashed password here.
// To create the hash, visit setup.php in a browser and type a password into the field,
// on submission it will be echoed out to you as a hashed value.
\$CONF['setup_password'] = '$SETUP_HASH';
" >> "$POSTFIXADM_CONF_FILE"
unset SETUP_HASH

echo "Continue to create postfixadmin superuser on https://$DOMAIN/postfixadmin/setup.php and press RETURN when you finished
The setup.php page will be inaccessible after that."
Pause
sed -i "/.*\* \^\/postfixadmin.*/i location = \/postfixadmin\/setup.php { \
deny all; \
access_log off; \
log_not_found off; \
}" "$VHOST_CONF_PATH"

start_service nginx
}

create_basic_auth() {
COMPONENT_NAME=$1

while true; do
  echo "
  ------------------------------
  Do you want to create basic auth password for $COMPONENT_NAME? (y/n)
  ------------------------------ [Y/n]"
  read -r yn
    case $yn in
        [Yy]* ) answer=true; break;;
        [Nn]* ) answer=false; break;;
        * ) echo "Please answer y or n.";;
    esac
done

if $answer; then
auth_passwd_file_name=
echo "
------------------------------
Please enter a name for the password file, it will be written into /etc/nginx/
------------------------------"
read -r auth_passwd_file_name

auth_passwd_user=
echo "
------------------------------
Please enter the username you want to use for the authentication
------------------------------"
read -r auth_passwd_user

htpasswd -c /etc/nginx/."$auth_passwd_file_name" "$auth_passwd_user"

BASIC_AUTH_ACTIVE="
auth_basic \"Restricted\";
auth_basic_user_file /etc/nginx/.${auth_passwd_file_name};"
fi
}

create_service_user() {
echo "
***************
Addding a service user to the system
***************"
service_user=$1
echo "
------------------------------
Enter a name for the service user,
Typically the user will be owner of a php-fpm pool,
and is owner of the data files in the $WWWPATHHTML directory.
It can also be added to groups, e.g. the www-data group in the next step.
E.g.: $service_user
------------------------------"
read -r service_user
echo "create service user $service_user"
useradd -M "$service_user"
usermod -L "$service_user"
}

add_user_to_group() {
echo "
*********************************************
Adding a user to a group
*********************************************"
service_user=$1
user_group="$2"

if [ -z "$service_user" ]; then
  echo "
  ------------------------------
  Enter the username of the service user which should be added to a group.
  The user should already exist.

  E.g.: $service_user
  ------------------------------
  "
read -r service_user
fi

echo "
------------------------------
Enter ONE or MORE groups the user '$service_user' should be added to.
Like the www-data or redis group.
Given the user should read files with group permissions	for another php pool,
then add the user to that php pool.

Comma separated list of groups.
E.g.: $user_group
------------------------------"
read -r user_group

usermod -aG "$user_group" "$service_user"
}

create_base_dirs() {
echo "
*********************************************
Creating directory for application
*********************************************"
if [ ! -d $WWWLOGDIR ]; then
  mkdir -p $WWWLOGDIR
fi

if [ ! -d $CERTS_PATH ]; then
  mkdir -p $CERTS_PATH
fi

if [ ! -d $WWWPATH ]; then
  mkdir -p $WWWPATH
fi

if [ ! -d $PERMISSIONFILES ]; then
  mkdir -p $PERMISSIONFILES
fi
}

create_dh_param() {
echo "
*********************************************
Creating diffie-helman key
*********************************************"
DOMAIN_PART=$DOMAIN_APP_NAME
if [ -z "$DOMAIN_PART" ]; then
  echo "
  ------------------------------
  Please enter the domain for the DHPARAM
  ------------------------------

  E.g.: example.com
  "
  read -r DOMAIN_PART;
fi

if [ ! -d $CERTS_PATH ]; then
  printf "Create %s, press return to continue." "$CERTS_PATH"
  Pause
  mkdir -p $CERTS_PATH
fi
openssl dhparam -out $CERTS_PATH/"${DOMAIN_PART}"_dhparams.pem 2048
printf "Set file permission 600 for %s/%s_dhparams.pem, press return to continue" "$CERTS_PATH" "${DOMAIN_PART}"
Pause
chmod 600 $CERTS_PATH/"${DOMAIN_PART}"_dhparams.pem
}

create_snakeoil_certs() {
echo "
*********************************************
Creating snakeoil certificate
*********************************************"

while true; do
  echo "
  ------------------------------
  Do you want to create a snakeoil certificate for testing?
  ------------------------------ [Y/n]"
  read -r yn
    case $yn in
        [Yy]* ) answer=true; break;;
        [Nn]* ) answer=false; break;;
        * ) echo "Please answer y or n.";;
    esac
done

if $answer; then
if [ ! -d $SCRIPTS_DIR ]; then
  mkdir -p $SCRIPTS_DIR
fi
if [ ! -f $SCRIPTS_DIR/manage_certs.sh ]; then
  wget https://raw.githubusercontent.com/blacs30/installation-scripts/master/manage_certs.sh -O $SCRIPTS_DIR/manage_certs.sh
fi

. "${SCRIPTS_DIR}/manage_certs.sh" read_config

if [ ! -d $CERTS_PATH ]; then
  printf "Create certificates directory at %s, return to continue." "$CERTS_PATH"
  Pause
  mkdir -p $CERTS_PATH
fi
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096  \
-subj "/C=$COUNTRYNAME/ST=$PROVINCENAME/L=$KEY_LOCATION/O=$KEY_ORGANIZATION/OU=$KEY_OUN/CN=$KEY_COMMON_NAME/emailAddress=$KEY_MAIL" \
-keyout $CERTS_PATH/"$KEY_COMMON_NAME".key \
-out $CERTS_PATH/"$KEY_COMMON_NAME".crt

printf "Set file permission 600 for %s/%s.key, press return to continue" "$CERTS_PATH" "$KEY_COMMON_NAME"
Pause
chmod 600 $CERTS_PATH/"$KEY_COMMON_NAME".key
fi
}

write_base_vhost_part() {
cat << BASE_VHOST_PART >> "$VHOST_CONF_PATH"

server {
listen 		80;
# enforce https
server_name     $ALL_DOMAINS;
location ~ .well-known/acme-challenge/ {
root 						$LE_KNOWN_DIR;
default_type 		text/plain;
}
location / {
return 301 https://\$server_name\$request_uri;
}
}

server {
listen 					443 ssl http2;
listen          [::]:443 ssl http2;
server_name    	$ALL_DOMAINS;
root   					$WWWPATHHTML;
access_log     	$WWWLOGDIR/$DOMAIN_PART-access.log;
error_log      	$WWWLOGDIR/$DOMAIN_PART-error.log warn;

ssl    									on;
ssl_certificate        	$SSL_CERT;
#ssl_certificate        $CERTS_PATH/www.$DOMAIN_PART/fullchain.pem;
ssl_certificate_key    	$SSL_KEY;
#ssl_certificate_key    $CERTS_PATH/www.$DOMAIN_PART/privkey.pem;
ssl_dhparam    		      $CERTS_PATH/${DOMAIN_PART}_dhparams.pem;

include			            global/secure_ssl.conf;

BASE_VHOST_PART
}

check_vhost_create_vars() {
if [ -z "$KEY_COMMON_NAME" ]; then
  KEY_COMMON_NAME=$DOMAIN_PART
fi

WWWPATHHTML=$WWWPATH/$DOMAIN_APP_NAME/public_html
echo "
------------------------------
Please enter the web root directory for this vhost,
it will be created in case it doesn't exist

E.g.: $WWWPATHHTML
------------------------------"
read -r WWWPATHHTML

if [ ! -d "$WWWPATHHTML" ]; then
  mkdir -p "$WWWPATHHTML"
fi

ALL_DOMAINS=
echo "
------------------------------
Please enter all domains which this vhost should listen for (space separated):

E.g.: $DOMAIN_PART www.$DOMAIN_PART
------------------------------"
read -r ALL_DOMAINS

LE_KNOWN_DIR=/var/www/letsencrypt
if [ ! -d $LE_KNOWN_DIR ]; then
  mkdir $LE_KNOWN_DIR
fi

SSL_KEY=$CERTS_PATH/$KEY_COMMON_NAME.key
if [ ! -f "$SSL_KEY" ]; then
  echo "
  ------------------------------
  Please enter the full path for the location of the ssl certificate key.

  E.g.: $SSL_KEY
  ------------------------------
  "
  read -r SSL_KEY;
fi

SSL_CERT=$CERTS_PATH/$KEY_COMMON_NAME.crt
if [ ! -f "$SSL_CERT" ]; then
  echo "
  ------------------------------
  Please enter the full path for the location of the ssl certificate.

  E.g.: $SSL_CERT
  ------------------------------
  "
  read -r SSL_CERT;
fi

while true; do
  echo "
  ------------------------------
  Do you want to create an upstream to a php unix socket or port?
  ------------------------------ [Y/n]"
  read -r yn
    case $yn in
        [Yy]* )
        create_upstream=true
        php_pool_text="php upstream pool which will be created."
        break;;
        [Nn]* )
        create_upstream=false
        php_pool_text="existing php upstream pool."
        break;;
        * ) echo "Please answer y or n.";;
    esac
done
}

write_administrative_base_vhost_part() {

echo "Creating administrative VHOST"
cat << ADMINISTRATIVE_VHOST >> "$VHOST_CONF_PATH"

# Additional rules go here.
include        		      global/restrictions.conf;
index                   index.php;

# if (\$allow_visit = no) { return 403 };

# Make sure files with the following extensions do not get loaded by nginx because nginx would display the source code, and these files can contain PASSWORDS!
location ~* \.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|tpl(\.php)?|xtmpl)$|^(\..*|Entries.*|Repository|Root|Tag|Template)$|\.php_ {
deny all;
}

location ~*  \.(jpg|jpeg|png|gif|css|js|ico)$ {
expires max;
log_not_found off;
}

location ~ \.php$ {
try_files \$uri =404;
include /etc/nginx/fastcgi_params;
fastcgi_pass $pool_name;
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
}
}
ADMINISTRATIVE_VHOST

}

check_vhost_base_vars() {
if [ -z "$VHOST_CONF_PATH" ]; then
  echo "
  --------------
  Enter the full path and name for your VHOST configuration file.
  $([ -d "$VHOST_CONF_DIR"/ ] && echo "Following VHOSTs are existing:" && find "$VHOST_CONF_DIR"/ -type f -printf "%f\n" | sed -e 's/.*/- &/g')

  E.g.: $VHOST_CONF_DIR/$VHOST_CONF_FILE
  ------------------------------
  "
  read -r VHOST_CONF_PATH
fi

if [ -z "$pool_name" ]; then
  pool_name=$service_user
fi

echo "
------------------------------
Please enter the name of the php pool.
$([ -d /etc/php/7.0/fpm/pool.d/ ] && echo "Following php pools are existing:" && find /etc/php/7.0/fpm/pool.d/ -type f -printf "%f\n" | sed -e 's/\(.*\)\..*/\1/' -e 's/.*/- &/g')

E.g.: $pool_name
------------------------------"
read -r pool_name
}

write_wordpress_vhost_part() {

echo "Creating Wordpress VHOST"
cat << WP_VHOST_CREATE >> "$VHOST_CONF_PATH"

# Additional rules go here.
include        	global/restrictions.conf;
include        	global/wordpress.conf;

client_max_body_size    40M;
index  									index.php;

location = /xmlrpc.php {
deny all;
access_log off;
log_not_found off;
}

# Pass all .php files onto a php-fpm/php-fcgi server.
location ~ [^/]\.php(/|$) {
fastcgi_split_path_info ^(.+?\.php)(/.*)$;
try_files \$uri \$uri/ /index.php?args;
include fastcgi.conf;
fastcgi_index index.php;
#      fastcgi_intercept_errors on;
fastcgi_pass $pool_name;
}

# Secure wp-login.php requests
location = /wp-login.php {
# if (\$allow_visit = no) { return 403 };

fastcgi_split_path_info ^(.+?\.php)(/.*)$;
try_files \$uri \$uri/ /index.php?args;
include fastcgi.conf;
fastcgi_index index.php;
#      fastcgi_intercept_errors on;
fastcgi_pass $pool_name;
}

# Secure /wp-admin requests
location ~ ^wp-admin {
# if (\$allow_visit = no) { return 403 };
}

# Secure /wp-admin requests (allow admin-ajax.php)
location ~* ^/wp-admin/admin-ajax.php$ {

fastcgi_split_path_info ^(.+?\.php)(/.*)$;
try_files \$uri \$uri/ /index.php?args;
include fastcgi.conf;
fastcgi_index index.php;
#      fastcgi_intercept_errors on;
fastcgi_pass $pool_name;
}

# Secure /wp-admin requests (.php files)
location ~* ^/wp-admin/.*\.php {

# if (\$allow_visit = no) { return 403 };

fastcgi_split_path_info ^(.+?\.php)(/.*)$;
try_files \$uri \$uri/ /index.php?args;
include fastcgi.conf;
fastcgi_index index.php;
#      fastcgi_intercept_errors on;
fastcgi_pass $pool_name;
}
}
WP_VHOST_CREATE

}

write_bbs_vhost_part() {

echo "Creating BBS VHOST"
cat << BBS_VHOST >> "$VHOST_CONF_PATH"

# Additional rules go here.
include                 global/restrictions.conf;

# if (\$allow_visit = no) { return 403 };

location / {
rewrite ^/(img/.*)$ /\$1 break;
rewrite ^/(js/.*)$ /\$1 break;
rewrite ^/(style/.*)$ /\$1 break;
rewrite ^/$ /index.php last;
rewrite ^/(admin|authors|authorslist|login|logout|metadata|search|series|serieslist|tags|tagslist|titles|titleslist|opds)/.*$ /index.php last;
}

location ~* \.(?:ico|css|js|gif|jpe?g|png|ttf|woff|svg|eot)$ {
# Some basic cache-control for static files to be sent to the browser
expires max;
add_header Pragma public;
add_header Cache-Control "public, must-revalidate, proxy-revalidate";
}

location ~ \.php$ {
try_files \$uri \$uri/ /index.php;
include fastcgi.conf;
fastcgi_pass   $pool_name;
}
}
BBS_VHOST

}

write_phpmyadmin_vhost_part() {

create_basic_auth PHPMYADMIN

sed -i -e '1h;1!H;$!d;g;s/\(.*\)}/\1/' "$VHOST_CONF_PATH"
cat << PHPMYADMIN_PART >> "$VHOST_CONF_PATH"
location /phpmyadmin {
$BASIC_AUTH_ACTIVE
index index.php index.html index.htm;
location ~ ^/phpmyadmin/(.+\.php)\$ {
try_files \$uri =404;
fastcgi_param HTTPS on;
fastcgi_pass $pool_name;
fastcgi_index index.php;
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
include /etc/nginx/fastcgi_params;
}
location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
}
}

location /phpMyAdmin {
rewrite ^/* /phpmyadmin last;
}
}
PHPMYADMIN_PART

}

write_monit_vhost_part() {

sed -i -e '1h;1!H;$!d;g;s/\(.*\)}/\1/' "$VHOST_CONF_PATH"

cat << MONIT_PART >> "$VHOST_CONF_PATH"
location /monit/ {
rewrite ^/monit/(.*) /\$1 break;
proxy_ignore_client_abort on;
proxy_pass   https://127.0.0.1:2812/;
proxy_redirect  https://127.0.0.1:2812/ /monit;
}
}
MONIT_PART

}

write_postfixadmin_vhost_part() {

create_basic_auth POSTFIXADMIN

sed -i -e '1h;1!H;$!d;g;s/\(.*\)}/\1/' "$VHOST_CONF_PATH"
cat << POSTFIXADMIN_PART >> "$VHOST_CONF_PATH"
location /postfixadmin {
$BASIC_AUTH_ACTIVE
index index.php index.html index.htm;
location ~ ^/postfixadmin/(.+\.php)$ {
try_files \$uri =404;
fastcgi_param HTTPS on;
fastcgi_pass $pool_name;
fastcgi_index index.php;
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
include /etc/nginx/fastcgi_params;
}
location ~* \.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|tpl(\.php)?|xtmpl)$|^(\..*|Entries.*|Repository|Root|Tag|Template)$|\.php_ {
deny all;
}
location ~* ^/postfixadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
}
}
}
POSTFIXADMIN_PART

}

write_owncloud_vhost_part() {

echo "Creating owncloud or nextcloud VHOST"
cat << OC_VHOST >> "$VHOST_CONF_PATH"

# Additional rules go here.

# if (\$allow_visit = no) { return 403 };

add_header X-Content-Type-Options nosniff;
add_header X-Frame-Options "SAMEORIGIN";
add_header X-XSS-Protection "1; mode=block";
add_header X-Robots-Tag none;
add_header X-Download-Options noopen;
add_header X-Permitted-Cross-Domain-Policies none;

location = /robots.txt {
allow all;
log_not_found off;
access_log off;
}

# The following 2 rules are only needed for the user_webfinger app.
# Uncomment it if you're planning to use this app.
#rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
#rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json last;

location = /.well-known/carddav {
return 301 \$scheme://\$host/remote.php/dav;
}
location = /.well-known/caldav {
return 301 \$scheme://\$host/remote.php/dav;
}

# Location for letsencrypt webserver check
location /.well-known/acme-challenge { }

# set max upload size
client_max_body_size 4096M;
fastcgi_buffers 64 4K;

# Disable gzip to avoid the removal of the ETag header
gzip off;

# Uncomment if your server is build with the ngx_pagespeed module
# This module is currently not supported.
# pagespeed off;
error_page 403 /core/templates/403.php;
error_page 404 /core/templates/404.php;

location / {
rewrite ^ /index.php\$uri;
}

location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
deny all;
}
location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {
deny all;
}

location ~ ^/(?:index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|ocs-provider/.+|core/templates/40[34])\.php(?:$|/) {
fastcgi_split_path_info ^(.+\.php)(/.*)$;
include fastcgi_params;
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
fastcgi_param PATH_INFO \$fastcgi_path_info;
fastcgi_param HTTPS on;
#Avoid sending the security headers twice
fastcgi_param modHeadersAvailable true;
fastcgi_param front_controller_active true;
fastcgi_pass $pool_name;
fastcgi_intercept_errors on;
fastcgi_request_buffering off;
}

location ~ ^/(?:updater|ocs-provider)(?:$|/) {
try_files \$uri/ =404;
index index.php;
}

# Adding the cache control header for js and css files
# Make sure it is BELOW the PHP block
location ~* \.(?:css|js)$ {
try_files \$uri /index.php\$uri\$is_args\$args;
add_header Cache-Control "public, max-age=7200";
# Add headers to serve security related headers (It is intended to have those duplicated to the ones above)
# Before enabling Strict-Transport-Security headers please read into this topic first.
# add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;";
add_header X-Content-Type-Options nosniff;
add_header X-Frame-Options "SAMEORIGIN";
add_header X-XSS-Protection "1; mode=block";
add_header X-Robots-Tag none;
add_header X-Download-Options noopen;
add_header X-Permitted-Cross-Domain-Policies none;
# Optional: Don't log access to assets
access_log off;
}

location ~* \.(?:svg|gif|png|html|ttf|woff|ico|jpg|jpeg)$ {
try_files \$uri /index.php\$uri\$is_args\$args;
# Optional: Don't log access to other assets
access_log off;
}
}
OC_VHOST

}

write_webmail_vhost_part() {

echo "Creating Webmail lite VHOST"
create_basic_auth WEBMAIL_ADMINPANEL
cat << WEBMAIL_VHOST >> "$VHOST_CONF_PATH"

# Additional rules go here.
include        		      global/restrictions.conf;
index                   index.php;

# Additional rules go here.
# if (\$allow_visit = no) { return 403 };

# Make sure files with the following extensions do not get loaded by nginx because nginx would display the source code, and these files can contain PASSWORDS!
location ~* \.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|tpl(\.php)?|xtmpl)$|^(\..*|Entries.*|Repository|Root|Tag|Template)$|\.php_ {
deny all;
}
location ~*  \.(jpg|jpeg|png|gif|css|js|ico)$ {
expires max;
log_not_found off;
}
location ~ \.php$ {
try_files \$uri =404;
include /etc/nginx/fastcgi_params;
fastcgi_buffers 16 16k;
fastcgi_buffer_size 32k;
fastcgi_pass $pool_name;
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
}

location /adminpanel {
$BASIC_AUTH_ACTIVE
}

location / {
location ~ ^/(.+\.php)$ {
try_files \$uri =404;
fastcgi_param HTTPS on;
fastcgi_buffers 16 16k;
fastcgi_buffer_size 32k;
fastcgi_pass $pool_name;
fastcgi_index index.php;
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
include /etc/nginx/fastcgi_params;
}
location ~* ^/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
}
}
}
WEBMAIL_VHOST

}

write_cops_vhost_part() {

CALIBRE_LIBRARY=
printf "Please enter the path to the Calibre Library: "
printf "E.g.: /var/www/OwnCloud/files/Calibre_Library "
read -r CALIBRE_LIBRARY

create_basic_auth COPS

echo "Creating COPS VHOST"
cat << COPS_VHOST >> "$VHOST_CONF_PATH"

# Additional rules go here.
include                 global/restrictions.conf;
index 									feed.php;

# if (\$allow_visit = no) { return 403 };

location ~* \.(?:ico|css|js|gif|jpe?g|png|ttf|woff|svg|eot)$ {
# Some basic cache-control for static files to be sent to the browser
expires max;
add_header Pragma public;
add_header Cache-Control "public, must-revalidate, proxy-revalidate";
}

location ~ \.php$ {
$BASIC_AUTH_ACTIVE
try_files \$uri \$uri/ /index.php;
include fastcgi.conf;
fastcgi_pass   $pool_name;
}

location /Calibre {
root $CALIBRE_LIBRARY;
internal;
}
}
COPS_VHOST

}

create_nginx_vhost() {
vhost_kind=$1
php_pool_text=

echo "
*********************************************
Creating nginx vhost for $vhost_kind
*********************************************"
if [ "$vhost_kind" != "owncloud" ] || [ "$vhost_kind" != "nextcloud" ] || [ "$vhost_kind" != "wordpress" ] || [ "$vhost_kind" != "bbs" ] ||  [ "$vhost_kind" != "cops" ] ||  [ "$vhost_kind" != "webmail" ]; then

while true; do
  echo "
  ------------------------------
  Do you want to create a new vhost or
  add a component to an existing vhost?
  ------------------------------ [new/existing]"
  read -r yn
    case $yn in
        new) vhost_create=true; break;;
        existing) vhost_create=false; break;;
        * ) echo "Please answer new or existing.";;
    esac
done
fi

DOMAIN_PART=$DOMAIN_APP_NAME
if [ -z "$DOMAIN_PART" ]; then
  echo "
  --------------
  Please enter the domain for this vhost

  E.g.: example.com
  ------------------------------
  "
  read -r DOMAIN_PART;
fi

if [ $vhost_create = true ]; then
check_vhost_create_vars

if [ -z "$pool_name" ]; then
  pool_name=$service_user
fi

echo "
------------------------------
Please enter the name of the $php_pool_text
$([ -d /etc/php/7.0/fpm/pool.d/ ] && echo "Following php pools are existing:" && find /etc/php/7.0/fpm/pool.d/ -type f -printf "%f\n" | sed -e 's/\(.*\)\..*/\1/' -e 's/.*/- &/g')

E.g.: $pool_name
------------------------------"
read -r pool_name

else
create_upstream=false
fi

if [ $create_upstream = true ] && [ $vhost_create = true ]; then
  listen_pool=unix:///var/run/php/$pool_name.sock
  echo "
  ------------------------------
  Please enter unix socket or port php listening pool.

  E.g.: $listen_pool
  ------------------------------"
  read -r listen_pool
fi

VHOST_CONF_DIR=/etc/nginx/sites-available
if [ ! -d $VHOST_CONF_DIR ];then
  printf "Where is your nginx sites-available location? Please enter the path: "
  printf "E.g.: %s" "$VHOST_CONF_DIR"
  read -r VHOST_CONF_DIR
fi

if [ ! -d "$VHOST_CONF_DIR" ];then

while true; do
  echo "
  ------------------------------
  The directory $VHOST_CONF_DIR does not exist, should it be created?
  -- 'n' will create NO VHOST file!
  The setup might run into further errors.
  ------------------------------ [Y/n]"
  read -r yn
    case $yn in
        [Yy]* )
        if [ ! -d "$VHOST_CONF_DIR" ]; then
          mkdir -p "$VHOST_CONF_DIR"
        fi
        break;;
        [Nn]* ) return 1; break;;
        * ) echo "Please answer y or n.";;
    esac
done
fi

VHOST_CONF_FILE=$DOMAIN_PART.conf
echo "
------------------------------
Enter a name for your VHOST configuration file.
$([ -d "$VHOST_CONF_DIR"/ ] && echo "Following VHOSTs are existing:" && find "$VHOST_CONF_DIR"/ -type f -printf "%f\n" | sed -e 's/.*/- &/g')

E.g.:  $VHOST_CONF_FILE
------------------------------"
read -r VHOST_CONF_FILE

# Check if vhost alreay exists otherwise create it
VHOST_CONF_PATH=$VHOST_CONF_DIR/$VHOST_CONF_FILE
EXISTING_VHOST_CONFIG=$(find "$VHOST_CONF_DIR" -type f -name "*$VHOST_CONF_FILE*")

if [ "$(find "$VHOST_CONF_DIR" -type f -name "*$VHOST_CONF_FILE*"  | wc -l)" -gt "0" ];then
for i in $EXISTING_VHOST_CONFIG
do
# Backup existing config file if existing
cp "$i" "$i".bkp
done
fi

if [ $create_upstream = true ] && [ $vhost_create = true ]; then
cat << VHOST_UPSTREAM_CREATE > "$VHOST_CONF_PATH"
upstream $pool_name {
server $listen_pool;
}
VHOST_UPSTREAM_CREATE
fi

$vhost_create && write_base_vhost_part "$VHOST_CONF_PATH"

if [ -z "$vhost_kind" ]; then
echo "
------------------------------
Choose the kind for the nginx vhost. You may do some manual adjustments later.
Available kinds:
- wordpress
- owncloud
- cops ( For COPS ebooks vhost )
- bbs ( For BicBucStriim ebooks vhost )
- phpmyadmin (web interface for mysql database)
- postfixadmin (web interface for postfix)
- monit (web interface for a basic monitoring)
- webmail (Web Mail interface )

E.g.: $vhost_kind
------------------------------"
read -r vhost_kind
fi

case "$vhost_kind" in
wordpress)
check_vhost_base_vars
write_wordpress_vhost_part
;;
owncloud)
check_vhost_base_vars
write_owncloud_vhost_part
;;
nextcloud)
check_vhost_base_vars
write_owncloud_vhost_part
;;
cops)
check_vhost_base_vars
write_cops_vhost_part
;;
bbs)
check_vhost_base_vars
write_bbs_vhost_part
;;
phpmyadmin)
check_vhost_base_vars
$vhost_create && write_administrative_base_vhost_part
write_phpmyadmin_vhost_part
;;
postfixadmin)
check_vhost_base_vars
$vhost_create && write_administrative_base_vhost_part
write_postfixadmin_vhost_part
;;
monit)
check_vhost_base_vars
$vhost_create && write_administrative_base_vhost_part
write_monit_vhost_part
;;
webmail)
check_vhost_base_vars
write_webmail_vhost_part
;;
esac

echo "
------------------------------
NGINX VHOST config was created at $VHOST_CONF_PATH
------------------------------"
sleep 2

NGINX_ENABLE_DIR=/etc/nginx/sites-enabled
if [ ! -d $NGINX_ENABLE_DIR ]; then
printf "Where is your nginx sites-enabled location? Please enter the path: e.g.: %s" "$NGINX_ENABLE_DIR"
  read -r NGINX_ENABLE_DIR;
fi

echo "
------------------------------
enable vhost
------------------------------"
if [ -d "$NGINX_ENABLE_DIR" ] && [ ! -f "$NGINX_ENABLE_DIR"/"$DOMAIN_APP_NAME" ]; then
  ln -s "$VHOST_CONF_PATH" "$NGINX_ENABLE_DIR"/"$DOMAIN_APP_NAME"
fi

echo "
NGINX Geo blocking is NOT active per default but included in the VHOST config.
Comment in the allow_visit setting in the VHOST config.
Press return to continue."
Pause
}

create_php_pool() {
echo "
*********************************************
Creating a php fpm pool
*********************************************"
pool_owner=$service_user
pool_name=$pool_owner
size=small
php_tmp=/tmp
echo "
------------------------------
Enter a name for the php pool.
To recognize it easily give it the name of the service user.

E.g.: $pool_name
------------------------------"
read -r pool_name

echo "
------------------------------
Enter a name for php pool owner.
To recognize it easily give it the name of the service user.
Make sure the user exist alreday, or has been created during previous setup steps.
The pool owner will be the owner of files to be read and to be created
from nginx in connection with the PHP-FPM pool.

E.g.: $pool_owner
------------------------------"
read -r pool_owner


listen_pool=/var/run/php/$pool_name.sock
echo "
------------------------------
Please enter unix socket or port php listening pool.

E.g.: $listen_pool
------------------------------"
read -r listen_pool;

echo "
------------------------------
Enter a name php tmp directory.
The directory should already exist.

e.g.: $php_tmp
------------------------------"
read -r php_tmp

echo "Create basic php-fpm pool config"
pool_conf=/etc/php/7.0/fpm/pool.d/$pool_name.conf
cat << BASIC_POOL > "$pool_conf"
;; $DOMAIN_APP_NAME
[$pool_name]
env[HOSTNAME] = \$HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = $php_tmp
env[TMPDIR] = $php_tmp
env[TEMP] = $php_tmp
listen = $listen_pool
listen.owner = $pool_owner
listen.group = www-data
listen.mode = 0660
user = $pool_owner
group = www-data
request_slowlog_timeout = 5s
slowlog = /var/log/php/slowlog-$pool_name.log
catch_workers_output = yes

; ***********************************************************
; Explanations
; The number of PHP-FPM children that should be spawned automatically
; pm.start_servers =
; The maximum number of children allowed (connection limit)
; pm.max_children =
; The minimum number of spare idle PHP-FPM servers to have available
; pm.min_spare_servers =
; The maximum number of spare idle PHP-FPM servers to have available
; pm.max_spare_servers =
; Maximum number of requests each child should handle before re-spawning
; pm.max_requests =
; Maximum amount of time to process a request (similar to max_execution_time in php.ini
; request_terminate_timeout =
; ***********************************************************

BASIC_POOL

while true; do
  echo "
  ------------------------------
  Choose the size for the pool. It can be changed manually later.
  Available sizes:
  - big_oc (Big size pool for e.g. Owncloud )
  - middle_oc (Middle sized pool for e.g. Owncloud )
  - big_wp (Big size pool for e.g. Wordpress )
  - middle (Middle sized pool for e.g. Wordpress and other sites)
  - small (Small sized, on demand, pool, for e.g. administrative pages or lower traffic pages )
  ------------------------------"
  read -r yn
  case $size in
  big_oc)
  echo "Big Owncloud pool"
  cat <<- BIG_OC_POOL >> "$pool_conf"
  listen.backlog = 1024
  pm = dynamic
  pm.max_children = 40
  pm.start_servers = 10
  pm.min_spare_servers = 4
  pm.max_spare_servers = 10
  pm.max_requests = 1000
  pm.process_idle_timeout = 300s
  request_terminate_timeout = 300
  php_value[max_execution_time] = 300
  php_value[max_input_time] = 300
  php_value[memory_limit] = 4096M
  php_value[post_max_size] = 4096M
  php_value[upload_max_filesize] = 4096M
BIG_OC_POOL
  break;;
  middle_oc)
  echo "Middle Owncloud pool"
  cat <<- MIDDLE_OC_POOL >> "$pool_conf"
  listen.backlog = 1024
  pm = dynamic
  pm.max_children = 30
  pm.start_servers = 2
  pm.min_spare_servers = 2
  pm.max_spare_servers = 6
  pm.max_requests = 500
  pm.process_idle_timeout = 150s
  request_terminate_timeout = 150
  php_value[max_input_time] = 150
  php_value[max_execution_time] = 150
  php_value[memory_limit] = 1512M
  php_value[post_max_size] = 1512M
  php_value[upload_max_filesize] = 1512M
MIDDLE_OC_POOL
  break;;
  big_wp)
  echo "Big WordPress pool"
  cat <<- BIG_WP_POOL >> "$pool_conf"
  listen.backlog = 1024
  pm = dynamic
  pm.max_children = 40
  pm.start_servers = 10
  pm.min_spare_servers = 4
  pm.max_spare_servers = 10
  pm.max_requests = 1000
  pm.process_idle_timeout = 300s
  request_terminate_timeout = 300
  php_value[max_input_time] = 300
  php_value[max_execution_time] = 300
  php_value[memory_limit] = 75M
  php_value[post_max_size] = 50M
  php_value[upload_max_filesize] = 50M
BIG_WP_POOL
  break;;
  middle)
  echo "Middle sized pool"
  cat <<- MIDDLE_POOL >> "$pool_conf"
  listen.backlog = 512
  pm = dynamic
  pm.max_children = 30
  pm.start_servers = 2
  pm.min_spare_servers = 2
  pm.max_spare_servers = 6
  pm.max_requests = 500
  pm.process_idle_timeout = 60s
  php_value[max_input_time] = 120
  php_value[max_execution_time] = 120
  php_value[memory_limit] = 50M
  php_value[php_post_max_size] = 25M
  php_value[upload_max_filesize] = 25M
MIDDLE_POOL
  break;;
  small)
  echo "Small size on demand"
  cat <<- SMALL_POOL >> "$pool_conf"
  listen.backlog = 64
  pm = ondemand
  pm.max_children = 5
  pm.max_requests = 200
  pm.process_idle_timeout = 10s
SMALL_POOL
  break;;
  *) echo "ERROR: Invalid option!" ;;
  esac
done

echo "
------------------------------
PHP Pool was created at $pool_conf
------------------------------"
}

start_service() {
services_to_start=$1
echo "
*********************************************
Starting service(s) $services_to_start
*********************************************"
for i in $services_to_start
do
case $i in
nginx)
SERVICE=apache2
if pgrep $SERVICE > /dev/null; then

while true; do
  echo "
  ----------------------------------------------------------------------
  $SERVICE service running, do you want to stop it in order to start $i?
  --------------------------------------------------------------- [Y/n]"
  read -r yn
    case $yn in
        [Yy]* ) service $SERVICE stop; break;;
        [Nn]* ) break;;
        * ) echo "Please answer y or n.";;
    esac
done

fi
;;
esac

service "$i" stop && service "$i" start
done
}

set_vars
check_if_root
set_installer

usage() {
echo "---------------------------------------
USAGE: minstall.sh MODE
---------------------------------------
LOG error and normal out put with
minstall.sh MODE> >(tee minstall.log) 2> >(tee minstall.err >&2)
---------------------------------------
MODES:
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
- create_php_pool"
}

if [ $# -lt 1 ]; then usage;exit; fi
case "$1" in
base_server_setup_and_security)
base_server_setup_and_security
;;
disable_ipv6)
disable_ipv6
;;
set_hostname)
set_hostname
;;
ssh_server)
ssh_server
;;
csf_config)
csf_config
;;
csf_add_syslogs)
csf_add_syslogs "$@"
;;
csf_add_logfiles)
csf_add_logfiles "$@"
;;
csf_add_pignore)
csf_add_pignore "$@"
;;
install_base_components)
install_base_components
;;
install_mysql)
install_mysql
;;
install_phpmyadmin)
install_phpmyadmin
;;
install_webmail_lite)
install_webmail_lite
;;
install_wordpress)
install_wordpress
;;
install_owncloud)
install_owncloud
;;
install_nextcloud)
install_nextcloud
;;
install_redis)
install_redis
;;
install_nginx)
install_nginx
;;
install_php_fpm)
install_php_fpm
;;
install_unbound)
install_unbound
;;
install_bbs)
install_bbs
;;
install_cops)
install_cops
;;
install_monit)
install_monit
;;
install_mailserver)
install_mailserver
;;
install_postfix_and_co)
install_postfix_and_co
;;
install_postfixadmin)
install_postfixadmin
;;
install_php)
install_components "php-common php-readline php7.0 php7.0-cli php7.0-common php7.0-gd php7.0-intl php7.0-json php7.0-mcrypt php7.0-opcache php7.0-sqlite3 php7.0-xml"
;;
configure_mail_security)
configure_mail_security
;;
configure_spf)
configure_spf
;;
configure_dkim)
configure_dkim
;;
configure_dmarc)
configure_dmarc
;;
configure_sieve)
configure_sieve
;;
configure_opensrsd)
configure_opensrsd
;;
configure_postfix)
configure_postfix
;;
configure_dovecot)
configure_dovecot
;;
create_mysql_db)
create_mysql_db
;;
create_dh_param)
create_dh_param
;;
create_snakeoil_certs)
create_snakeoil_certs
;;
create_nginx_vhost)
create_nginx_vhost
;;
create_php_pool)
create_php_pool
;;
*)
usage
exit 3
;;
esac
