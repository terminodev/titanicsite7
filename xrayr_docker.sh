#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# 检查是否为root用户运行
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}Error: ${plain}This script must be run as root user!\n"
    exit 1
fi

# 检测操作系统
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    case "${ID}" in
        centos|rhel|almalinux|rocky|ol|fedora|scientific)
            release="centos"
            ;;
        debian|raspbian|mx)
            release="debian"
            ;;
        ubuntu)
            release="ubuntu"
            ;;
        *)
            if [[ "${ID_LIKE}" == *"rhel"* ]] || [[ "${ID_LIKE}" == *"centos"* ]] || [[ "${ID_LIKE}" == *"fedora"* ]]; then
                release="centos"
            elif [[ "${ID_LIKE}" == *"debian"* ]]; then
                release="debian"
            else
                fallback_os_detect
            fi
            ;;
    esac
    os_version=${VERSION_ID%%.*}
    if [[ -z "${os_version}" ]]; then
        os_version=$(echo "${VERSION_ID}" | grep -oE '^[0-9]+' | head -1)
    fi
else
    fallback_os_detect
fi

# 传统操作系统检测
fallback_os_detect() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        os_version=$(grep -oE '[0-9]+' /etc/redhat-release | head -1)
    else
        issue_content=$(cat /etc/issue 2>/dev/null || echo "")
        proc_version_content=$(cat /proc/version 2>/dev/null || echo "")
        if echo "$issue_content" | grep -Eqi "debian"; then
            release="debian"
        elif echo "$issue_content" | grep -Eqi "ubuntu"; then
            release="ubuntu"
        elif echo "$issue_content" | grep -Eqi "centos|red hat|redhat|fedora"; then
            release="centos"
        elif echo "$proc_version_content" | grep -Eqi "debian"; then
            release="debian"
        elif echo "$proc_version_content" | grep -Eqi "ubuntu"; then
            release="ubuntu"
        elif echo "$proc_version_content" | grep -Eqi "centos|red hat|redhat"; then
            release="centos"
        else
            echo -e "${red}未检测到系统版本${plain}\n" && exit 1
        fi

        if [[ -n "$issue_content" ]]; then
            os_version=$(echo "$issue_content" | grep -oE '[0-9]+' | head -1)
        fi
        if [[ -z "$os_version" ]] && [[ -n "$proc_version_content" ]]; then
            os_version=$(echo "$proc_version_content" | grep -oE '[0-9]+' | head -1)
        fi
    fi

    if [[ -z "$os_version" ]]; then
        if [[ -f /etc/os-release ]]; then
            os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
        elif [[ -f /etc/lsb-release ]]; then
            os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
        fi
    fi
}

# 检查系统架构
if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "${red}未本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者${plain}\n"
    exit 2
fi

