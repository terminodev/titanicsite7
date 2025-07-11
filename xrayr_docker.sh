#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    # 使用国际化错误信息
    echo -e "${red}Error: ${plain}This script must be run as root user!\n"
    # 给出指导性建议
    echo "You can use sudo to run this script if you have the permission."
    exit 1
fi

# 检测操作系统版本
if [[ -f /etc/redhat-release ]]; then
    release="centos"
else
    issue_content=$(cat /etc/issue)
    proc_version_content=$(cat /proc/version)

    if echo "$issue_content" | grep -Eqi "debian"; then
        release="debian"
    elif echo "$issue_content" | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif echo "$issue_content" | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif echo "$proc_version_content" | grep -Eqi "debian"; then
        release="debian"
    elif echo "$proc_version_content" | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif echo "$proc_version_content" | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    else
        echo -e "${red}未检测到系统版本，请联系作者！${plain}\n" && exit 1
    fi
fi

# 检查系统架构
if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "${red}未本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者${plain}\n"
    exit 2
fi

os_version=""

# 获取操作系统版本
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
elif [[ -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

# 检查操作系统版本是否满足要求
case "${release}" in
    centos)
        if [[ ${os_version} -le 6 ]]; then
            echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
        fi
        ;;
    ubuntu)
        if [[ ${os_version} -lt 18 ]]; then
            echo -e "${red}请使用 Ubuntu 18 或更高版本的系统！${plain}\n" && exit 1
        fi
        ;;
    debian)
        if [[ ${os_version} -lt 9 ]]; then
            echo -e "${red}请使用 Debian 9 或更高版本的系统！${plain}\n" && exit 1
        fi
        ;;
esac

install_dep(){
        if [[ x"${release}" == x"centos" ]]; then
            yum clean all
            yum makecache
            if [ ${os_version} -eq 7 ]; then
                yum install epel-release -y
                yum install wget curl unzip tar crontabs socat yum-utils ca-certificates -y
            elif [ ${os_version} -ge 8 ]; then
                dnf -y install epel-release
                dnf -y install wget curl unzip tar crontabs socat yum-utils ca-certificates
            fi
        elif [[ x"${release}" == x"ubuntu" ]]; then
            apt update -y
            apt install -y wget curl unzip tar cron socat apt-transport-https ca-certificates gnupg lsb-release
        elif [[ x"${release}" == x"debian" ]]; then
            apt update -y
            apt install -y wget curl unzip tar cron socat apt-transport-https ca-certificates gnupg lsb-release
        fi
}

install_docker() {
    command_exists=$(command -v docker)
    if [[ -z "$command_exists" ]]; then
        if [[ x"${release}" == x"centos" ]]; then
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install docker-ce docker-ce-cli containerd.io -y
            systemctl enable docker --now
        elif [[ x"${release}" == x"ubuntu" ]]; then
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update -y
            apt-get install docker-ce docker-ce-cli containerd.io -y
            systemctl enable docker --now
        elif [[ x"${release}" == x"debian" ]]; then
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update -y
            apt-get install docker-ce docker-ce-cli containerd.io -y
            systemctl enable docker --now
        fi
    fi
}

