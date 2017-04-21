# Basic System configuration

Some time ago I've created a file, now called automated_installation.sh in this repo that installed every requirement just by giving it a parameter.
That file became too huge and there is not really explanatory documentation around it. That's why I tear it down into multiple smaller howto documents.

### Base installation
I've preferred aptitude over apt-get not because of it's command line GUI but the included features which are more separated in apt-get to other commands. One helpful feature is the solving of dependencies.

All other installation guides will use aptitude but in every case here it is interchangeable with apt-get.

In the automated installation the installer can be chosen and all the steps work with both installers.

It is assumed to be logged in as root. If that is not the case just add a `sudo` before the commands where it is required.

Lets install it:  
`apt-get update &&  apt-get install -y aptitude`

Next let's install some helpful tools which are dependencies for some of the other installation howto's:

`aptitude install -y wget unzip rsync vim bzip2 cron rsyslog curl ed`

Start the newly installed services:  
```shell
systemctl start rsyslog
systemctl start cron
```
Set the correct timezone for the system:  
```shell
echo "Europe/Berlin" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
```
#### Enable Spoof protection with the following commands:  
Further information e.g. here: [kokikode.wordpress.com](https://kokikode.wordpress.com/2009/12/01/defense-against-arp-spoofing-in-linux/)

- Reverse Path filter:  
```shell
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 1 > /proc/sys/net/ipv4/conf/default/rp_filter
```
- Don't respond to broadcast packages:  
`echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts`

- Reject ICMP redirects:  
```shell
echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects
echo 0 > /proc/sys/net/ipv4/conf/default/accept_redirects
```
- Ignore bogus ICMP errors:  
`echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses`

- Do not send ICMP redirects:  
```shell
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 0 > /proc/sys/net/ipv4/conf/default/send_redirects
```
- Do not accept IP source route packets:  
```shell
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
echo 0 > /proc/sys/net/ipv4/conf/default/accept_source_route
```
- Turn on log Martian Packets with impossible addresses:  
```shell
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians
echo 1 > /proc/sys/net/ipv4/conf/default/log_martians
```

Disable ipv6 in the system as it is not needed at the moment
```shell
echo "
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.eth0.disable_ipv6 = 1
" >> /etc/sysctl.conf
```

Enable the changes with this command:
`sysctl -p`

First add these repositories to the apt-sources:  
```shell
echo "deb http://mirrors.linode.com/debian/ jessie-updates main contrib non-free" >> /etc/apt/sources.list
echo "deb-src http://mirrors.linode.com/debian/ jessie-updates main contrib non-free" >> /etc/apt/sources.list
echo "deb-src http://security.debian.org/ jessie/updates main non-free" >> /etc/apt/sources.list
echo "deb http://mirrors.linode.com/debian/ jessie main contrib non-free" >> /etc/apt/sources.list
echo "deb-src http://mirrors.linode.com/debian/ jessie main contrib non-free" >> /etc/apt/sources.list
echo "deb http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list
echo "deb-src http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list
wget http://www.dotdeb.org/dotdeb.gpg --no-check-certificate
apt-key add dotdeb.gpg
rm -f dotdeb.gpg
```

Set the hostname in required places:

```shell
host_name=testserver
old_host_name=$(hostname)
echo "$host_name" > /etc/hostname && bash /etc/init.d/hostname.sh && echo "$host_name" > /etc/mailname
sed -i -e 's/127.0.0.1.*/# &/' -e "/^# 127.0.0.1.*/ a 127.0.0.1 $host_name localhost" -e "s/$old_host_name/$host_name/" /etc/hosts
```

To get notifications on available system updates I install apticron. It sends a mail when updates are available. A description of the change is included. That is a good overview to make a first assessment how urgent the update is.

`aptitude install -y apticron`

Now after the installation the mail recipient has to be configured:   
```shell
mail=admin@example.com;
sed -i -r -e "s/^EMAIL=.*/EMAIL=\"$mail\"/g" /etc/apticron/apticron.conf;
```

### SSH Server
In case it didn't happen yet install SSH Server:  
```shell
SSHD_CONFIG=/etc/ssh/sshd_config;
aptitude install -y openssh-server;
```
Don't allow root login via ssh:  
`sed -i -r -e "s/^PermitRootLogin.*/PermitRootLogin no/g" $SSHD_CONFIG`  

Disable x11 forwarding:  
`sed -i -r -e "s/^X11Forwarding.*/X11Forwarding no/g" $SSHD_CONFIG`

You can add some further users who should have access via ssh:  
```shell
adminuser=testuser;
/usr/sbin/useradd "$adminuser";
echo "$adminuser:$adminuser" | chpasswd;
echo "AllowUsers $adminuser vagrant" >> $SSHD_CONFIG;
```

At last restart the SSH Server:
`systemctl restart ssh`

> Run the next command on your local computer to create ssh keys
The goal is to use ssh keys to login and no passwords
ssh-keygen
This commands copies your local public key to your (this) server.
ssh-copy-id -i ~/.ssh/id_rsa.pub remote-host
adjust the /etc/ssh/sshd_config to disable password login
