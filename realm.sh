#!/usr/bin/env bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
clear
#=================================================
#   Description: Realm管理脚本，仅供参考
#   From: https://github.com/terminodev
#=================================================

stty erase ^?

cd "$(
  cd "$(dirname "$0")" || exit
  pwd
)" || exit

# 字体颜色配置
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
OK="${Green}[OK]${Font}"
ERROR="${Red}[ERROR]${Font}"

# 变量
shell_version="1.0.2"
shelldir=$(pwd)
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"
realm_conf_path="/opt/realm/config.json"
raw_conf_path="/opt/realm/rawconf"

# check root
[[ $EUID -ne 0 ]] && echo -e "${Red}错误：${Font} 当前非ROOT账号，无法继续操作，请更换ROOT账号！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${Red}未检测到系统版本${Font}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${Red}请使用 CentOS 7 或更高版本的系统！${Font}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${Red}请使用 Ubuntu 16 或更高版本的系统！${Font}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${Red}请使用 Debian 8 或更高版本的系统！${Font}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

print_ok() {
  echo -e "${OK} ${Blue} $1 ${Font}"
}

print_error() {
  echo -e "${ERROR} ${RedBG} $1 ${Font}"
}

judge() {
  if [[ 0 -eq $? ]]; then
    print_ok "$1 完成"
    sleep 1
  else
    print_error "$1 失败"
    exit 1
  fi
}

before_show_menu() {
    echo && echo -n -e "${Yellow}按回车返回主菜单: ${Font}" && read temp
    start_menu
}

Installation_dependency() {
    echo -e "${Info} 开始安装依赖..."
    if [[ ${release} == "centos" ]]; then
        yum install epel-release -y
        yum install gzip wget curl unzip jq -y
    else
        apt-get update && apt-get install gzip wget curl unzip jq -y
    fi
    \cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo -e "${Info} 依赖安装完毕..."
}

#检测是否安装Realm
# 0: running, 1: not running, 2: not installed
check_status() {
    if test ! -e /opt/realm/realm -a ! -e /etc/systemd/system/realm.service -a ! -e /opt/realm/config.json; then
        return 2
    fi
    temp=$(systemctl --no-pager status realm | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled realm)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${Red}Realm已安装，请不要重复安装${Font}"
        before_show_menu
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${Red}请先安装Realm${Font}"
        before_show_menu
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Realm状态: ${Green}已运行${Font}  版本: ${Green}$(/opt/realm/realm -v | awk '{print $2}')${Font}"
            show_enable_status
            ;;
        1)
            echo -e "Realm状态: ${Yellow}未运行${Font}  版本: ${Green}$(/opt/realm/realm -v | awk '{print $2}')${Font}"
            show_enable_status
            ;;
        2)
            echo -e "Realm状态: ${Red}未安装${Font}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "是否开机自启: ${Green}是${Font}"
    else
        echo -e "是否开机自启: ${Red}否${Font}"
    fi
}

Write_config() {
echo '
{
  "log": {
    "level": "off",
    "output": "stdout"
  },
  "dns": {
    "mode": "ipv4_then_ipv6",
    "protocol": "tcp_and_udp",
    "nameservers": [
      "1.1.1.1:53",
      "223.5.5.5:53"
    ],
    "min_ttl": 60,
    "max_ttl": 3600,
    "cache_size": 256
  },
  "network": {
    "no_tcp": false,
    "use_udp": true,
    "ipv6_only": false,
    "tcp_timeout": 5,
    "udp_timeout": 30,
    "send_mptcp": false,
    "accept_mptcp": false,
    "send_proxy": false,
    "send_proxy_version": 2,
    "accept_proxy": false,
    "accept_proxy_timeout": 5,
    "tcp_keepalive": 15,
    "tcp_keepalive_probe": 3
  },
  "endpoints": [

  ]
}' > /opt/realm/config.json
}

#安装Realm
Install_Realm(){
  check_uninstall
  Installation_dependency
  [ -e /opt/realm/ ] || mkdir -p /opt/realm/
  echo -e "######################################################"
  echo -e "#    请选择下载点:  1.国外   2.国内                  #"
  echo -e "######################################################"
  read -p "请选择(默认国外): " download
  [[ -z ${download} ]] && download="1"
  if [[ ${download} == [2] ]]; then
      URL="https://ghfast.top/https://github.com/zhboner/realm/releases/latest/download/realm-x86_64-unknown-linux-musl.tar.gz"
  elif [[ ${download} == [1] ]]; then
      URL="https://github.com/zhboner/realm/releases/latest/download/realm-x86_64-unknown-linux-musl.tar.gz"    
  else
      print_error "输入错误，请重新输入！"
      before_show_menu
  fi
  wget -N --no-check-certificate -O realm-x86_64-unknown-linux-musl.tar.gz ${URL} && tar -xvf realm-x86_64-unknown-linux-musl.tar.gz && chmod +x realm && mv -f realm /opt/realm/realm
  rm -rf realm-x86_64-unknown-linux-musl.tar.gz
  Write_config
echo '
[Unit]
Description=Realm
After=network-online.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=realm
Group=realm
DynamicUser=true
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
WorkingDirectory=/opt/realm
ExecStart=/opt/realm/realm -c /opt/realm/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5s
RestartPreventExitStatus=23

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
ReadWritePaths=/opt/realm
# 日志管理（使用systemd journal）
StandardOutput=journal
StandardError=journal
SyslogIdentifier=realm

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/realm.service
  systemctl enable realm --now
    if test -a /opt/realm/realm -a /etc/systemd/system/realm.service -a /opt/realm/config.json;then
        print_ok "Realm安装完成"
    else
        print_error "Realm安装失败"
        rm -rf /opt/realm/realm /opt/realm/config.json /etc/systemd/system/realm.service
    fi
  sleep 3s
  start_menu
}

