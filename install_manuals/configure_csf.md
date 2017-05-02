# CSF (Config Server Firewall) configuration
I decided to use the csf for my server. It is powerful but not overcomplicated, has good documentation and not unknown to google search results.


### Install the software

We start with the prerequisite:  
`aptitude install -y libwww-perl`

Now let's download the csf package being in the tmp folder:  
`cd /tmp`  
`wget --no-check-certificate https://download.configserver.com/csf.tgz`

Time to unpack the downloaded file:  
`tar -xzf csf.tgz`

Disable ufw (or other) firewall(s)  
`ufw disable`

Change directory to the extracted csf folder:  
`cd csf`

Run the csf installation file install.sh:  
`sh install.sh`

### Configure csf
Set the variable to the csf.conf file so that we don't have to type the path over and over again:  
`CSF_CONFIG_FILE=/etc/csf/csf.conf`

Let's check if all prerequisite are really installed:  
`perl /usr/local/csf/bin/csftest.pl`

If you already know IPs which should be allowed to access this server run this command:  
`csf -a <ip address>`

The following commands are some basic settings. Find the more detailed explanation inside the csf.conf file:  

> 3 = Restrict syslog/rsyslog access to RESTRICT_SYSLOG_GROUP ** RECOMMENDED **

`sed -i -r -e 's/^RESTRICT_SYSLOG[ |=].*/# &/' -e '/^# RESTRICT_SYSLOG[ |=].*/ a RESTRICT_SYSLOG = "3"' "$CSF_CONFIG_FILE"`

> 2 = Disabled UI

`sed -i -r -e 's/^RESTRICT_UI[ |=].*/# &/' -e '/^# RESTRICT_UI[ |=].*/ a RESTRICT_UI = "2"' "$CSF_CONFIG_FILE"`

> If SMTP_BLOCK is enabled but you want to allow local connections to port 25

`sed -i -r -e 's/^SMTP_BLOCK[ |=].*/# &/' -e '/^# SMTP_BLOCK[ |=].*/ a SMTP_BLOCK = "1"' "$CSF_CONFIG_FILE"`

> Account Tracking. The following options enable the tracking of modifications to the accounts on a server.
> 1 = enable this feature for all accounts

`sed -i -r -e 's/^AT_ALERT[ |=].*/# &/' -e '/^# AT_ALERT[ |=].*/ a AT_ALERT = "1"' "$CSF_CONFIG_FILE"`

> Enter all TCP_IN ports, comma separated without spaces, colon for range is possible
e.g. 25,53,80,110,143,443,465,587,993,995,24441,24500:26000

`TCP_IN=25,53,80,110,143,443,465,587,993,995,24441`  
`sed -i -r -e "s/^TCP_IN.*/# &/" -e "/^# TCP_IN.*/ a TCP_IN = \"$TCP_IN\"" "$CSF_CONFIG_FILE"`

> Enter all TCP_OUT ports, comma separated without spaces, colon for range is possible
e.g. 25,53,80,110,113,443,587,993,995,2703,24500:26000

`TCP_OUT=25,53,80,110,113,443,587,993,995,2703`  
`sed -i -r -e "s/^TCP_OUT =.*/# &/" -e "/^# TCP_OUT =.*/ a TCP_OUT = \"$TCP_OUT\"" "$CSF_CONFIG_FILE"`

> Enter all UDP_IN ports, comma separated without spaces, colon for range is possible
e.g. 53,24500:26000

`UDP_IN=53`  
`sed -i -r -e "s/^UDP_IN =.*/# &/" -e "/^# UDP_IN =.*/ a UDP_IN = \"$UDP_IN\"" "$CSF_CONFIG_FILE"`

> Enter all UDP_OUT ports, comma separated without spaces, colon for range is possible
e.g. 53,113,123,24441,24500:26000

`UDP_OUT=53,113,123,24441`  
`sed -i -r -e "s/^UDP_OUT.*/# &/" -e "/^# UDP_OUT.*/ a UDP_OUT = \"$UDP_OUT\"" "$CSF_CONFIG_FILE"`

> Disable IPv6 address as it is not used yes

`sed -i -r "s/^IPV6[ |=].*/IPV6 = \"0\"/g" "$CSF_CONFIG_FILE"`

> Check if SYSLOG is running - Enter the value in seconds (0 to disable)

`SYSLOG_CHECK=300`  
`sed -i -r -e "s/^SYSLOG_CHECK =.*/# &/" -e "/^# SYSLOG_CHECK =.*/ a SYSLOG_CHECK = \"$SYSLOG_CHECK\"" "$CSF_CONFIG_FILE"`

> Limit the number of IP's kept in the /etc/csf/csf.deny file - enter a value (e.g. 200)

`DENY_IP_LIMIT=200`  
`sed -i -r -e "s/^DENY_IP_LIMIT.*/# &/" -e "/^# DENY_IP_LIMIT.*/ a DENY_IP_LIMIT = \"$DENY_IP_LIMIT\"" "$CSF_CONFIG_FILE"`

