#!/bin/bash
###
 # @Author: Vincent Young
 # @Date: 2023-02-09 17:39:59
 # @LastEditors: Vincent Young
 # @LastEditTime: 2023-02-15 20:54:40
 # @FilePath: /OpenAI-Checker/openai.sh
 # @Telegram: https://t.me/missuo
 # 
 # Copyright © 2023 by Vincent, All Rights Reserved.
### 

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'
BLUE="\033[36m"

SUPPORT_COUNTRY=(AL DZ AD AO AG AR AM AU AT AZ BS BD BB BE BZ BJ BT BO BA BW BR BN BG BF CV CA CL CO KM CG CR CI HR CY CZ DK DJ DM DO EC SV EE FJ FI FR GA GM GE DE GH GR GD GT GN GW GY HT VA HN HU IS IN ID IQ IE IL IT JM JP JO KZ KE KI KW KG LV LB LS LR LI LT LU MG MW MY MV ML MT MH MR MU MX FM MD MC MN ME MA MZ MM NA NR NP NL NZ NI NE NG MK NO OM PK PW PS PA PG PY PE PH PL PT QA RO RW KN LC VC WS SM ST SN RS SC SL SG SK SI SB ZA KR ES LK SR SE CH TW TZ TH TL TG TO TT TN TR TV UG UA AE GB US UY VU ZM)
echo -e "${BLUE}OpenAI Access Checker. Made by Vincent${PLAIN}"
echo -e "${BLUE}https://github.com/missuo/OpenAI-Checker${PLAIN}"
echo "-------------------------------------"

ipv4=1
ipv6=1
while getopts ":i:" optname; do
    case "$optname" in
    "i")
        dstip="$OPTARG"
		v4() { [ "$1" -lt 256 ] 2>/dev/null && [ $1 -ge 0 ] && [ $1 != "$2" ]; }                    

		part="${dstip##*.}"
		if v4 $part && v4 ${dstip%%.*}; then             # test 1 & 4 from 1.2.3.4
			part="${dstip%*.$part}"                      # 1.2.3.4 -> 1.2.3
			part="${part#*.}"                            # 1.2.3 -> 2.3
			if v4 "${part%.*}" && v4 "${part#*.}"; then  # tests 2 & 3
				ipv6=0
			fi
		elif [ "$dstip" != "${dstip#[0-9A-Fa-f]*:}" ] && [ "$1" = "${dstip#*[^0-9A-Fa-f:]}" ] \
		&& [ "${dstip#*[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]}" \
			= "${dstip#*:*:*:*:*:*:*:*:*:}" ]; then
			ipv4=0
		else
			echo -e "${RED}Unrecognized IP format '$dstip'${PLAIN}"
			exit 1
		fi
        useRESOLVE="--resolve chat.openai.com:443:${dstip}"
        ;;
    ":")
        echo -e "${RED}Unknown error while processing options${PLAIN}"
        exit 1
        ;;
    esac

done

if [ -z "$dstip" ]; then
    useRESOLVE=""
fi

result1=$(curl ${useRESOLVE} -sL --max-time 10 "https://chat.openai.com" | grep 'Sorry, you have been blocked')
result2=$(curl ${useRESOLVE} -sI --max-time 10 "https://chat.openai.com" | grep 'cf-mitigated: challenge')
if [ -n "$result1" ] && [ -z "$result2" ]; then
	echo -e "${RED}Your IP is BLOCKED!${PLAIN}"