# 检查操作系统版本号
case "${release}" in
    centos)
        if [[ ${os_version} -lt 7 ]]; then
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
                yum install wget curl crontabs socat yum-utils ca-certificates -y
            elif [ ${os_version} -ge 8 ]; then
                dnf -y install epel-release
                dnf -y install wget curl crontabs socat yum-utils ca-certificates
            fi
        elif [[ x"${release}" == x"ubuntu" ]]; then
            apt update -y
            apt install -y wget curl cron socat apt-transport-https ca-certificates gnupg lsb-release
        elif [[ x"${release}" == x"debian" ]]; then
            apt update -y
            apt install -y wget curl cron socat apt-transport-https ca-certificates gnupg lsb-release
        fi
        if ! command -v yq &> /dev/null; then
            wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq &>/dev/null && chmod +x /usr/local/bin/yq
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
    email=${nodeid}@xrayrtmp.com
    docker ps -a | grep -wq "xrayr_${xrayrname}"
    if [[ $? -eq 0 ]]; then
        docker stop xrayr_${xrayrname}
        docker rm -f xrayr_${xrayrname}
        docker network disconnect --force host xrayr_${xrayrname} >/dev/null 2>&1
    fi
    [ -e /opt/xrayr ] || mkdir -p /opt/xrayr/
    local config_file="/opt/xrayr/config_${xrayrname}.yml"
    wget -N --no-check-certificate -O "$config_file" https://raw.githubusercontent.com/XrayR-project/XrayR/master/release/config/config.yml.example
    wget -N --no-check-certificate -O /opt/xrayr/dns_${xrayrname}.json https://raw.githubusercontent.com/XrayR-project/XrayR/master/release/config/dns.json
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载失败，请确保网络可以连接到github.com${plain}"
        exit 1
    fi
    # sed -i "s/Level: warning/Level: none/" /opt/xrayr/config_${xrayrname}.yml
    # sed -i "s/\"SSpanel\"/\"${paneltype}\"/" /opt/xrayr/config_${xrayrname}.yml
    # sed -i "s?http://127.0.0.1:667?${apihost}?" /opt/xrayr/config_${xrayrname}.yml
    # sed -i "s/123/${apikey}/" /opt/xrayr/config_${xrayrname}.yml
    # sed -i "s/41/${nodeid}/" /opt/xrayr/config_${xrayrname}.yml
    # sed -i "s/NodeType: V2ray/NodeType: ${nodetype}/" /opt/xrayr/config_${xrayrname}.yml

    yq -i ".Log.Level = \"none\"" "$config_file"
    yq -i ".Nodes[0].PanelType = \"${paneltype}\"" "$config_file"
    yq -i ".Nodes[0].ApiConfig.ApiHost = \"${apihost}\"" "$config_file"
    yq -i ".Nodes[0].ApiConfig.ApiKey = \"${apikey}\"" "$config_file"
    yq -i ".Nodes[0].ApiConfig.NodeID = ${nodeid}" "$config_file"
    yq -i ".Nodes[0].ApiConfig.NodeType = \"${nodetype}\"" "$config_file"

    # TLS 相关
    if [[ x"${security}" == x"none" ]]; then
        yq -i ".Nodes[0].ControllerConfig.EnableREALITY = false" "$config_file"
    fi
    yq -i ".Nodes[0].ControllerConfig.CertConfig.CertMode = \"${certmode}\"" "$config_file"
    yq -i ".Nodes[0].ControllerConfig.CertConfig.CertDomain = \"${certdomain}\"" "$config_file"

    if [[ x"${certmode}" == x"dns" ]]; then
        yq -i ".Nodes[0].ControllerConfig.CertConfig.Email = \"${email}\"" "$config_file"
        yq -i ".Nodes[0].ControllerConfig.CertConfig.Provider = \"${provider}\"" "$config_file"
        
        # 处理环境变量
        yq -i "del(.Nodes[0].ControllerConfig.CertConfig.DNSEnv)" "$config_file"
        for var in $dnsenvs; do
            key=$(echo $var | cut -f1 -d=)
            val=$(echo $var | cut -f2 -d=)
            yq -i ".Nodes[0].ControllerConfig.CertConfig.DNSEnv.$key = \"$val\"" "$config_file"
        done
    elif [[ x"${certmode}" == x"file" ]]; then
        if [[ -f "$certfile" && -f "$keyfile" ]]; then
            yq -i ".Nodes[0].ControllerConfig.CertConfig.CertFile = \"/etc/XrayR/${xrayrname}.cert\"" "$config_file"
            yq -i ".Nodes[0].ControllerConfig.CertConfig.KeyFile = \"/etc/XrayR/${xrayrname}.key\"" "$config_file"
        else
            echo -e "${red}错误: 证书文件或私钥文件路径不存在！${plain}"
            exit 1
        fi
    fi

    local cert_mount=""
    if [[ x"${certmode}" == x"file" ]]; then
        cert_mount="-v ${certfile}:/etc/XrayR/${xrayrname}.cert -v ${keyfile}:/etc/XrayR/${xrayrname}.key"
    fi
    docker pull ghcr.io/xrayr-project/xrayr:latest
    docker run --restart=always --log-opt max-size=5m --log-opt max-file=3 \
        --name xrayr_${xrayrname} -d \
        -v "$config_file":/etc/XrayR/config.yml \
        -v /opt/xrayr/dns_${xrayrname}.json:/etc/XrayR/dns.json \
        ${cert_mount} \
        --network=host ghcr.io/xrayr-project/xrayr:latest
    if [[ $(docker ps -q -f name=xrayr_${xrayrname}) ]]; then
        tmpfile=$(mktemp)
        crontab -l > "${tmpfile}"
        if grep -wq "xrayr_${xrayrname}" "${tmpfile}"; then
            sed -i "/xrayr_${xrayrname}/d" "${tmpfile}"
        fi
        echo "0 6 * * *  docker restart xrayr_${xrayrname}" >> "${tmpfile}"
        crontab "${tmpfile}"
        rm -f "${tmpfile}"
        docker ps
        echo -e "${green}节点[${nodeid}]安装完成，并已设置每日6点定时重启！${plain}"
        echo -e "${yellow}如无法使用，请查看日志寻找原因：docker logs xrayr_${xrayrname}${plain}"
    else
        echo -e "${red}容器启动失败，请检查配置或使用 docker logs 查看原因${plain}"
    fi
}