#更新realm
Update_Realm(){
    if test -a /opt/realm/realm -a /etc/systemd/system/realm.service -a /opt/realm/config.json;then
        localv=$(/opt/realm/realm -v | awk '{print $2}')
        latestv=$(curl --silent --connect-timeout 5 --retry 1 "https://api.github.com/repos/zhboner/realm/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g;s/v//g')
        if [[ x"${localv}" == x || x"${latestv}" == x ]]; then
            if [[ "${autoupgrade}" == 0 ]]; then
                confirm "版本获取失败，是否覆盖安装最新版本，数据不会丢失，确认请输入y?" "n"
                if [[ $? != 0 ]]; then
                    echo -e "${Red}已取消${Font}"
                    before_show_menu
                    return 0
                fi
            else
                echo -e "${Red}版本获取失败，取消更新${Font}"
                return 0
            fi
        else
            if [[ ${localv} == $(echo -e "${localv}\n${latestv}" | sort -rV | head -1) ]]; then
                print_ok "本地已经安装最新版本，无需更新"
                if [[ "${autoupgrade}" == 0 ]]; then
                    before_show_menu
                else
                    exit 0
                fi
            else
                if [[ "${autoupgrade}" == 0 ]]; then
                    confirm "即将开始安装最新版本，数据不会丢失，是否继续?" "n"
                    if [[ $? != 0 ]]; then
                        echo -e "${Red}已取消${Font}"
                        before_show_menu
                        return 0
                    fi
                else
                    echo -e "${Green}即将开始安装最新版本${Font}"
                fi
            fi
        fi
        [ -e /opt/realm/ ] || mkdir -p /opt/realm/
        if [[ "${autoupgrade}" == 0 ]]; then
            echo -e "######################################################"
            echo -e "#    请选择下载点:  1.国外   2.国内                  #"
            echo -e "######################################################"
            read -p "请选择(默认国外): " download
        fi
        [[ -z ${download} ]] && download="1"
        if [[ ${download} == [2] ]]; then
            URL="https://ghfast.top/https://github.com/zhboner/realm/releases/latest/download/realm-x86_64-unknown-linux-musl.tar.gz"
        elif [[ ${download} == [1] ]]; then
            URL="https://github.com/zhboner/realm/releases/latest/download/realm-x86_64-unknown-linux-musl.tar.gz"    
        else
            print_error "输入错误，请重新输入！"
            before_show_menu
        fi
        wget -N --no-check-certificate -O /tmp/realm-x86_64-unknown-linux-musl.tar.gz ${URL}
        if [[ $? != 0 ]]; then
            print_error "Realm下载失败，暂未更新"
            return 0
        fi
        tar -xvf /tmp/realm-x86_64-unknown-linux-musl.tar.gz -C /tmp && mv -f /tmp/realm /opt/realm/realm && chmod +x /opt/realm/realm
        rm -rf /tmp/realm-x86_64-unknown-linux-musl.tar.gz
        systemctl restart realm
        check_status
        if [[ $? == 0 ]]; then
            print_ok "更新完成，已自动重启Realm"
            exit 0
        fi
    else
        print_error "Realm没有安装，无法更新"
        if [[ "${autoupgrade}" == 0 ]]; then
            sleep 3s
            before_show_menu
        fi
    fi
}

#卸载Realm
Uninstall_Realm(){
    if test -a /opt/realm/realm -a /etc/systemd/system/realm.service -a /opt/realm/config.json;then
        check_install
        confirm "确定要卸载Realm吗?" "n"
        if [[ $? != 0 ]]; then
            start_menu
            return 0
        fi
        systemctl stop realm
        systemctl disable realm
        rm -rf /opt/realm/realm /opt/realm/config.json /etc/systemd/system/realm.service
        systemctl daemon-reload
        systemctl reset-failed
        print_ok "Realm卸载成功"
        sleep 3s
        before_show_menu
    else
        print_error "Realm没有安装，无需卸载"
        sleep 3s
        before_show_menu
    fi
}
#启动Realm
Start_Realm(){
    check_install
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        print_ok "Realm正在运行"
    else
        systemctl start realm
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            print_ok "${Green}Realm启动成功${Font}"
        else
            print_error "Realm启动失败，请稍后查看日志信息"
        fi
    fi
    before_show_menu
}

#停止Realm
Stop_Realm(){
    check_install
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        print_ok "Realm已停止，无需再次停止"
    else
        systemctl stop realm
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            print_ok "Realm停止成功"
        else
            print_error "Realm停止失败，请稍后查看日志信息"
        fi
    fi
    before_show_menu
}

#重启Realm
Restart_Realm(){
    check_install
    $(systemctl restart realm)
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        print_ok "Realm重启成功"
    else
        print_error "Realm重启失败，请稍后查看日志信息"
    fi
    before_show_menu
}

#查看Realm
Status_Realm(){
    check_install
    systemctl --no-pager status realm
    before_show_menu
}

#设置Realm自启
Enable_Realm(){
    check_install
    systemctl enable realm
    if [[ $? == 0 ]]; then
        print_ok "Realm设置开机自启成功"
    else
        print_error "Realm设置开机自启失败"
    fi
    before_show_menu
}

#取消Realm自启
Disable_Realm(){
    check_install
    systemctl disable realm
    if [[ $? == 0 ]]; then
        print_ok "Realm取消开机自启成功"
    else
        print_error "Realm取消开机自启失败"
    fi
    before_show_menu
}

#添加设置
Set_Config(){
[ -e /opt/realm/rawconf ] || touch /opt/realm/rawconf
echo -e " 请输入本地监听端口[1-65535] (支持端口段如10000-10002,数量要和目标端口一致)"
read -e -p " 留空则随机分配[10000-16383]之间一个端口:" listening_ports
if [[ -z "${listening_ports}" ]]; then
    listening_port_temp1=0
    listening_ports=0
    while [ $listening_ports == 0 ]; do
       listening_port_temp1=`shuf -i 10000-16383 -n1`
       if [ "$(cat /opt/realm/rawconf |cut -d# -f1 |grep "${listening_port_temp1}" |wc -l)" == 0 ] ; then
              listening_ports=$listening_port_temp1
       fi
    done
fi
if [[ ! "${listening_ports}" =~ ^[0-9]+$ ]]; then   
    echo -e "${Red}请输入正确的数字格式${Font}"
    before_show_menu
fi
listening_ports_count=$(cat /opt/realm/rawconf |cut -d# -f1 |grep "${listening_ports}" |wc -l)
if [[ "${listening_ports_count}" -eq 1 ]]; then   
    echo -e "${Red}您输入的端口已存在，请换一个端口${Font}"
    before_show_menu
fi
read -e -p " 请输入转发的目标地址/IP（默认：127.0.0.1） :" remote_addresses
if [[ -z "${remote_addresses}" ]]; then
    remote_addresses=127.0.0.1
fi
if [[ $remote_addresses =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];then
    c=`echo $remote_addresses |cut -d. -f1`
    d=`echo $remote_addresses |cut -d. -f2`
    e=`echo $remote_addresses |cut -d. -f3`
    f=`echo $remote_addresses |cut -d. -f4`
    if [ $c -gt 255 -o $d -gt 255 -o $e -gt 255 -o $f -gt 255 ];then
        echo -e "${Red}请输入正确格式的IP${Font}"
        before_show_menu
    fi
fi

read -e -p " 请输入目标端口[1-65535] (支持端口段如10000-10002，数量要和监听端口相同):" remote_ports
if [[ -z "${remote_ports}" ]]; then
    echo -e "${Yellow}已取消${Font}"
    before_show_menu
fi
if [[ ! "${remote_ports}" =~ ^[0-9]+$ ]]; then   
    echo -e "${Red}请输入正确的数字格式${Font}"
    before_show_menu
fi
tunnel_type=n
confirm "是否使用隧道转发？[y/n]" "n"
if [[ $? == 0 ]]; then
    read -e -p " 请输入隧道类型（默认：s，客户端填 c，服务端填 s ）:" tunnel_type
    if [[ -z "${tunnel_type}" ]]; then
        tunnel_type=s
    fi
    read -e -p " 请输入隧道转发模式（客户端和服务器必须保持一致，默认：ws ，可选：ws tls wss）:" tunnel_mode
    if [[ -z "${tunnel_mode}" ]]; then
        tunnel_mode=ws
    fi
    if [[ "${tunnel_mode}" == ws || "${tunnel_mode}" == wss ]]; then
        read -e -p " 请输入伪装host（客户端和服务器必须保持一致，默认：apps.bdimg.com）:" tunnel_host
        if [[ -z "${tunnel_host}" ]]; then
            tunnel_host=apps.bdimg.com
        fi
        read -e -p " 请输入伪装path（客户端和服务器必须保持一致，默认：/ws）:" tunnel_path
        if [[ -z "${tunnel_path}" ]]; then
            tunnel_path=/ws
        fi
    fi
    if [[ "${tunnel_mode}" == tls || "${tunnel_mode}" == wss ]]; then
        read -e -p " 请输入伪装sni（客户端和服务器必须保持一致，默认：apps.bdimg.com）:" tunnel_sni
        if [[ -z "${tunnel_sni}" ]]; then
            tunnel_sni=apps.bdimg.com
        fi
    fi

fi
read -e -p " 请输入备注信息 (可选):" remarks
if [[ $remarks =~ \/ || $remarks =~ \# ]];then
    echo -e "${Red}备注信息中不支持字符 "/" ,"#"${Font}"
    before_show_menu
fi
    echo ""
    echo -e "—————————————————————————————————————————————"
    echo -e "请检查Realm转发规则配置是否有误 !\n"
    echo -e "本地监听端口 : ${Green}${listening_ports}${Font}"
    echo -e "目标地址     : ${Green}${remote_addresses}${Font}"
    echo -e "目标端口     : ${Green}${remote_ports}${Font}"
    if [[ "${tunnel_type}" != n ]]; then
        echo -e "隧道类型     : ${Green}${tunnel_type}${Font}"
        echo -e "转发模式     : ${Green}${tunnel_mode}${Font}"
        if [[ "${tunnel_mode}" == ws || "${tunnel_mode}" == wss ]]; then
            echo -e "伪装host     : ${Green}${tunnel_host}${Font}"
            echo -e "伪装path     : ${Green}${tunnel_path}${Font}"
        fi
        if [[ "${tunnel_mode}" == tls || "${tunnel_mode}" == wss ]]; then
            echo -e "伪装sni     : ${Green}${tunnel_sni}${Font}"
        fi
    fi
    echo -e "备注信息     : ${Green}${remarks}${Font}"
    echo -e "—————————————————————————————————————————————\n"

    read -e -p "按任意键继续，如有配置错误请使用 Ctrl+C 退出。" temp
    if [[ "${tunnel_type}" == n ]]; then
        JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports"}'
        JSON=${JSON/listening_ports/$listening_ports}
        JSON=${JSON/remote_addresses/$remote_addresses}
        JSON=${JSON/remote_ports/$remote_ports}
        temp=$(jq --argjson data $JSON '.endpoints += [$data]' $realm_conf_path)
        echo $temp >$realm_conf_path
    else
        if [[ "${tunnel_mode}" == ws ]]; then
            JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports","tunnel_type":"ws;host=example.com;path=/chat"}'
            JSON=${JSON/listening_ports/$listening_ports}
            JSON=${JSON/remote_addresses/$remote_addresses}
            JSON=${JSON/remote_ports/$remote_ports}
            if [[ "${tunnel_type}" == c ]]; then
                JSON=${JSON/tunnel_type/remote_transport}
            else
                JSON=${JSON/tunnel_type/listen_transport}
            fi
            JSON=${JSON/example.com/$tunnel_host}
            JSON=${JSON/\/chat/$tunnel_path}
            temp=$(jq --argjson data $JSON '.endpoints += [$data]' $realm_conf_path)
            echo $temp >$realm_conf_path
        elif [[ "${tunnel_mode}" == tls ]]; then
            if [[ "${tunnel_type}" == c ]]; then
                JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports","tunnel_type":"tls;sni=snidomain.com;insecure"}'
                JSON=${JSON/tunnel_type/remote_transport}
            else
                JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports","tunnel_type":"tls;servername=snidomain.com"}'
                JSON=${JSON/tunnel_type/listen_transport}
            fi
            JSON=${JSON/listening_ports/$listening_ports}
            JSON=${JSON/remote_addresses/$remote_addresses}
            JSON=${JSON/remote_ports/$remote_ports}
            JSON=${JSON/snidomain.com/$tunnel_sni}
            temp=$(jq --argjson data $JSON '.endpoints += [$data]' $realm_conf_path)
            echo $temp >$realm_conf_path
        elif [[ "${tunnel_mode}" == wss ]]; then
            if [[ "${tunnel_type}" == c ]]; then
                JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports","tunnel_type":"ws;host=example.com;path=/chat;tls;sni=snidomain.com;insecure"}'
                JSON=${JSON/tunnel_type/remote_transport}
            else
                JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports","tunnel_type":"ws;host=example.com;path=/chat;tls;servername=snidomain.com"}'
                JSON=${JSON/tunnel_type/listen_transport}
            fi
            JSON=${JSON/listening_ports/$listening_ports}
            JSON=${JSON/remote_addresses/$remote_addresses}
            JSON=${JSON/remote_ports/$remote_ports}
            JSON=${JSON/example.com/$tunnel_host}
            JSON=${JSON/\/chat/$tunnel_path}
            JSON=${JSON/snidomain.com/$tunnel_sni}
            temp=$(jq --argjson data $JSON '.endpoints += [$data]' $realm_conf_path)
            echo $temp >$realm_conf_path
        fi
    fi
    echo $listening_ports"#"$remote_addresses"#"$remote_ports"#"$tunnel_type"#"$tunnel_mode"#"$tunnel_host"#"$tunnel_path"#"$tunnel_sni"#"$remarks >> $raw_conf_path
    Restart_Realm
}

#赋值
eachconf_retrieve()
{
    a=${trans_conf}
    listening_ports=`echo ${a} | awk -F "#" '{print $1}'`
    remote_addresses=`echo ${a} | awk -F "#" '{print $2}'`
    remote_ports=`echo ${a} | awk -F "#" '{print $3}'`
    tunnel_type=`echo ${a} | awk -F "#" '{print $4}'`
    tunnel_mode=`echo ${a} | awk -F "#" '{print $5}'`
    tunnel_host=`echo ${a} | awk -F "#" '{print $6}'`
    tunnel_path=`echo ${a} | awk -F "#" '{print $7}'`
    tunnel_sni=`echo ${a} | awk -F "#" '{print $8}'`
    remarks=`echo ${a} | awk -F "#" '{print $9}'`
}

#添加Realm转发规则
Add_Realm(){
Set_Config
echo -e "--------${Green_font_prefix} 规则添加成功! ${Font_color_suffix}--------"
read -p "输入任意键按回车返回主菜单"
start_menu
}

#查看规则
Check_Realm(){
    echo -e "                      Realm 配置                        "
    echo -e "--------------------------------------------------------"
    echo -e "序号|方法\t|本地端口\t|目标地址:端口\t|备注信息"
    echo -e "--------------------------------------------------------"

    count_line=$(awk 'END{print NR}' $raw_conf_path)
    for((i=1;i<=$count_line;i++))
    do
        trans_conf=$(sed -n "${i}p" $raw_conf_path)
        eachconf_retrieve
        if [ "$tunnel_type" == "n" ]; then
            str="端口转发"
        elif [ "$tunnel_type" == "c" ]; then
            str="隧道转发"
        elif [ "$tunnel_type" == "s" ]; then
            str="隧道接收"
        fi
        echo -e " $i  |$str |$listening_ports\t|$remote_addresses:$remote_ports\t|$remarks"
        echo -e "--------------------------------------------------------"
    done
read -p "输入任意键按回车返回主菜单"
start_menu
}

#删除Realm转发规则
Delete_Realm(){
    echo -e "                      Realm 配置                        "
    echo -e "--------------------------------------------------------"
    echo -e "序号|方法\t|本地端口\t|目标地址:端口\t|备注信息"
    echo -e "--------------------------------------------------------"

    count_line=$(awk 'END{print NR}' $raw_conf_path)
    for((i=1;i<=$count_line;i++))
    do
        trans_conf=$(sed -n "${i}p" $raw_conf_path)
        eachconf_retrieve
        if [ "$tunnel_type" == "n" ]; then
            str="端口转发"
        elif [ "$tunnel_type" == "c" ]; then
            str="隧道转发"
        elif [ "$tunnel_type" == "s" ]; then
            str="隧道接收"
        fi
        echo -e " $i  |$str |$listening_ports\t|$remote_addresses:$remote_ports\t|$remarks"
        echo -e "--------------------------------------------------------"
    done
    read -p "请输入你要删除的配置序号：" numdelete
    sed -i "${numdelete}d" $raw_conf_path
    nu=${numdelete}-1
    temp=$(jq 'del(.endpoints['$nu'])' $realm_conf_path)
    echo $temp >$realm_conf_path
    clear
    $(systemctl restart realm)
    echo -e "------------------${Green_font_prefix}配置已删除,服务已重启${Font_color_suffix}-----------------"
    sleep 2s
    clear
    echo -e "----------------------${Green_font_prefix}当前配置如下${Font_color_suffix}----------------------"
    echo -e "--------------------------------------------------------"
    Check_Realm
    read -p "输入任意键按回车返回主菜单"
    start_menu
}

#修改realm规则
Edit_Realm(){
    echo -e "                      Realm 配置                        "
    echo -e "--------------------------------------------------------"
    echo -e "序号|方法\t|本地端口\t|目标地址:端口\t|备注信息"
    echo -e "--------------------------------------------------------"

    count_line=$(awk 'END{print NR}' $raw_conf_path)
    for((i=1;i<=$count_line;i++))
    do
        trans_conf=$(sed -n "${i}p" $raw_conf_path)
        eachconf_retrieve
        if [ "$tunnel_type" == "n" ]; then
            str="端口转发"
        elif [ "$tunnel_type" == "c" ]; then
            str="隧道转发"
        elif [ "$tunnel_type" == "s" ]; then
            str="隧道接收"
        fi
        echo -e " $i  |$str |$listening_ports\t|$remote_addresses:$remote_ports\t|$remarks"
        echo -e "--------------------------------------------------------"
    done
    read -p "请输入你要修改的配置序号：" numedit
    echo -e "------------------${Red_font_prefix}修改功能暂未完善，请删除规则然后添加规则${Font_color_suffix}-----------------"
    #systemctl restart realm
    #echo -e "------------------${Red_font_prefix}配置已修改,服务已重启${Font_color_suffix}-----------------"
    sleep 2s
    clear
    echo -e "----------------------${Green_font_prefix}当前配置如下${Font_color_suffix}----------------------"
    echo -e "--------------------------------------------------------"
    Check_Realm
    read -p "输入任意键按回车返回主菜单"
    start_menu
}

#更新脚本
Update_Shell(){
    echo -e "当前版本为 [ ${shell_version} ]，开始检测最新版本..."
    ol_version=$(curl --silent --location --connect-timeout 5 --retry 1 "https://ghfast.top/https://raw.githubusercontent.com/terminodev/titanicsite7/main/realm.sh" | grep "shell_version=" | head -1 | awk -F '=|"' '{print $3}')
    if [[ x"${ol_version}" == x ]]; then
        print_error "版本获取失败，可到GitHub更新脚本"
        before_show_menu
        return 0
    fi
    if [[ "$shell_version" != "$(echo -e "$shell_version\n$ol_version" | sort -rV | head -1)" ]]; then
        print_ok "存在新版本，是否更新 [Y/N]?"
        read -rp "(默认: y):" update_confirm
        [[ -z "${update_confirm}" ]] && update_confirm="y"
        case $update_confirm in
        [yY][eE][sS] | [yY])
          wget -N --no-check-certificate https://ghfast.top/https://raw.githubusercontent.com/terminodev/titanicsite7/main/realm.sh -O ${shelldir}/realm.sh && chmod +x ${shelldir}/realm.sh
          print_ok "更新完成"
          print_ok "请通过 bash $0 重新运行脚本"
          exit 0
        ;;
        *) ;;
        esac
    else
        print_ok "当前版本为最新版本，无需更新"
        print_ok "请通过 bash $0 重新运行脚本"
    fi
}

#备份配置
Backup(){
    if test -a /opt/realm/rawconf;then
    cp /opt/realm/rawconf /opt/realm/rawconf.back
    echo -e " ${Green_font_prefix}备份完成！${Font_color_suffix}"
    sleep 3s
    start_menu
    else
    echo -e " ${Red_font_prefix}未找到配置文件，备份失败${Font_color_suffix}"
    sleep 3s
    start_menu
    fi
}

#恢复配置
Recovey(){
    if test -a /opt/realm/rawconf.back;then
    rm -f /opt/realm/rawconf
    cp /opt/realm/rawconf.back /opt/realm/rawconf
    echo -e " ${Green_font_prefix}恢复完成！${Font_color_suffix}"
    sleep 3s
    start_menu
    else
    echo -e " ${Red_font_prefix}未找到备份文件，恢复失败${Font_color_suffix}"
    sleep 3s
    start_menu
    fi
}

#备份/恢复配置
Backup_Recovey(){
clear
echo -e "
 ${Green_font_prefix}1.${Font_color_suffix} 备份配置
 ${Green_font_prefix}2.${Font_color_suffix} 恢复配置
 ${Green_font_prefix}3.${Font_color_suffix} 删除备份"
echo
 read -p " 请输入数字后[1-2] 按回车键:" num2
 case "$num2" in
    1)
     Backup
    ;;
    2)
     Recovey 
    ;;
    3)
     if test -a /opt/realm/rawconf.back;then
       rm -f /opt/realm/rawconf.back
       echo -e " ${Green_font_prefix}删除成功！${Font_color_suffix}"
       sleep 3s
       start_menu
     else
       echo -e " ${Red_font_prefix}未找到备份文件，删除失败${Font_color_suffix}"   
       sleep 3s
       start_menu
     fi
    ;;
    *)
     esac
     echo -e "${Error}:请输入正确数字 [1-2] 按回车键"
     sleep 3s
     Backup_Recovey
}

