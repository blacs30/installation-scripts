#!/bin/bash
# ====================================================
# base server config
# ==================
# create system users
# disable root ssh access
# create ssh key files
# set hostname and timezone
# enable sudo
# and more
# ====================================================

# add administrative user
adduser adminuser

# test login of the new user

# edit SSH configuration
vi /etc/ssh/sshd_config
PermitRootLogin no
X11Forwarding no
AllowUsers adminuser adminuser2

# restart SSH service
service ssh restart

# ssh key based login
echo "ssh-keygen"
echo "ssh-copy-id -i ~/.ssh/id_rsa.pub remote-host"
# alternative for mac: cat ~/.ssh/id_rsa.pub | ssh user@machine "mkdir ~/.ssh; cat >> ~/.ssh/authorized_keys"

# set the hostname
hostnamectl set-hostname your.hostname.here

# check the timezone
dpkg-reconfigure tzdata

# edit /etc/sysctl.conf
net.ipv4.conf.all.rp_filter=1
echo -n '1' > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# ====================================================
# solve perl locale warning
# https://www.thomas-krenn.com/de/wiki/Perl_warning_Setting_locale_failed_unter_Debian
# ====================================================
# Set locales & timezone to Swedish
echo "Europe/Berlin" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales

# ====================================================
# install sudo and configuration
# ====================================================
apt-get install -y sudo

# add adminuser to group sudo
adduser adminuser sudo

# request root password for sudo
visudo
# add to last line
Defaults rootpw

# ====================================================
# install config server firewall csf and configuration
# https://www.digitalocean.com/community/tutorials/howtoinstallandconfigureconfigserverfirewallcsfonubuntu
# ====================================================
cd /tmp
wget http://www.configserver.com/free/csf.tgz
tar ‐xzf csf.tgz

# disable ufw if installed
ufw disable

# install csf
cd csf
sh install.shift

# check if all modules are available
perl /usr/local/csf/bin/csftest.pl

# edit config
vi /etc/csf/csf.conf

# apply changes after editing
csf -r

# allow ip
csf -a IPADDRESS

List of log files for the UI System Log Watch and Search features.
/etc/csf/csf.syslogs
List of log files for the LOGSCANNER feature.
/etc/csf/csf.logfiles


# Disable IPv6
echo "
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.eth0.disable_ipv6 = 1
" >> /etc/sysctl.conf

sysctl -p

echo "add nfs share as ro to /etc/fstab "

# install apticron
apt-get install -y apticron
vi /etc/apticron/apticron.conf
EMAIL="...."
