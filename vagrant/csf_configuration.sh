#!/usr/bin/env bash

CSF_CONFIG_FILE=/etc/csf/csf.conf
INSTALLER=aptitude

$INSTALLER install -y libwww-perl
cd /tmp
wget --no-check-certificate https://download.configserver.com/csf.tgz
tar -xzf csf.tgz
ufw_exe=$(which ufw)
if [ ! -z $ufw_exe ]; then ufw disable; fi
cd csf
sh install.sh
# prerequisite check
perl /usr/local/csf/bin/csftest.pl
#csf -a <ip address>

sed -i -r -e 's/^RESTRICT_SYSLOG[ |=].*/# &/' -e '/^# RESTRICT_SYSLOG[ |=].*/ a RESTRICT_SYSLOG = "3"' "$CSF_CONFIG_FILE"

sed -i -r -e 's/^RESTRICT_UI[ |=].*/# &/' -e '/^# RESTRICT_UI[ |=].*/ a RESTRICT_UI = "2"' "$CSF_CONFIG_FILE"

sed -i -r -e 's/^SMTP_BLOCK[ |=].*/# &/' -e '/^# SMTP_BLOCK[ |=].*/ a SMTP_BLOCK = "1"' "$CSF_CONFIG_FILE"

sed -i -r -e 's/^AT_ALERT[ |=].*/# &/' -e '/^# AT_ALERT[ |=].*/ a AT_ALERT = "1"' "$CSF_CONFIG_FILE"

TCP_IN=25,53,80,110,143,443,465,587,993,995,24441
sed -i -r -e "s/^TCP_IN.*/# &/" -e "/^# TCP_IN.*/ a TCP_IN = \"$TCP_IN\"" "$CSF_CONFIG_FILE"

TCP_OUT=25,53,80,110,113,443,587,993,995,2703
sed -i -r -e "s/^TCP_OUT =.*/# &/" -e "/^# TCP_OUT =.*/ a TCP_OUT = \"$TCP_OUT\"" "$CSF_CONFIG_FILE"

UDP_IN=53
sed -i -r -e "s/^UDP_IN =.*/# &/" -e "/^# UDP_IN =.*/ a UDP_IN = \"$UDP_IN\"" "$CSF_CONFIG_FILE"

UDP_OUT=53,113,123,24441
sed -i -r -e "s/^UDP_OUT.*/# &/" -e "/^# UDP_OUT.*/ a UDP_OUT = \"$UDP_OUT\"" "$CSF_CONFIG_FILE"

sed -i -r "s/^IPV6[ |=].*/IPV6 = \"0\"/g" "$CSF_CONFIG_FILE"

SYSLOG_CHECK=300
sed -i -r -e "s/^SYSLOG_CHECK =.*/# &/" -e "/^# SYSLOG_CHECK =.*/ a SYSLOG_CHECK = \"$SYSLOG_CHECK\"" "$CSF_CONFIG_FILE"

DENY_IP_LIMIT=200
sed -i -r -e "s/^DENY_IP_LIMIT.*/# &/" -e "/^# DENY_IP_LIMIT.*/ a DENY_IP_LIMIT = \"$DENY_IP_LIMIT\"" "$CSF_CONFIG_FILE"

DENY_TEMP_IP_LIMIT=100
sed -i -r -e "s/^DENY_TEMP_IP_LIMIT.*/# &/" -e "/^# DENY_TEMP_IP_LIMIT.*/ a DENY_TEMP_IP_LIMIT = \"$DENY_TEMP_IP_LIMIT\"" "$CSF_CONFIG_FILE"

LF_ALERT_TO=admin@test.com
sed -i -r -e "s/^LF_ALERT_TO.*/# &/" -e "/^# LF_ALERT_TO.*/ a LF_ALERT_TO = \"$LF_ALERT_TO\"" "$CSF_CONFIG_FILE"

CC_ALLOW_PORTS=DE,PL,CH
sed -i -r -e "s/^CC_ALLOW_PORTS[ |=].*/# &/" -e "/^# CC_ALLOW_PORTS[ |=].*/ a CC_ALLOW_PORTS = \"$CC_ALLOW_PORTS\"" "$CSF_CONFIG_FILE"

CC_ALLOW_PORTS_TCP=
sed -i -r -e "s/^CC_ALLOW_PORTS_TCP.*/# &/" -e "/^# CC_ALLOW_PORTS_TCP.*/ a CC_ALLOW_PORTS_TCP = \"$CC_ALLOW_PORTS_TCP\"" "$CSF_CONFIG_FILE"

CC_ALLOW_PORTS_UDP=
sed -i -r -e "s/^CC_ALLOW_PORTS_UDP.*/# &/" -e "/^# CC_ALLOW_PORTS_UDP.*/ a CC_ALLOW_PORTS_UDP = \"$CC_ALLOW_PORTS_UDP\"" "$CSF_CONFIG_FILE"