#初始化Realm配置
Init_Realm(){
    confirm "本功能强制初始化Realm，数据会丢失，是否继续?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${Red}已取消${Font}"
        before_show_menu
        return 0
    fi
    rm -rf /opt/realm/rawconf
    rm -rf /opt/realm/config.json
    Write_config
    read -p "初始化成功,输入任意键按回车返回主菜单"
    start_menu
}

#重载Realm配置
Reload_Realm(){
    rm -rf /opt/realm/config.json
    Write_config
    count_line=$(awk 'END{print NR}' $raw_conf_path)
    for((i=1;i<=$count_line;i++))
    do
        trans_conf=$(sed -n "${i}p" $raw_conf_path)
        eachconf_retrieve
        if [[ "${tunnel_type}" == n ]]; then
            JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports"}'
            JSON=${JSON/listening_ports/$listening_ports}
            JSON=${JSON/remote_addresses/$remote_addresses}
            JSON=${JSON/remote_ports/$remote_ports}
            temp=$(jq --argjson data $JSON '.endpoints += [$data]' $realm_conf_path)
            echo $temp >$realm_conf_path
        else
            if [[ "${tunnel_mode}" == ws ]]; then
                JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports","tunnel_type":"ws;host=example.com;path=/chat"}'
                JSON=${JSON/listening_ports/$listening_ports}
                JSON=${JSON/remote_addresses/$remote_addresses}
                JSON=${JSON/remote_ports/$remote_ports}
                if [[ "${tunnel_type}" == c ]]; then
                    JSON=${JSON/tunnel_type/remote_transport}
                else
                    JSON=${JSON/tunnel_type/listen_transport}
                fi
                JSON=${JSON/example.com/$tunnel_host}
                JSON=${JSON/\/chat/$tunnel_path}
                temp=$(jq --argjson data $JSON '.endpoints += [$data]' $realm_conf_path)
                echo $temp >$realm_conf_path
            elif [[ "${tunnel_mode}" == tls ]]; then
                if [[ "${tunnel_type}" == c ]]; then
                    JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports","tunnel_type":"tls;sni=snidomain.com;insecure"}'
                    JSON=${JSON/tunnel_type/remote_transport}
                else
                    JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports","tunnel_type":"tls;servername=snidomain.com"}'
                    JSON=${JSON/tunnel_type/listen_transport}
                fi
                JSON=${JSON/listening_ports/$listening_ports}
                JSON=${JSON/remote_addresses/$remote_addresses}
                JSON=${JSON/remote_ports/$remote_ports}
                JSON=${JSON/snidomain.com/$tunnel_sni}
                temp=$(jq --argjson data $JSON '.endpoints += [$data]' $realm_conf_path)
                echo $temp >$realm_conf_path
            elif [[ "${tunnel_mode}" == wss ]]; then
                if [[ "${tunnel_type}" == c ]]; then
                    JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports","tunnel_type":"ws;host=example.com;path=/chat;tls;sni=snidomain.com;insecure"}'
                    JSON=${JSON/tunnel_type/remote_transport}
                else
                    JSON='{"listen":"[::]:listening_ports","remote":"remote_addresses:remote_ports","tunnel_type":"ws;host=example.com;path=/chat;tls;servername=snidomain.com"}'
                    JSON=${JSON/tunnel_type/listen_transport}
                fi
                JSON=${JSON/listening_ports/$listening_ports}
                JSON=${JSON/remote_addresses/$remote_addresses}
                JSON=${JSON/remote_ports/$remote_ports}
                JSON=${JSON/example.com/$tunnel_host}
                JSON=${JSON/\/chat/$tunnel_path}
                JSON=${JSON/snidomain.com/$tunnel_sni}
                temp=$(jq --argjson data $JSON '.endpoints += [$data]' $realm_conf_path)
                echo $temp >$realm_conf_path
            fi
        fi
    done
  systemctl restart realm
  read -p "重载配置成功,输入任意键按回车返回主菜单"
  start_menu
}