install_XrayR() {
    apidomain=$(awk -F[/:] '{print $4}' <<< ${apihost})
    xrayrname=${apidomain}_${nodetype}_${nodeid}
    docker ps | grep -wq "xrayr_${xrayrname}"
    if [[ $? -eq 0 ]]; then
        docker stop xrayr_${xrayrname}
        docker rm -f xrayr_${xrayrname}
        docker network disconnect --force host xrayr_${xrayrname} >/dev/null 2>&1
    fi
    [ -e /opt/xrayr ] || mkdir -p /opt/xrayr/
    wget -N --no-check-certificate -O /opt/xrayr/config_${xrayrname}.yml https://raw.githubusercontent.com/XrayR-project/XrayR/master/release/config/config.yml.example
    wget -N --no-check-certificate -O /opt/xrayr/dns_${xrayrname}.json https://raw.githubusercontent.com/XrayR-project/XrayR/master/release/config/dns.json
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载失败，请确保服务器可以连接github.com${plain}"
        exit 1
    fi
    sed -i "s/Level: warning/Level: none/" /opt/xrayr/config_${xrayrname}.yml
    sed -i "s/\"SSpanel\"/\"${paneltype}\"/" /opt/xrayr/config_${xrayrname}.yml
    sed -i "s?http://127.0.0.1:667?${apihost}?" /opt/xrayr/config_${xrayrname}.yml
    sed -i "s/123/${apikey}/" /opt/xrayr/config_${xrayrname}.yml
    sed -i "s/41/${nodeid}/" /opt/xrayr/config_${xrayrname}.yml
    sed -i "s/NodeType: V2ray/NodeType: ${nodetype}/" /opt/xrayr/config_${xrayrname}.yml
    if [[ x"${security}" == x"none" ]]; then
        sed -i "s/EnableREALITY: true/EnableREALITY: false/" /opt/xrayr/config_${xrayrname}.yml
    fi
    sed -i "s/CertMode: dns/CertMode: ${certmode}/" /opt/xrayr/config_${xrayrname}.yml
    sed -i "s/CertDomain: \"node1.test.com\"/CertDomain: \"${certdomain}\"/" /opt/xrayr/config_${xrayrname}.yml
    sed -i "s/Provider: alidns/Provider: ${provider}/" /opt/xrayr/config_${xrayrname}.yml
    sed -i "s/ALICLOUD_ACCESS_KEY: aaa/${dnsenv1}/" /opt/xrayr/config_${xrayrname}.yml
    if [[ x"${dnsenv2}" == x"ALICLOUD_SECRET_KEY: bbb" ]]; then
        sed -i "/ALICLOUD_SECRET_KEY: bbb/d" /opt/xrayr/config_${xrayrname}.yml
    else
        sed -i "s/ALICLOUD_SECRET_KEY: bbb/${dnsenv2}/" /opt/xrayr/config_${xrayrname}.yml
    fi
    docker pull ghcr.io/xrayr-project/xrayr:latest
    docker run --restart=always --log-opt max-size=5m --log-opt max-file=3 --name xrayr_${xrayrname} -d -v /opt/xrayr/config_${xrayrname}.yml:/etc/XrayR/config.yml -v /opt/xrayr/dns_${xrayrname}.json:/etc/XrayR/dns.json --network=host ghcr.io/xrayr-project/xrayr:latest
    docker ps | grep -wq "xrayr_${xrayrname}"
    if [[ $? -eq 0 ]]; then
        # 使用mktemp创建安全的临时文件
        tmpfile=$(mktemp)
        # 备份当前crontab到临时文件
        crontab -l > "${tmpfile}"
        # 检查并删除已存在的相同任务
        if grep -wq "xrayr_${xrayrname}" "${tmpfile}"; then
            sed -i "/xrayr_${xrayrname}/d" "${tmpfile}"
        fi
        # 添加新的重启任务
        echo "0 6 * * *  docker restart xrayr_${xrayrname}" >> "${tmpfile}"
        # 替换当前crontab
        crontab "${tmpfile}"
        # 删除临时文件
        rm -f "${tmpfile}"
        # 输出确认信息
        echo -e "${green}将添加每天6点0分自动重启，以释放节点内存！[${nodeid}]${plain}"
        # 检查新的crontab中是否包含任务
        crontab -l | grep -w "xrayr_${xrayrname}"
        echo -e "${green}节点[${nodeid}]安装完成!${plain}"
        echo -e "${green}如无法使用，输入命令查看日志：docker logs xrayr_${xrayrname} ${plain}"
        docker ps
    fi
}

hello(){
    echo ""
    echo -e "${yellow}XrayR Docker版一键安装脚本，支持节点多开${plain}"
    echo -e "${yellow}支持系统:  CentOS7+, Debian9+, Ubuntu18+${plain}"
    echo ""
}

help(){
    hello
    echo "使用示例：bash $0 -p SSpanel -w http://www.domain.com:80 -k apikey -i 10 -t V2ray"
    echo ""
    echo "  -h     显示帮助信息"
    echo "  -p     【必填】指定前端面板类型，默认为SSpanel，可选：SSpanel,NewV2board,PMpanel,Proxypanel,V2RaySocks"
    echo "  -w     【必填】指定WebApi地址，例：http://www.domain.com:80"
    echo "  -k     【必填】指定WebApikey"
    echo "  -i     【必填】指定节点ID"
    echo "  -t     【选填】指定节点类型，默认为V2ray，可选：V2ray, Shadowsocks, Trojan"
    echo "  -m     【选填】指定获取证书的方式，默认为none，可选：none,file,http,dns，V2ray+tls和Trojan模式下必填"
    echo "                 获取ssl证书方式暂不支持file，http模式请确保80端口不被其他程序占用"
    echo "  -d     【选填】指定申请证书域名，无默认值，请提前做好解析，V2ray+tls和Trojan模式下必填"
    echo "  -r     【选填】指定dns提供商，所有支持的dns提供商请在此获取：https://go-acme.github.io/lego/dns，模式为dns时必填"
    echo "  -e     【选填】采用DNS申请证书需要的环境变量，请参考上文链接内，模式为dns时必填"
    echo "  -n     【选填】采用DNS申请证书需要的环境变量，请参考上文链接内，模式为dns时必填"
    echo ""
}

apihost=www.domain.com
apikey=demokey
nodeid=demoid
security=none
certmode=none
certdomain=cert.domain.com
provider=alidns
dnsenv1="ALICLOUD_ACCESS_KEY: aaa"
dnsenv2="ALICLOUD_SECRET_KEY: bbb"