uninstall_XrayR() {
    echo -e "${green}开始卸载 XrayR...${plain}"

    local target_container=""
    if [[ x"${uninstall_all}" == x"1" ]]; then
        echo -e "${yellow}将卸载所有 XrayR 容器${plain}"
    elif [[ x"${xrayrname}" != x ]]; then
        target_container="xrayr_${xrayrname}"
        echo -e "${yellow}将卸载容器: ${target_container}${plain}"
    else
        apidomain=$(awk -F[/:] '{print $4}' <<< ${apihost})
        if [[ x"${apidomain}" != x && x"${nodetype}" != x && x"${nodeid}" != x ]]; then
            xrayrname=${apidomain}_${nodetype}_${nodeid}
            target_container="xrayr_${xrayrname}"
            echo -e "${yellow}将卸载容器: ${target_container}${plain}"
        fi
    fi

    if [[ x"${uninstall_all}" == x"1" ]]; then
        local containers=$(docker ps -a --filter "name=xrayr_" --format "{{.Names}}")
        if [[ -z "${containers}" ]]; then
            echo -e "${yellow}未找到任何 XrayR 容器${plain}"
        else
            for container in ${containers}; do
                echo -e "${green}正在停止并删除容器: ${container}${plain}"
                docker stop ${container} >/dev/null 2>&1
                docker rm -f ${container} >/dev/null 2>&1
                local cfg_name=$(echo ${container} | sed 's/^xrayr_//')
                rm -f /opt/xrayr/config_${cfg_name}.yml
                rm -f /opt/xrayr/dns_${cfg_name}.json
                local tmpfile=$(mktemp)
                crontab -l > "${tmpfile}" 2>/dev/null || true
                if grep -wq "${container}" "${tmpfile}" 2>/dev/null; then
                    sed -i "/${container}/d" "${tmpfile}"
                    crontab "${tmpfile}"
                fi
                rm -f "${tmpfile}"
            done
            echo -e "${green}所有 XrayR 容器已卸载${plain}"
        fi
        echo -e "${yellow}是否删除 /opt/xrayr 目录？(y/n)${plain}"
        read -r confirm
        if [[ x"${confirm}" == x"y" || x"${confirm}" == x"Y" ]]; then
            rm -rf /opt/xrayr
            echo -e "${green}已删除 /opt/xrayr 目录${plain}"
        fi
    elif [[ x"${target_container}" != x ]]; then
        if docker ps -a --format "{{.Names}}" | grep -wq "${target_container}"; then
            echo -e "${green}正在停止并删除容器: ${target_container}${plain}"
            docker stop ${target_container} >/dev/null 2>&1
            docker rm -f ${target_container} >/dev/null 2>&1
            rm -f /opt/xrayr/config_${xrayrname}.yml
            rm -f /opt/xrayr/dns_${xrayrname}.json
            local tmpfile=$(mktemp)
            crontab -l > "${tmpfile}" 2>/dev/null || true
            if grep -wq "${target_container}" "${tmpfile}" 2>/dev/null; then
                sed -i "/${target_container}/d" "${tmpfile}"
                crontab "${tmpfile}"
            fi
            rm -f "${tmpfile}"
            echo -e "${green}容器 ${target_container} 已卸载${plain}"
        else
            echo -e "${red}未找到容器: ${target_container}${plain}"
            local similar=$(docker ps -a --filter "name=xrayr_" --format "{{.Names}}" | head -5)
            if [[ -n "${similar}" ]]; then
                echo -e "${yellow}现有的 XrayR 容器:${plain}"
                echo "${similar}"
            fi
        fi
    else
        echo -e "${red}未指定要卸载的容器，请使用 -w -t -i 参数指定，或使用 -a 卸载所有${plain}"
        exit 1
    fi
    
    echo -e "${green}卸载完成！${plain}"
    exit 0
}

hello(){
    echo ""
    echo -e "${yellow}XrayR Docker版一键安装脚本，支持节点多开${plain}"
    echo -e "${yellow}支持系统:  CentOS7+, Debian9+, Ubuntu18+${plain}"
    echo ""
}