#Realm定时重启任务
Time_Task(){
  clear
  echo -e "#############################################################"
  echo -e "#                       Realm定时重启任务                   #"
  echo -e "#############################################################" 
  echo -e   
  crontab -l > /tmp/cronconf
  echo -e "${Green_font_prefix}1.配置Realm定时重启任务${Font_color_suffix}"
  echo -e "${Red_font_prefix}2.删除Realm定时重启任务${Font_color_suffix}"
  read -p "请选择: " numtype
  if [ "$numtype" == "1" ]; then  
      if grep -wq "systemctl restart realm" /tmp/cronconf;then
          sed -i "/systemctl restart realm/d" /tmp/cronconf
      fi
      echo -e "请选择定时重启任务类型:"
      echo -e "1.分钟 2.小时 3.天(默认)" 
      read -p "请输入类型: " type_num
      [[ -z ${type_num} ]] && type_num="3"
      case "$type_num" in
        1)
      echo -e "请设置每多少分钟重启Realm任务"   
      read -p "请设置分钟数(默认30分钟): " type_m
      [[ -z ${type_m} ]] && type_m="30"
      echo "*/$type_m * * * *  systemctl restart realm" >> /tmp/cronconf
        ;;
        2)
      echo -e "请设置每多少小时重启Realm任务"   
      read -p "请设置小时数(默认6小时): " type_h
      [[ -z ${type_h} ]] && type_h="6"
      echo "0 */$type_h * * *  systemctl restart realm" >> /tmp/cronconf
        ;;
        3)
      echo -e "请设置每多少天重启Realm任务"    
      read -p "请设置天数(默认1天): " type_d
      [[ -z ${type_d} ]] && type_d="1"
      echo "0 6 */$type_d * *  systemctl restart realm" >> /tmp/cronconf
        ;;
        *)
        clear
        echo -e "${Error}:请输入正确数字 [1-3] 按回车键"
        sleep 3s
        Time_Task
        ;;
      esac
      crontab /tmp/cronconf
      echo -e "${Green_font_prefix}设置成功!${Font_color_suffix}"   
      read -p "输入任意键按回车返回主菜单"
      start_menu   
  elif [ "$numtype" == "2" ]; then
      if grep -wq "systemctl restart realm" /tmp/cronconf;then
          sed -i "/systemctl restart realm/d" /tmp/cronconf
      fi
      crontab /tmp/cronconf
      echo -e "${Green_font_prefix}定时重启任务删除完成！${Font_color_suffix}"
      read -p "输入任意键按回车返回主菜单"
      start_menu    
  else
      echo "输入错误，请重新输入！"
      sleep 3s
      Time_Task
  fi
  rm -f /tmp/cronconf  
}