# -p PanelType
# -w webApiHost
# -k webApiKey
# -i NodeID
# -t NodeType
# -m CertMode
# -d CertDomain
# -e Email
# -r Provider
# -e DNSEnv
# -n DNSEnv
# -h help
if [[ $# -eq 0 ]];then
    help
    exit 1
fi
while getopts ":p:w:k:i:t:m:d:r:e:n:h" optname
do
    case "$optname" in
      "p")
        paneltype=$OPTARG
        ;;
      "w")
        apihost=$OPTARG
        ;;
      "k")
        apikey=$OPTARG
        ;;
      "i")
        nodeid=$OPTARG
        ;;
      "t")
        nodetype=$OPTARG
        ;;
      "m")
        certmode=$OPTARG
        ;;
      "d")
        certdomain=$OPTARG
        ;;
      "r")
        provider=$OPTARG
        ;;
      "e")
        dnsenv1=$OPTARG
        ;;
      "n")
        dnsenv2=$OPTARG
        ;;
      "h")
        help
        exit 0
        ;;
      ":")
        echo "$OPTARG 选项没有参数值"
        ;;
      "?")
        echo "$OPTARG 选项未知"
        ;;
      *)
        help
        exit 1
        ;;
    esac
done

echo -e "${green}您输入的参数：${plain}"
if [[ x"${apihost}" == x"www.domain.com" ]]; then
    echo -e "${red}未输入 -w 选项，请重新运行${plain}"
    exit 1
else
    echo -e "${green}前端面板地址：${apihost}${plain}"
fi
if [[ x"${paneltype}" == x ]]; then
    echo -e "${yellow}前端面板类型：SSpanel (未指定默认使用该值)${plain}"
    paneltype=SSpanel
else
    echo -e "${green}前端面板类型：${paneltype}${plain}"
fi
if [[ x"${apikey}" == x"demokey" ]]; then
    echo -e "${red}未输入 -k 选项，请重新运行${plain}"
    exit 1
else
    echo -e "${green}前端通讯秘钥：${apikey}${plain}"
fi
if [[ x"${nodeid}" == x"demoid" ]]; then
    echo -e "${red}未输入 -i 选项，请重新运行${plain}"
    exit 1
else
    echo -e "${green}节点ID：${nodeid}${plain}"
fi
if [[ x"${nodetype}" == x ]]; then
    echo -e "${yellow}节点类型：V2ray(未指定默认使用该值)${plain}"
    nodetype=V2ray
else
    echo -e "${green}节点类型：${nodetype}${plain}"
fi
if [[ x"${nodetype}" == xV2ray ]] || [[ x"${nodetype}" == xTrojan ]]; then
    if [[ x"${certmode}" == x"none" ]]; then
        echo -e "${yellow}获取证书方式：http(未指定默认使用该值)，V2ray未开启tls选项时可以忽略${plain}"
        certmode=http
    else
        echo -e "${green}获取证书方式：${certmode}${plain}"
    fi
    if [[ x"${certdomain}" == x"cert.domain.com" ]]; then
        echo -e "${yellow}未输入 -d 选项，V2ray未开启tls选项时可以忽略${plain}"
        if [[ x"${nodetype}" == xTrojan ]]; then
            exit 1
        fi
    else
        echo -e "${green}申请证书域名：${certdomain}${plain}"
    fi
    if [[ x"${certmode}" == x"dns" ]]; then
        if [[ x"${provider}" != x ]]; then
            echo -e "${green}DNS解析提供商：${provider}${plain}"
        fi
        if [[ x"${dnsenv1}" == x"ALICLOUD_ACCESS_KEY: aaa" ]]; then
            echo -e "${red}未输入 -e 选项，请重新运行${plain}"
            exit 1
        else
            echo -e "${green}DNS证书需要的环境变量1：${dnsenv1}${plain}"
        fi
        if [[ x"${dnsenv2}" == x"ALICLOUD_SECRET_KEY: bbb" ]]; then
            echo -e "${yellow}未输入 -n 选项，请确认${plain}"
        else
            echo -e "${green}DNS证书需要的环境变量2：${dnsenv2}${plain}"
        fi
    fi
fi
if [[ ! "${nodeid}" =~ ^[0-9]+$ ]]; then   
    echo -e "${red}-i 选项参数值仅限数字格式，请输入正确的参数值并重新运行${plain}"
    exit 1
fi 

echo -e "${green}即将开始安装，取消请按Ctrl+C${plain}"
# 倒计时函数，增加边界条件检查
countdown() {
    # 检查输入是否为正整数
    if ! [[ $1 =~ ^[0-9]+$ ]]; then
        echo -e "${red}Error: Countdown value must be a positive integer.${plain}"
        return 1
    fi

    local countdown=$1
    while [ $countdown -gt 0 ]
    do
        echo -ne "${yellow}${countdown}${plain}"
        (( countdown-- ))
        sleep 1
        # 使用控制序列清空当前行并回到行首
        echo -ne "\r   \r"
    done
}

# 调用倒计时函数，传入10作为参数
countdown 10
install_dep
install_docker
install_XrayR
