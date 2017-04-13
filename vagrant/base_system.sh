#!/usr/bin/env bash

apticron_mail=noreply@test.com
INSTALLER=aptitude
ssh_user=testuser

apt-get update &&  apt-get install -y aptitude
$INSTALLER install -y wget unzip rsync vim bzip2 cron rsyslog curl ed
systemctl start rsyslog
systemctl start cron
echo "Europe/Berlin" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 1 > /proc/sys/net/ipv4/conf/default/rp_filter

echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects
echo 0 > /proc/sys/net/ipv4/conf/default/accept_redirects
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 0 > /proc/sys/net/ipv4/conf/default/send_redirects
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
echo 0 > /proc/sys/net/ipv4/conf/default/accept_source_route
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians
echo 1 > /proc/sys/net/ipv4/conf/default/log_martians

$INSTALLER install -y apticron
apticron_mail=$apticron_mail
sed -i -r -e "s/^EMAIL=.*/EMAIL=\"$apticron_mail\"/g" /etc/apticron/apticron.conf

SSHD_CONFIG=/etc/ssh/sshd_config;
$INSTALLER install -y openssh-server;
sed -i -r -e "s/^PermitRootLogin.*/PermitRootLogin no/g" $SSHD_CONFIG
sed -i -r -e "s/^X11Forwarding.*/X11Forwarding no/g" $SSHD_CONFIG

adminuser=$ssh_user;
adduser "$adminuser";
AllowUsers "$adminuser" >> $SSHD_CONFIG

systemctl restart ssh