#Realm自动更新任务
Autoupgrade_Task(){
  clear
  echo -e "#############################################################"
  echo -e "#                       Realm自动更新任务                   #"
  echo -e "#############################################################" 
  echo -e   
  crontab -l > /tmp/cronconf
  echo -e "${Green_font_prefix}1.配置Realm自动更新任务${Font_color_suffix}"
  echo -e "${Red_font_prefix}2.删除Realm自动更新任务${Font_color_suffix}"
  read -p "请选择: " numtype
  if [ "$numtype" == "1" ]; then  
      if grep -wq "echo autoupgrade" /tmp/cronconf;then
          sed -i "/echo autoupgrade/d" /tmp/cronconf
      fi
      echo -e "请选择自动更新任务类型:"
      echo -e "1.分钟 2.小时 3.天" 
      read -p "请输入类型: " type_num
      case "$type_num" in
        1)
      echo -e "请设置每多少分钟自动更新Realm任务"   
      read -p "请设置分钟数: " type_m
      echo "*/$type_m * * * *  echo autoupgrade | bash ${shelldir}/realm.sh" >> /tmp/cronconf
        ;;
        2)
      echo -e "请设置每多少小时自动更新Realm任务"   
      read -p "请设置小时数: " type_h
      echo "0 */$type_h * * *  echo autoupgrade | bash ${shelldir}/realm.sh" >> /tmp/cronconf
        ;;
        3)
      echo -e "请设置每多少天自动更新Realm任务"    
      read -p "请设置天数: " type_d
      echo "0 0 */$type_d * *  echo autoupgrade | bash ${shelldir}/realm.sh" >> /tmp/cronconf
        ;;
        *)
        clear
        echo -e "${Error}:请输入正确数字 [1-3] 按回车键"
        sleep 3s
        Autoupgrade_Task
        ;;
      esac
      crontab /tmp/cronconf
      echo -e "${Green_font_prefix}设置成功!${Font_color_suffix}"   
      read -p "输入任意键按回车返回主菜单"
      start_menu   
  elif [ "$numtype" == "2" ]; then
      if grep -wq "echo autoupgrade" /tmp/cronconf;then
          sed -i "/echo autoupgrade/d" /tmp/cronconf
      fi
      crontab /tmp/cronconf
      echo -e "${Green_font_prefix}自动更新任务删除完成！${Font_color_suffix}"
      read -p "输入任意键按回车返回主菜单"
      start_menu    
  else
      echo "输入错误，请重新输入！"
      sleep 3s
      Autoupgrade_Task
  fi
  rm -f /tmp/cronconf  
}