CC_DENY_PORTS=AE,AF,AL,AM,AZ,BA,BD,BG,BY,CD,CF,CN,GR,HK,IL,IQ,IR,JO,KE,KG,KR,KZ,LB,LY,MA,MD,ME,MN,OM,PK,RU,SA,SD,SN,SY,TJ,TM,TN,TW,UA,UZ,VN
sed -i -r -e "s/^CC_DENY_PORTS =.*/# &/" -e "/^# CC_DENY_PORTS =.*/ a CC_DENY_PORTS = \"$CC_DENY_PORTS\"" "$CSF_CONFIG_FILE"

CC_DENY_PORTS_TCP=25,110,143,465,587,993,995
sed -i -r -e "s/^CC_DENY_PORTS_TCP.*/# &/" -e "/^# CC_DENY_PORTS_TCP.*/ a CC_DENY_PORTS_TCP = \"$CC_DENY_PORTS_TCP\"" "$CSF_CONFIG_FILE"

CC_DENY_PORTS_UDP=113,123
sed -i -r -e "s/^CC_DENY_PORTS_UDP.*/# &/" -e "/^# CC_DENY_PORTS_UDP.*/ a CC_DENY_PORTS_UDP = \"$CC_DENY_PORTS_UDP\"" "$CSF_CONFIG_FILE"

LF_TRIGGER=1
sed -i -r -e "s/^LF_TRIGGER =.*/# &/" -e "/^# LF_TRIGGER =.*/ a LF_TRIGGER = \"$LF_TRIGGER\"" "$CSF_CONFIG_FILE"

LF_POP3D=5
sed -i -r -e "s/^LF_POP3D[ |=].*/# &/" -e "/^# LF_POP3D[ |=].*/ a LF_POP3D = \"$LF_POP3D\"" "$CSF_CONFIG_FILE"

LF_IMAPD=5
sed -i -r -e "s/^LF_IMAPD =.*/# &/" -e "/^# LF_IMAPD =.*/ a LF_IMAPD = \"$LF_IMAPD\"" "$CSF_CONFIG_FILE"

LT_IMAPD=30
sed -i -r -e "s/^LT_IMAPD =.*/# &/" -e "/^# LT_IMAPD =.*/ a LT_IMAPD = \"$LT_IMAPD\"" "$CSF_CONFIG_FILE"

PS_INTERVAL=120
sed -i -r -e "s/^PS_INTERVAL.*/# &/" -e "/^# PS_INTERVAL.*/ a PS_INTERVAL = \"$PS_INTERVAL\"" "$CSF_CONFIG_FILE"

UID_INTERVAL=120
sed -i -r -e "s/^UID_INTERVAL.*/# &/" -e "/^# UID_INTERVAL.*/ a UID_INTERVAL = \"$UID_INTERVAL\"" "$CSF_CONFIG_FILE"

PORTKNOCKING_ALERT=1
sed -i -r -e "s/^PORTKNOCKING_ALERT =.*/# &/" -e "/^# PORTKNOCKING_ALERT =.*/ a PORTKNOCKING_ALERT = \"$PORTKNOCKING_ALERT\"" "$CSF_CONFIG_FILE"

PORTKNOCKING="22;TCP;23;24;25;26"
sed -i -r -e "s/^PORTKNOCKING[ |=].*/# &/" -e "/^# PORTKNOCKING[ |=].*/ a PORTKNOCKING = \"$PORTKNOCKING\"" "$CSF_CONFIG_FILE"

LOGSCANNER=1
sed -i -r -e "s/^LOGSCANNER[ |=].*/# &/" -e "/^# LOGSCANNER[ |=].*/ a LOGSCANNER = \"$LOGSCANNER\"" "$CSF_CONFIG_FILE"

LOGSCANNER_INTERVAL=daily
sed -i -r -e "s/^LOGSCANNER_INTERVAL.*/# &/" -e "/^# LOGSCANNER_INTERVAL.*/ a LOGSCANNER_INTERVAL = \"$LOGSCANNER_INTERVAL\"" "$CSF_CONFIG_FILE"

LOGSCANNER_LINES=90000
sed -i -r -e "s/^LOGSCANNER_LINES.*/# &/" -e "/^# LOGSCANNER_LINES.*/ a LOGSCANNER_LINES = \"$LOGSCANNER_LINES\"" "$CSF_CONFIG_FILE"

echo "   ******************   "
echo "   set csf to testing   "
echo "   ******************   "

sed -i -r -e "s/^TESTING[ |=].*/TESTING = \"1\"/g" "$CSF_CONFIG_FILE"

csf -x && csf -e