> Limit the number of IP's kept in the temprary IP ban list. - Enter a value (e.g. 100)

`DENY_TEMP_IP_LIMIT=100`  
`sed -i -r -e "s/^DENY_TEMP_IP_LIMIT.*/# &/" -e "/^# DENY_TEMP_IP_LIMIT.*/ a DENY_TEMP_IP_LIMIT = \"$DENY_TEMP_IP_LIMIT\"" "$CSF_CONFIG_FILE"`


> Enter LF Alert mail address - Leave empty if mailaddress in template should be used.

`LF_ALERT_TO=admin@test.com`  
`sed -i -r -e "s/^LF_ALERT_TO.*/# &/" -e "/^# LF_ALERT_TO.*/ a LF_ALERT_TO = \"$LF_ALERT_TO\"" "$CSF_CONFIG_FILE"`

> Country allow access to specific ports, enter country codes, comma separated (e.g. CH,DE,PL)
Leave empty if you don't want to use this function.

`CC_ALLOW_PORTS=DE,PL,CH`  
`sed -i -r -e "s/^CC_ALLOW_PORTS[ |=].*/# &/" -e "/^# CC_ALLOW_PORTS[ |=].*/ a CC_ALLOW_PORTS = \"$CC_ALLOW_PORTS\"" "$CSF_CONFIG_FILE"`

> Specify TCP ports to allow for entered countries, comma separated (e.g. 21,22)
Leave empty if you don't want to use this function.

`CC_ALLOW_PORTS_TCP=`  
`sed -i -r -e "s/^CC_ALLOW_PORTS_TCP.*/# &/" -e "/^# CC_ALLOW_PORTS_TCP.*/ a CC_ALLOW_PORTS_TCP = \"$CC_ALLOW_PORTS_TCP\"" "$CSF_CONFIG_FILE"`

> Specify UDP ports to allow for entered countries, comma separated (e.g. 53)
Leave empty if you don't want to use this function.

`CC_ALLOW_PORTS_UDP=`  
`sed -i -r -e "s/^CC_ALLOW_PORTS_UDP.*/# &/" -e "/^# CC_ALLOW_PORTS_UDP.*/ a CC_ALLOW_PORTS_UDP = \"$CC_ALLOW_PORTS_UDP\"" "$CSF_CONFIG_FILE"`

> Country deny access to specific ports, enter country codes, comma separated
(e.g.: AE,AF,AL,AM,AZ,BA,BD,BG,BY,CD,CF,CN,GR,HK,IL,IQ,IR,JO,KE,KG,KR,KZ,LB,LY,MA,MD,ME,MN,OM,PK,RU,SA,SD,SN,SY,TJ,TM,TN,TW,UA,UZ,VN)
Make empty if you don't want to use this function.

`CC_DENY_PORTS=AE,AF,AL,AM,AZ,BA,BD,BG,BY,CD,CF,CN,GR,HK,IL,IQ,IR,JO,KE,KG,KR,KZ,LB,LY,MA,MD,ME,MN,OM,PK,RU,SA,SD,SN,SY,TJ,TM,TN,TW,UA,UZ,VN`  
`sed -i -r -e "s/^CC_DENY_PORTS =.*/# &/" -e "/^# CC_DENY_PORTS =.*/ a CC_DENY_PORTS = \"$CC_DENY_PORTS\"" "$CSF_CONFIG_FILE"`

> Specify TCP ports to deny for entered countries, comma separated (e.g.: 25,110,143,465,587,993,995)
Make empty if you don't want to use this function.

`CC_DENY_PORTS_TCP=25,110,143,465,587,993,995`  
`sed -i -r -e "s/^CC_DENY_PORTS_TCP.*/# &/" -e "/^# CC_DENY_PORTS_TCP.*/ a CC_DENY_PORTS_TCP = \"$CC_DENY_PORTS_TCP\"" "$CSF_CONFIG_FILE"`

> Specify UDP ports to deny for entered countries, comma separated (e.g.: 113,123)
Make empty if you don't want to use this function.  

`CC_DENY_PORTS_UDP=113,123`  
`sed -i -r -e "s/^CC_DENY_PORTS_UDP.*/# &/" -e "/^# CC_DENY_PORTS_UDP.*/ a CC_DENY_PORTS_UDP = \"$CC_DENY_PORTS_UDP\"" "$CSF_CONFIG_FILE"`

> Set LF_TRIGGER on (1) or off (0) (e.g.: 0)

`LF_TRIGGER=1`  
`sed -i -r -e "s/^LF_TRIGGER =.*/# &/" -e "/^# LF_TRIGGER =.*/ a LF_TRIGGER = \"$LF_TRIGGER\"" "$CSF_CONFIG_FILE"`

> Enable login failure detection of pop3 connections - enter number of failed logins to block  (e.g.: 0)

