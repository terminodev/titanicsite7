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

# 封装的检测函数
detect_os() {
    local release=$1
    local file=$2
    if cat "$file" | grep -Eqi "$release"; then
        echo "$release"
    fi
}

# 检测操作系统
release=""
if release=$(detect_os "centos" /etc/issue) || release=$(detect_os "red hat|redhat" /etc/issue) || release=$(detect_os "debian" /etc/issue) || release=$(detect_os "ubuntu" /etc/issue); then
# 如果 /etc/issue 没有检测到，尝试 /proc/version
    if [ -z "$release" ]; then
        release=$(detect_os "debian" /proc/version) || release=$(detect_os "ubuntu" /proc/version) || release=$(detect_os "centos|red hat|redhat" /proc/version)
    fi
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
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
        if [[ ${os_version} -lt 16 ]]; then
            echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
        fi
        ;;
    debian)
        if [[ ${os_version} -lt 8 ]]; then
            echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
        fi
        ;;
esac

install_content() {
  local _install_flags="$1"
  local _content="$2"
  local _destination="$3"
  local _overwrite="$4"

  local _tmpfile="$(mktemp)"

  echo -ne "Install $_destination ... "
  echo "$_content" > "$_tmpfile"
  if [[ -z "$_overwrite" && -e "$_destination" ]]; then
    echo -e "exists"
  elif install "$_install_flags" "$_tmpfile" "$_destination"; then
    echo -e "ok"
  fi

  rm -f "$_tmpfile"
}

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

tpl_hysteria_config_yaml() {
  cat << EOF
v2board:
  apiHost: http://127.0.0.1:667
  apiKey: 123
  nodeID: 41
acme:
  domains:
    - your.domain.net
  email: your@email.com
auth:
  type: v2board
acl: 
  inline: 
    - reject(10.0.0.0/8)
    - reject(172.16.0.0/12)
    - reject(192.168.0.0/16)
    - reject(127.0.0.0/8)
    - reject(fc00::/7)
masquerade:
  type: proxy
  proxy:
    url: https://news.ycombinator.com/
    rewriteHost: true
EOF
}

install_Hysteria2() {
    apidomain=$(awk -F[/:] '{print $4}' <<< ${apihost})
    hy2name=${apidomain}_${nodetype}_${nodeid}
    docker ps | grep -wq "hy2_${hy2name}"
    if [[ $? -eq 0 ]]; then
        docker stop hy2_${hy2name}
        docker rm -f hy2_${hy2name}
        docker network disconnect --force host hy2_${hy2name} >/dev/null 2>&1
    fi
    [ -e /opt/hy2 ] || mkdir -p /opt/hy2/
    install_content -Dm644 "$(tpl_hysteria_config_yaml)" "/opt/hy2/config_${hy2name}.yml" "1"
    sed -i "s?http://127.0.0.1:667?${apihost}?" /opt/hy2/config_${hy2name}.yml
    sed -i "s/123/${apikey}/" /opt/hy2/config_${hy2name}.yml
    sed -i "s/41/${nodeid}/" /opt/hy2/config_${hy2name}.yml
    sed -i "s/\"v2board\"/\"${paneltype}\"/" /opt/hy2/config_${hy2name}.yml
    sed -i "s/your.domain.net/${certdomain}/" /opt/hy2/config_${hy2name}.yml
    sed -i "s/your@email.com/${email}/" /opt/hy2/config_${hy2name}.yml
    docker pull ghcr.io/cedar2025/hysteria:latest
    docker run --restart=always --log-opt max-size=5m --log-opt max-file=3 --name hy2_${hy2name} -d -v /opt/hy2/config_${hy2name}.yml:/etc/hysteria/server.yaml --network=host ghcr.io/cedar2025/hysteria:latest
    docker ps | grep -wq "hy2_${hy2name}"
    if [[ $? -eq 0 ]]; then
        crontab -l > /tmp/cronconf
        if grep -wq "hy2_${hy2name}" /tmp/cronconf;then
            sed -i "/hy2_${hy2name}/d" /tmp/cronconf
        fi
        echo "0 6 * * *  docker restart hy2_${hy2name}" >> /tmp/cronconf
        crontab /tmp/cronconf
        rm -f /tmp/cronconf
        echo -e "${green}将添加每天6点0分自动重启，以释放节点内存![${nodeid}]${plain}"
        crontab -l | grep -w "hy2_${hy2name}"
        echo -e "${green}节点[${nodeid}]安装完成!${plain}"
        echo -e "${green}如无法使用，输入命令查看日志：docker logs hy2_${hy2name} ${plain}"
        docker ps
    fi
}

hello(){
    echo ""
    echo -e "${yellow}Hysteria2 Docker版后端一键安装，可以节点多开${plain}"
    echo -e "${yellow}支持系统:  CentOS7+, Debian10+, Ubuntu18+${plain}"
    echo ""
}

help(){
    hello
    echo "使用示例：bash $0 -p SSpanel -w http://www.domain.com:80 -k apikey -i 10 -t V2ray"
    echo ""
    echo "  -h     显示帮助信息"
    echo "  -p     【选填】指定前端面板类型，默认为v2board，可选：v2board"
    echo "  -w     【必填】指定WebApi地址，例：http://www.domain.com:80"
    echo "  -k     【必填】指定WebApikey"
    echo "  -i     【必填】指定节点ID"
    echo "  -m     【必填】指定获取证书的方式，默认为http，可选：file,http,dns"
    echo "                 获取ssl证书方式暂不支持file，http模式请确保80端口不被其他程序占用"
    echo "  -d     【必填】指定申请证书域名，无默认值，请提前做好解析"
    echo "  -r     【选填】指定dns提供商，所有支持的dns提供商请在此获取：https://go-acme.github.io/lego/dns，模式为dns时必填"
    echo "  -e     【必填】注册acme服务所用的账户"
    echo ""
}

apihost=www.domain.com
apikey=demokey
nodeid=demoid
certmode=http
certdomain=cert.domain.com
provider=alidns
email=your@email.com
dnsenv1="ALICLOUD_ACCESS_KEY: aaa"
dnsenv2="ALICLOUD_SECRET_KEY: bbb"

# -p PanelType
# -w webApiHost
# -k webApiKey
# -i NodeID
# -m CertMode
# -d CertDomain
# -e Email
# -r Provider
# -h help
if [[ $# -eq 0 ]];then
    help
    exit 1
fi
while getopts ":p:w:k:i:m:d:r:e:h" optname
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
        email=$OPTARG
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
    echo -e "${yellow}前端面板类型：v2board (未指定默认使用该值)${plain}"
    paneltype=v2board
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
if [[ x"${certdomain}" == x"cert.domain.com" ]]; then
    echo -e "${red}未输入 -d 选项，请重新运行${plain}"
    exit 1
else
    echo -e "${green}证书域名：${certdomain}${plain}"
    IP=$(curl ipget.net)
    domainIP=$(curl ipget.net/?ip="$certdomain")
    if [ $IP != $domainIP ]; then
        echo -e "${red}域名解析IP不匹配${plain}"
        echo -e "${red}请确认DNS已正确解析到VPS，或CloudFlare的小云朵没关闭，请关闭小云朵后重试${plain}"
        exit 1
    fi
fi
if [[ x"${email}" == x"your@email.com" ]]; then
    echo -e "${red}未输入 -e 选项，请重新运行${plain}"
    exit 1
else
    echo -e "${green}邮箱账户：${email}${plain}"
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
install_Hysteria2
