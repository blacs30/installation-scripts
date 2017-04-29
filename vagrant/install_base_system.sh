#!/usr/bin/env bash

# load variables
source /vagrant/environment.sh

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

# Disable ipv6 in the system as it is not needed at the moment
cat << EOF >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.eth0.disable_ipv6 = 1
EOF
sysctl -p

# update the apt rep
cat << EOF >> /etc/apt/sources.list
deb http://mirrors.linode.com/debian/ jessie-updates main contrib non-free
deb-src http://mirrors.linode.com/debian/ jessie-updates main contrib non-free
deb-src http://security.debian.org/ jessie/updates main non-free
deb http://mirrors.linode.com/debian/ jessie main contrib non-free
deb-src http://mirrors.linode.com/debian/ jessie main contrib non-free
deb http://packages.dotdeb.org jessie all
deb-src http://packages.dotdeb.org jessie all
EOF

wget http://www.dotdeb.org/dotdeb.gpg --no-check-certificate
apt-key add dotdeb.gpg
rm -f dotdeb.gpg
$INSTALLER update

# set the hostname
HOST_NAME=$HOST_NAME
old_HOST_NAME=$(hostname)
echo "$HOST_NAME" > /etc/hostname && bash /etc/init.d/hostname.sh && echo "$HOST_NAME" > /etc/mailname
sed -i -e 's/127.0.0.1.*/# &/' -e "/^# 127.0.0.1.*/ a 127.0.0.1 $HOST_NAME localhost" -e "s/$old_HOST_NAME/$HOST_NAME/" /etc/hosts

$INSTALLER install -y apticron
sed -i -r -e "s/^EMAIL=.*/EMAIL=\"$APTICRON_MAIL\"/g" /etc/apticron/apticron.conf

SSHD_CONFIG=/etc/ssh/sshd_config;
$INSTALLER install -y openssh-server;
sed -i -r -e "s/^PermitRootLogin.*/PermitRootLogin no/g" $SSHD_CONFIG
sed -i -r -e "s/^X11Forwarding.*/X11Forwarding no/g" $SSHD_CONFIG

adminuser=$SSH_USER;
/usr/sbin/useradd "$adminuser";
echo "$adminuser:$adminuser" | chpasswd;
echo "AllowUsers $adminuser vagrant" >> $SSHD_CONFIG

systemctl restart ssh
