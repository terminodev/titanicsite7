#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

if  [ -n "$1" ] ;then
  domains="$@"
else
  domains="ddns.server.tw"
fi

config=/opt/gost/config.json
IPREX='([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])'
time=`date +"%Y-%m-%d-%H:%M"`

for domain in ${domains}
do
if [ -z $(grep ${domain} ${config}) ]; then 
  continue
fi
oldip=`grep ${domain} ${config}|grep -Eo "$IPREX"|tail -n1`
newip=`dig -t A +noquestion +noadditional +noauthority +tcp @119.29.29.29 ${domain} | awk '/IN[ \t]+A/{print $NF}'`

if [ $oldip != $newip ]; then
  sed -i "s/$oldip/$newip/" ${config}
  systemctl restart gost
  echo "${time} - [${domain}] update ${oldip} to ${newip}" >> /tmp/changeip.log
fi
done
tail -n 100 /tmp/changeip.log > /tmp/tmpchangeip.log
mv -f /tmp/tmpchangeip.log /tmp/changeip.log