#主菜单
start_menu(){
clear
echo -e ""
echo -e "\tRealm 安装管理脚本  ${Red}[${shell_version}]${Font}"
echo -e ""
echo -e "
—————————————— 安装向导 ——————————————
 ${Green_font_prefix}0.${Font_color_suffix} 更新脚本
 ${Green_font_prefix}1.${Font_color_suffix} 安装 Realm
 ${Green_font_prefix}2.${Font_color_suffix} 更新 Realm
 ${Green_font_prefix}3.${Font_color_suffix} 卸载 Realm
—————————————— 服务管理 ——————————————
${Green_font_prefix}11.${Font_color_suffix} 启动 Realm
${Green_font_prefix}12.${Font_color_suffix} 停止 Realm
${Green_font_prefix}13.${Font_color_suffix} 重启 Realm
${Green_font_prefix}14.${Font_color_suffix} 查看 Realm 状态 
${Green_font_prefix}15.${Font_color_suffix} 设置 Realm 开机自启
${Green_font_prefix}16.${Font_color_suffix} 取消 Realm 开机自启
—————————————— 规则管理 ——————————————
${Green_font_prefix}21.${Font_color_suffix} 添加一条 Realm 规则
${Green_font_prefix}22.${Font_color_suffix} 删除一条 Realm 规则
${Green_font_prefix}23.${Font_color_suffix} 修改一条 Realm 规则
${Green_font_prefix}24.${Font_color_suffix} 查看所有 Realm 规则
${Green_font_prefix}25.${Font_color_suffix} 重新加载 Realm 规则文件(/opt/realm/rawconf)
${Green_font_prefix}26.${Font_color_suffix} 初始化   Realm 规则
—————————————— 其他选项 ——————————————
${Green_font_prefix}31.${Font_color_suffix} 备份/恢复配置文件
${Green_font_prefix}32.${Font_color_suffix} 设置定时重启任务
${Green_font_prefix}33.${Font_color_suffix} 设置自动更新Realm
${Green_font_prefix}40.${Font_color_suffix} 退出脚本
"
 show_status
echo &&read -p " 请输入数字后，按回车键:" num
case "$num" in
    1)
    Install_Realm
    ;;
    2)
    autoupgrade=0
    Update_Realm
    ;;
    3)
    Uninstall_Realm
    ;;
    11)
    Start_Realm
    ;;
    12)
    Stop_Realm
    ;;  
    13)
    Restart_Realm
    ;;
    14)
    Status_Realm
    ;;
    15)
    Enable_Realm
    ;;
    16)
    Disable_Realm
    ;;      
    21)
    Add_Realm
    ;;
    22)
    Delete_Realm
    ;;
    23)
    Edit_Realm
    ;;
    24)
    Check_Realm
    ;;
    25)
    Reload_Realm
    ;;
    26)
    Init_Realm
    ;;
    31)
    Backup_Recovey
    ;;
    32)
    Time_Task
    ;;
    33)
    Autoupgrade_Task
    ;;
    40)
    exit 0
    ;;
    0)
    Update_Shell
    ;;
    autoupgrade)
    autoupgrade=1
    Update_Realm
    ;;
    *)
    print_error "请输入正确的数字"
    ;;
esac
}
start_menu
