#!/usr/bin/env bash
# Wiki: https://v2.gost.run/
# Usage: bash <(curl -s https://raw.githubusercontent.com/terminodev/titanicsite7/main/gost/gost.sh)
# Uninstall: systemctl disable gost --now ; rm -rf /etc/systemd/system/gost.service /opt/gost

GITHUB_RAW_URL="raw.githubusercontent.com"
GITHUB_URL="github.com"
CN=0
customversion=0

# -v 指定版本号
# -c 国内加速
# -h 帮助信息
while getopts ":v:ch" optname
do
    case "$optname" in
      "v")
        targetversion=$OPTARG
        customversion=1
        ;;
      "c")
        CN=1
        ;;
      "h")
        echo "支持选项: -v 指定版本号 -c 国内加速"
        exit 0
        ;;
      ":")
        echo "选项 $OPTARG 无参数值"
        exit 1
        ;;
      "?")
        echo "无效选项 $OPTARG"
        exit 1
        ;;
    esac
done
if [ ${customversion} = 0 ]; then
  # 获取最新版本号
  targetversion=$(wget -qO- -t1 -T2 "https://api.github.com/repos/ginuerzh/gost/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')
  if [ -z $targetversion ]; then
      echo -e "获取Gost最新版本号失败，请使用参数 -v 2.12.0 指定版本号进行安装"
      exit 1
  fi
fi
if [ ${CN} == 1 ]; then
    if [ ${targetversion} \> 2.11.5 ]; then
      URL="https://ghfast.top/https://github.com/ginuerzh/gost/releases/download/v${targetversion}/gost_${targetversion}_linux_amd64.tar.gz"
    else
      URL="https://ghfast.top/https://github.com/ginuerzh/gost/releases/download/v${targetversion}/gost-linux-amd64-${targetversion}.gz"
    fi
    GITHUB_RAW_URL="raw.fastgit.org"
    GITHUB_URL="hub.fastgit.org"
else
    if [ ${targetversion} \> 2.11.5 ]; then
      URL="https://github.com/ginuerzh/gost/releases/download/v${targetversion}/gost_${targetversion}_linux_amd64.tar.gz"
    else
      URL="https://github.com/ginuerzh/gost/releases/download/v${targetversion}/gost-linux-amd64-${targetversion}.gz"
    fi
fi
[ -e /opt/gost/ ] || mkdir -p /opt/gost/
[ -e /opt/gost/config.json ] || wget https://${GITHUB_RAW_URL}/terminodev/titanicsite7/main/gost/config.json -O /opt/gost/config.json
[ -e /opt/gost/gost ] && rm -rf /opt/gost/gost
if [ ${targetversion} \> 2.11.5 ]; then
  wget -O /tmp/gost_${targetversion}_linux_amd64.tar.gz $URL && tar -xvf /tmp/gost_${targetversion}_linux_amd64.tar.gz -C /opt/gost/
  rm -f /tmp/gost_${targetversion}_linux_amd64.tar.gz
else
  wget -O - $URL | gzip -d > /opt/gost/gost
fi
chmod +x /opt/gost/gost
tmpdomain=`echo $RANDOM | md5sum | cut -c1-8`
openssl req -newkey rsa:2048 \
            -x509 \
            -sha256 \
            -days 3650 \
            -nodes \
            -out /opt/gost/cert.pem \
            -keyout /opt/gost/key.pem \
            -subj "/C=US/ST=Alabama/L=Montgomery/O=Super Shops/OU=Marketing/CN=*.${tmpdomain}.com" \
            -addext "subjectAltName=DNS:*.${tmpdomain}.com,DNS:${tmpdomain}.com"; ret=$?
if [[ ! $ret == 0 ]]; then
    cat > "/tmp/openssl_tmp.cnf" << EOF
[ req ]
distinguished_name = req_distinguished_name
attributes         = req_attributes

[ req_distinguished_name ]

[ req_attributes ]
EOF
    openssl req -newkey rsa:2048 \
                -x509 \
                -sha256 \
                -days 730 \
                -nodes \
                -out /opt/gost/cert.pem \
                -keyout /opt/gost/key.pem \
                -subj "/C=CA/ST=British Columbia/L=Vancouver/O=Elite Retail/OU=Sales/CN=*.${tmpdomain}" \
                -extensions SAN \
                -config <(cat /tmp/openssl_tmp.cnf <(printf "\n[SAN]\nsubjectAltName=DNS:*.${tmpdomain},DNS:${tmpdomain}"))
    rm -f /tmp/openssl_tmp.cnf
fi

cat <<EOF > /etc/systemd/system/gost.service
[Unit]
Description=Gost
After=network-online.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=gost
Group=gost
DynamicUser=true
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
WorkingDirectory=/opt/gost
ExecStart=/opt/gost/gost -C /opt/gost/config.json
Restart=always
RestartSec=5
# 资源限制优化
LimitCORE=infinity
LimitNOFILE=512000
LimitNPROC=512000
# 安全设置
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictSUIDSGID=true
ReadWritePaths=/opt/gost
# 日志管理
StandardOutput=null
#StandardError=journal
SyslogIdentifier=gost

[Install]
WantedBy=multi-user.target
EOF

crontab -l > /tmp/gostcronconf
if grep -wq "gost.service" /tmp/gostcronconf;then
  sed -i "/gost.service/d" /tmp/gostcronconf
fi
echo "0 6 * * *  systemctl restart gost.service" >> /tmp/gostcronconf
crontab /tmp/gostcronconf
rm -f /tmp/gostcronconf
echo -e "已设置每日6:00定时重启gost服务，以释放内存、降低负载"

systemctl daemon-reload
systemctl enable gost.service --now
sleep 2
systemctl --no-pager status gost.service