help(){
    hello
    echo "使用示例：bash $0 -p SSpanel -w http://www.domain.com -k apikey -i 10 -t V2ray"
    echo ""
    echo "  -h     显示帮助信息"
    echo "  -p     【必填】前端面板类型 (默认: SSpanel)，可选：SSpanel,NewV2board,PMpanel,Proxypanel,V2RaySocks"
    echo "  -w     【必填】WebApi地址，例：http://www.domain.com"
    echo "  -k     【必填】WebApikey"
    echo "  -i     【必填】节点ID"
    echo "  -t     【选填】节点类型，默认为V2ray，可选：V2ray, Shadowsocks, Trojan"
    echo "  -m     【选填】获取证书的方式，默认为none，(none, file, http, dns)，http模式请确保80端口不被其他程序占用"
    echo "  -d     【选填】证书域名，无默认值，请提前做好解析，V2ray+tls和Trojan模式下必填"
    echo "  -r     【选填】dns提供商，所有支持的dns提供商请在此获取：https://go-acme.github.io/lego/dns，模式为dns时必填"
    echo "  -v     【选填】采用DNS申请证书的环境变量，请参考上文链接内，模式为dns时必填，多个变量请用引号，如 \"KEY1=VAL1 KEY2=VAL2\""
    echo "  -C     【选填】手动提供的证书文件，如 \"-C /opt/xrayr/certs/my.crt\""
    echo "  -K     【选填】手动提供的证书密钥文件，如 \"-K /opt/xrayr/certs/my.key\""
    echo ""
    echo "卸载选项："
    echo "  -u     【选填】卸载模式，需配合 -w -t -i 使用，或使用 -a 卸载所有"
    echo "  -a     【选填】卸载所有 XrayR 容器（与 -u 配合使用）"
    echo ""
    echo "卸载示例："
    echo "  bash $0 -u -a                    # 卸载所有 XrayR 容器"
    echo "  bash $0 -u -w http://domain.com -t V2ray -i 10   # 卸载指定节点"
    echo ""
}

# 默认值
paneltype=SSpanel
nodetype=V2ray
apihost=www.domain.com
apikey=demokey
nodeid=demoid
security=none
certmode=none
certdomain=cert.domain.com
provider=alidns

# -p PanelType
# -w webApiHost
# -k webApiKey
# -i NodeID
# -t NodeType
# -m CertMode
# -d CertDomain
# -e Email
# -r Provider
# -v DNSEnv
# -h help
# -u uninstall
# -a uninstall all
if [[ $# -eq 0 ]];then
    help
    exit 1
fi
while getopts ":p:w:k:i:t:m:d:r:v:C:K:uah" optname
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
      "v")
        dnsenvs=$OPTARG
        ;;
      "C")
        certfile=$OPTARG
        ;;
      "K")
        keyfile=$OPTARG
        ;;
      "u")
        uninstall_mode=1
        ;;
      "a")
        uninstall_all=1
        ;;
      "h")
        help; exit 0
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

if [[ x"${uninstall_mode}" == x"1" ]]; then
    uninstall_XrayR
fi
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
        echo -e "${yellow}获取证书方式：none(默认使用该值)${plain}"
    fi
    if [[ x"${certdomain}" == x"cert.domain.com" ]]; then
        echo -e "${yellow}未指定证书域名，未开启tls选项时可以忽略${plain}"
        if [[ x"${nodetype}" == xTrojan ]]; then
            exit 1
        fi
    else
        echo -e "${green}申请证书域名：${certdomain}${plain}"
    fi

    if [[ x"${certmode}" == x"dns" ]]; then
        echo -e "${green}获取证书方式：DNS 模式${plain}"
        if [[ -z "${provider}" ]]; then
            echo -e "${red}错误：DNS 模式下必须使用 -r 指定 Provider (如 alidns, cloudflare)${plain}"
            exit 1
        else
            echo -e "${green}DNS解析提供商：${provider}${plain}"
        fi
        if [[ -z "${dnsenvs}" ]]; then
            echo -e "${red}错误：DNS 模式下未输入环境变量 (-v)，请重新运行${plain}"
            exit 1
        else
            echo -e "${green}已配置的环境变量：${plain}"
            for var in ${dnsenvs}; do
                key=$(echo $var | cut -f1 -d=)
                val=$(echo $var | cut -f2 -d=)
                echo -e "  ${yellow}- ${key}=${val}${plain}"
            done
        fi
        echo -e "${green}ACME 注册邮箱：${email} (系统默认)${plain}"
    fi

    if [[ x"${certmode}" == x"file" ]]; then
        echo -e "${green}获取证书方式：File 模式 (手动指定)${plain}"
        echo -e "${green}证书路径：${certfile}${plain}"
        echo -e "${green}私钥路径：${keyfile}${plain}"
    fi

fi
if [[ ! "${nodeid}" =~ ^[0-9]+$ ]]; then   
    echo -e "${red}-i 选项参数值仅限数字格式，请输入正确的参数值并重新运行${plain}"
    exit 1
fi 

echo -e "${green}即将开始安装，取消请按Ctrl+C${plain}"
# 倒计时函数
countdown() {
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
        echo -ne "\r   \r"
    done
}

# 调用倒计时函数，传入10作为参数
countdown 10
install_dep
install_docker
install_XrayR