else
	if [[ "$ipv4" = "1" ]];then
		echo -e "[IPv4]"
		check4=`ping 1.1.1.1 -c 1 2>&1`;
		if [[ "$check4" != *"received"* ]] && [[ "$check4" != *"transmitted"* ]];then
			echo -e "\033[34mIPv4 is not supported on the current host. Skip...\033[0m";
		else
			if [ -n "$dstip" ]; then
				ping $dstip -c 2 -W 1 &> /dev/null;
				if [[ $? -ne 0 ]];then
					echo -e "${RED}Your input IP is Cannot be connected!${PLAIN}"
					exit 1
				fi
				ret_code=$(curl ${useRESOLVE} -4 -sI --max-time 10 https://chat.openai.com/cdn-cgi/trace -w %{http_code} | tail -n1)
				if [ "x$ret_code" != "x200" ]; then   
					echo -e "${RED}Your input IP is Cannot connect to ChatGPT!${PLAIN}"
					exit 1
				fi
			fi
			# local_ipv4=$(curl -4 -s --max-time 10 api64.ipify.org)
			local_ipv4=$(curl ${useRESOLVE} -4 -sS https://chat.openai.com/cdn-cgi/trace | grep "ip=" | awk -F= '{print $2}')
			local_isp4=$(curl -s -4 --max-time 10  --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36" "https://api.ip.sb/geoip/${local_ipv4}" | grep organization | cut -f4 -d '"')
			#local_asn4=$(curl -s -4 --max-time 10  --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36" "https://api.ip.sb/geoip/${local_ipv4}" | grep asn | cut -f8 -d ',' | cut -f2 -d ':')
			echo -e "${BLUE}Your IPv4: ${local_ipv4} - ${local_isp4}${PLAIN}"
			iso2_code4=$(curl ${useRESOLVE} -4 -sS https://chat.openai.com/cdn-cgi/trace | grep "loc=" | awk -F= '{print $2}')
			if [[ "${SUPPORT_COUNTRY[@]}"  =~ "${iso2_code4}" ]]; 
			then
				echo -e "${GREEN}Your IP supports access to OpenAI. Region: ${iso2_code4}${PLAIN}" 
			else
				echo -e "${RED}Region: ${iso2_code4}. Not support OpenAI at this time.${PLAIN}"
			fi
		fi
		echo "-------------------------------------"
	fi
	if [[ "$ipv6" = "1" ]];then
		echo -e "[IPv6]"
		check6=`ping6 240c::6666 -c 1 2>&1`;
		if [[ "$check6" != *"received"* ]] && [[ "$check6" != *"transmitted"* ]];then
			echo -e "\033[34mIPv6 is not supported on the current host. Skip...\033[0m";
		else
			if [ -n "$dstip" ]; then
				ping6 $dstip -c 2 -W 1 &> /dev/null;
				if [[ $? -ne 0 ]];then
					echo -e "${RED}Your input IP is cannot be connected!${PLAIN}"
					exit 1
				fi
				ret_code=$(curl ${useRESOLVE} -6 -sI --max-time 10 https://chat.openai.com/cdn-cgi/trace -w %{http_code} | tail -n1)
				if [ "x$ret_code" != "x200" ]; then   
					echo -e "${RED}Your input IP is Cannot connect to ChatGPT!${PLAIN}"
					exit 1
				fi
			fi
			# local_ipv6=$(curl -6 -s --max-time 20 api64.ipify.org)
			local_ipv6=$(curl ${useRESOLVE} -6 -sS https://chat.openai.com/cdn-cgi/trace | grep "ip=" | awk -F= '{print $2}')
			local_isp6=$(curl -s -6 --max-time 10 --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36" "https://api.ip.sb/geoip/${local_ipv6}" | grep organization | cut -f4 -d '"')
			#local_asn6=$(curl -s -6 --max-time 10  --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36" "https://api.ip.sb/geoip/${local_ipv6}" | grep asn | cut -f8 -d ',' | cut -f2 -d ':')
			echo -e "${BLUE}Your IPv6: ${local_ipv6} - ${local_isp6}${PLAIN}"
			iso2_code6=$(curl ${useRESOLVE} -6 -sS https://chat.openai.com/cdn-cgi/trace | grep "loc=" | awk -F= '{print $2}')
			if [[ "${SUPPORT_COUNTRY[@]}"  =~ "${iso2_code6}" ]]; 
			then
				echo -e "${GREEN}Your IP supports access to OpenAI. Region: ${iso2_code6}${PLAIN}" 
			else
				echo -e "${RED}Region: ${iso2_code6}. Not support OpenAI at this time.${PLAIN}"
			fi
		fi
		echo "-------------------------------------"
	fi
fi