`LF_POP3D=5`  
`sed -i -r -e "s/^LF_POP3D[ |=].*/# &/" -e "/^# LF_POP3D[ |=].*/ a LF_POP3D = \"$LF_POP3D\"" "$CSF_CONFIG_FILE"`

> Enable login failure detection of imap connections - enter number of failed logins to block  (e.g.: 0)

`LF_IMAPD=5`  
`sed -i -r -e "s/^LF_IMAPD =.*/# &/" -e "/^# LF_IMAPD =.*/ a LF_IMAPD = \"$LF_IMAPD\"" "$CSF_CONFIG_FILE"`    

> Block IMAP logins if greater than LT_IMAPD times per hour per account per IP - enter value (e.g.: 0)

`LT_IMAPD=30`  
`sed -i -r -e "s/^LT_IMAPD =.*/# &/" -e "/^# LT_IMAPD =.*/ a LT_IMAPD = \"$LT_IMAPD\"" "$CSF_CONFIG_FILE"`

> Port Scan Tracking. This feature tracks port blocks logged by iptables to
syslog. If an IP address generates a port block that is logged more than
PS_LIMIT (10) within PS_INTERVAL seconds, the IP address will be blocked. - enter value in seconds (recommended 60-300, e.g.: 0)

`PS_INTERVAL=120`  
`sed -i -r -e "s/^PS_INTERVAL.*/# &/" -e "/^# PS_INTERVAL.*/ a PS_INTERVAL = \"$PS_INTERVAL\"" "$CSF_CONFIG_FILE"`

> User ID Tracking. This feature tracks UID blocks logged by iptables to
syslog. If a UID generates a port block that is logged more than UID_LIMIT
times within UID_INTERVAL seconds, an alert will be sent. - enter value in seconds, (recommended 120, e.g.: 0)

`UID_INTERVAL=120`  
`sed -i -r -e "s/^UID_INTERVAL.*/# &/" -e "/^# UID_INTERVAL.*/ a UID_INTERVAL = \"$UID_INTERVAL\"" "$CSF_CONFIG_FILE"`

> Do you want to enable port knocking, e.g. for SSH access - yes(1)/no(0): (e.g.: 1)

`PORTKNOCKING_ALERT=1`  
`sed -i -r -e "s/^PORTKNOCKING_ALERT =.*/# &/" -e "/^# PORTKNOCKING_ALERT =.*/ a PORTKNOCKING_ALERT = \"$PORTKNOCKING_ALERT\"" "$CSF_CONFIG_FILE"`

> Enter following information as in the example:
openport;protocol;timeout;kport1;kport2;kport3[...;kportN],...
e.g.: 22;TCP;20;100;200;300;400

`PORTKNOCKING="22;TCP;23;24;25;26"`  
`sed -i -r -e "s/^PORTKNOCKING[ |=].*/# &/" -e "/^# PORTKNOCKING[ |=].*/ a PORTKNOCKING = \"$PORTKNOCKING\"" "$CSF_CONFIG_FILE"`

> Do you want to enable the logscanner, it will send regularly log reports- yes(1)/no(0): (e.g.: 1)

`LOGSCANNER=1`  
`sed -i -r -e "s/^LOGSCANNER[ |=].*/# &/" -e "/^# LOGSCANNER[ |=].*/ a LOGSCANNER = \"$LOGSCANNER\"" "$CSF_CONFIG_FILE"`

> The logscanner interval can be set to:
hourly - sent on the hour
daily  - sent at midnight (00:00)
manual - sent whenever 'csf --logrun' is run. This allows for scheduling
via cron job
(e.g.: manual)

`LOGSCANNER_INTERVAL=daily`  
`sed -i -r -e "s/^LOGSCANNER_INTERVAL.*/# &/" -e "/^# LOGSCANNER_INTERVAL.*/ a LOGSCANNER_INTERVAL = \"$LOGSCANNER_INTERVAL\"" "$CSF_CONFIG_FILE"`

> Set the maximum number of lines in the report before it is truncated
1000-100000 (e.g.: 5000)

`LOGSCANNER_LINES=90000`  
`sed -i -r -e "s/^LOGSCANNER_LINES.*/# &/" -e "/^# LOGSCANNER_LINES.*/ a LOGSCANNER_LINES = \"$LOGSCANNER_LINES\"" "$CSF_CONFIG_FILE"`

> Check the file `/etc/csf/csf.logfiles` and add all log files which should be included for the LOGSCANNER report function.  
> Check the file `/etc/csf/csf.syslogs` and add all log files which should be searched too.

> Check the file `/etc/csf/csf.pignore` and add processes which should be ignored in this format:  
> - exe:/path/to/executable  
> - ( p ) cmd:/usr/sbin/amavisd-new.*  
> - pcmd:php /var/space in path/cron.php  

The next command enables CSF Firewall testing, change to 0 to disable testing if CSF works well

`sed -i -r -e "s/^TESTING[ |=].*/TESTING = \"1\"/g" "$CSF_CONFIG_FILE"`

Restart csf to apply the changes:  
`csf -r`
