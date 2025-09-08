#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[ "$(id -u)" != "0" ] && { echo -e "${red}Error: You must be root to run this script${plain}"; exit 1; }

check_cmd() { 
    command -v "$1" &>/dev/null;
}

build_caddy() { 
    cur_dir=$(pwd)
    GO_LATEST_VER=$(curl https://go.dev/VERSION?m=text | head -1)
    case "$(uname -m)" in
    'amd64' | 'x86_64')
        SYSTEM_ARCH="amd64"
    ;;
    *aarch64* | *armv8*)
        SYSTEM_ARCH="arm64"
    ;;
    *)
        SYSTEM_ARCH="$(uname -m)"
        echo -e "${red}${SYSTEM_ARCH}${plain}"
    ;;
    esac

    [ -e "/tmp/build_caddy_dir" ] && rm -rf /tmp/build_caddy_dir && mkdir -p /tmp/build_caddy_dir && cd $_
    wget "https://go.dev/dl/${GO_LATEST_VER}.linux-${SYSTEM_ARCH}.tar.gz" -O ${GO_LATEST_VER}.linux-${SYSTEM_ARCH}.tar.gz
    tar -xf ${GO_LATEST_VER}.linux-${SYSTEM_ARCH}.tar.gz
    mkdir xcaddy
    GOPATH=/tmp/build_caddy_dir/xcaddy ./go/bin/go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
    PATH=/tmp/build_caddy_dir/go/bin:$PATH GOPATH=/tmp/build_caddy_dir/xcaddy CADDY_VERSION=latest CGO_ENABLED=0 GOOS=linux GOARCH=${SYSTEM_ARCH} ./xcaddy/bin/xcaddy build \
        --with github.com/imgk/caddy-trojan \
        --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive
    cd ${cur_dir}
    mv -f /tmp/build_caddy_dir/caddy .
    rm -rf /tmp/build_caddy_dir
}

install_caddy() {
    if ! check_cmd tar; then
        echo -e "${green}tar: command not found, installing...${plain}"
        if check_cmd apt; then
            apt install -y tar
        elif check_cmd dnf; then
            dnf install -y tar
        elif check_cmd yum; then
            yum install -y tar
        else
            echo -e "${red}Error: Unable to install tar${plain}"; exit 1
        fi
    fi

    case "$(uname -m)" in
        'amd64' | 'x86_64')
            SYSTEM_ARCH="amd64"
        ;;
        *aarch64* | *armv8*)
            SYSTEM_ARCH="arm64"
        ;;
        *)
            SYSTEM_ARCH="$(uname -m)"
            echo -e "${red}${SYSTEM_ARCH}${plain}"
        ;;
    esac

    if [ "$build" = "1" ]; then
        build_caddy
    else
        if [ "${SYSTEM_ARCH}" = "amd64" ] || [ "${SYSTEM_ARCH}" = "arm64" ]; then
            caddy_url=https://raw.githubusercontent.com/terminodev/titanicsite7/main/caddy/caddy2.10.2_with_t_n_linux_${SYSTEM_ARCH}.tgz
        else
            echo -e "${red}Error: There is no package for your operating system, please use the [-b] option to compile the installation${plain}" ; exit 1
        fi
        curl -sL $caddy_url | tar --overwrite -zx caddy
    fi
    mv -f caddy /usr/local/bin/caddy && chmod +x /usr/local/bin/caddy
    if ! id caddy &>/dev/null; then groupadd --system caddy; useradd --system --gid caddy --create-home --home-dir /var/lib/caddy --shell "$(command -v nologin)" --comment "Caddy web server" caddy; fi
    mkdir -p /etc/caddy/trojan && chown -R caddy:caddy /etc/caddy && chmod 700 /etc/caddy

cat > /etc/systemd/system/caddy.service <<EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
Environment=XDG_CONFIG_HOME=/etc XDG_DATA_HOME=/etc
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
ReadWritePaths=/etc/caddy
AmbientCapabilities=CAP_NET_BIND_SERVICE
# Automatically restart caddy if it crashes except if the exit code was 1
RestartPreventExitStatus=1
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}

config_trojan() {
    [ -z "$domain" ] && domain=$(echo $RANDOM | md5sum | cut -c1-7).com
    if [ ${ssl} = "0" ]; then
        cat > /etc/caddy/Caddyfile <<EOF
{
    https_port ${port}
    order trojan before respond
    log default {
		level ERROR
	}
    auto_https disable_redirects
    default_sni ${domain}
    fallback_sni ${domain}
    local_certs
    skip_install_trust
    servers :${port} {
        listener_wrappers {
            trojan
        }
        protocols h2 h1
    }
    trojan {
        caddy
        no_proxy
        users ${password}
    }
}
:${port}, ${domain} {
    tls internal {
        protocols tls1.2 tls1.2
        ciphers TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
    }
    trojan {
        websocket
    }
    respond "503 Service Unavailable" 503 {
        close
    }
}
EOF
    elif [ ${ssl} = "1" ]; then
        [ -z "$domain" ] && domain=${nip_domain}
        disable_tlsalpn_challenge_value=""
        [ "$port" = "443" ] || disable_tlsalpn_challenge_value="disable_tlsalpn_challenge"
        rm -rf /etc/caddy/certificates
        cat > /etc/caddy/Caddyfile <<EOF
{
    https_port ${port}
    order trojan before respond
    log default {
		level ERROR
	}
    auto_https disable_redirects
    email ${address_ip}@sslip.io
    default_sni ${domain}
    cert_issuer acme {
		${disable_tlsalpn_challenge_value}
	}
    servers :${port} {
        listener_wrappers {
            trojan
        }
        protocols h2 h1
    }
    trojan {
        caddy
        no_proxy
        users ${password}
    }
}
:${port}, ${domain} {
    tls {
        protocols tls1.2 tls1.2
        ciphers TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
    }
    trojan {
        websocket
    }
    respond "503 Service Unavailable" 503 {
        close
    }
}
EOF
    fi
    systemctl enable caddy.service --now
    #curl -X POST -H "Content-Type: application/json" -d "{\"password\": \"$password\"}" http://127.0.0.1:2019/trojan/users/add
    echo "$password" >> /etc/caddy/trojan/passwd.txt && sort /etc/caddy/trojan/passwd.txt | uniq > /etc/caddy/trojan/passwd.tmp && mv -f /etc/caddy/trojan/passwd.tmp /etc/caddy/trojan/passwd.txt
    if [ "ssl" = "1" ]; then
        echo -e "${green}Obtaining and Installing an SSL Certificate...${plain}"
        count=0
        sslfail=0
        until [ -d /etc/caddy/certificates ]; do
            count=$((count + 1))
            sleep 3
            (( count > 30 )) && sslfail=1 && break
        done
        [ "$sslfail" = "1" ] && { echo -e "${red}Certificate application failed, please check your server firewall and network settings${plain}"; exit 1; }
    fi
}

config_naiveproxy() {
    if [ ${ssl} = "0" ]; then 
        echo -e "${green}Self-signed certificates are not supported. A trusted certificate will be automatically requested.${plain}"
    fi
    [ -z "$domain" ] && domain=${nip_domain}
    disable_tlsalpn_challenge_value=""
    [ "$port" = "443" ] || disable_tlsalpn_challenge_value="disable_tlsalpn_challenge"
    rm -rf /etc/caddy/certificates
    cat > /etc/caddy/Caddyfile <<EOF
{
    https_port ${port}
    order forward_proxy before respond
    admin off
    log default {
	    level ERROR
	}
    auto_https disable_redirects
    email ${address_ip}@sslip.io
    default_sni ${domain}
    cert_issuer acme {
		${disable_tlsalpn_challenge_value}
	}
}
:${port}, ${domain} {
    forward_proxy {
        basic_auth $username $password
        hide_ip
        hide_via
        probe_resistance
    }
    respond "503 Service Unavailable" 503 {
        close
    }
}
EOF
    systemctl enable caddy.service --now
    echo -e "${green}Obtaining and Installing an SSL Certificate...${plain}"
    count=0
    sslfail=0
    until [ -d /etc/caddy/certificates ]; do
        count=$((count + 1))
        sleep 3
        (( count > 30 )) && sslfail=1 && break
    done
    [ "$sslfail" = "1" ] && { echo -e "${red}Certificate application failed, please check your server firewall and network settings${plain}"; exit 1; }
}

uninstall() {
    systemctl stop caddy.service
    systemctl disable caddy.service
    rm -f /etc/systemd/system/caddy.service
    systemctl daemon-reload
    rm -f /usr/local/bin/caddy
    rm -rf /etc/caddy
    userdel -r caddy
    groupdel caddy
}

hello(){
    echo ""
    echo -e "${yellow}Trojan/Naiveproxy一键安装脚本${plain}"
    echo -e "${yellow}CentOS7+, Debian9+, Ubuntu18+${plain}"
    echo ""
}

help(){
    hello
    echo "示例：bash $0"
    echo ""
    echo "  -h               显示帮助信息"
    echo "  -n name         【选填】自定义用户名"
    echo "  -w password     【选填】自定义密码"
    echo "  -d example.com  【选填】自定义域名"
    echo "  -p 4433         【选填】自定义监听端口，默认443"
    echo "  -s              【选填】申请可信SSL证书"
    echo "  -6              【选填】ipv6模式"
    echo "  -b              【选填】编译安装"
    echo "  -t trojan       【选填】指定安装类型，可选：trojan,naiveproxy"
    echo "  -u              【选填】卸载"
    echo ""
}

ssl=0
ipv6=0
build=0
uninstall=0

# -n 自定义用户名
# -w 自定义密码
# -d 自定义域名
# -p 自定义端口
# -s 申请可信SSL
# -t 安装类型trojan/naiveproxy
# -6 ipv6域名
# -b 编译安装
# -u 卸载
# -h 帮助信息
while getopts ":n:w:d:p:st:6buh" optname
do
    case "$optname" in
      "n")
        username=$OPTARG
        ;;   
      "w")
        password=$OPTARG
        ;;
      "d")
        domain=$OPTARG
        ;;
      "p")
        port=$OPTARG
        ;;
      "s")
        ssl=1
        ;;
      "t")
        type=$OPTARG
        ;;
      "6")
        ipv6=1
        ;;
      "b")
        build=1
        ;;
      "u")
        uninstall=1
        ;;
      "h")
        help
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
      *)
        help
        exit 1
        ;;
    esac
done

if [ "${uninstall}" = "1" ]; then
    uninstall
    echo -e "${green}You have successfully uninstalled Caddy.${plain}"
    exit 0
fi

if [ "$ipv6" = "1" ]; then
    static_IPv6_mode="false"
    last_notable_hexes="ffff:ffff"
    ipv6_regex="(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))"

    if $static_IPv6_mode; then
        if { command -v "ip" &>/dev/null; }; then
            address_ip=$(ip -6 -o addr show scope global primary -deprecated | grep -oE "$ipv6_regex" | grep -oE ".*($last_notable_hexes)$")
        else
            address_ip=$(ifconfig | grep -oE "$ipv6_regex" | grep -oE ".*($last_notable_hexes)$")
        fi
    else
        address_ip=$(curl -s -6 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
        if [[ ! $ret == 0 ]]; then
            address_ip=$(curl -s -6 https://api64.ipify.org || curl -s -6 https://ipv6.icanhazip.com)
        else
            address_ip=$(echo $ip | sed -E "s/^ip=($ipv6_regex)$/\1/")
        fi
    fi

    if [[ ! $address_ip =~ ^$ipv6_regex$ ]]; then
        echo -e "${red}Failed to find a valid IPv6 address.${plain}"
        exit 1
    fi
    domain_resolve=$(curl -sH 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=${domain}&type=AAAA" | jq -r '.Answer[0].data')
else
    ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'
    address_ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
    if [[ ! $ret == 0 ]]; then
        address_ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
    else
        address_ip=$(echo $address_ip | sed -E "s/^ip=($ipv4_regex)$/\1/")
    fi

    if [[ ! $address_ip =~ ^$ipv4_regex$ ]]; then
        echo -e "${red}Failed to find a valid IP.${plain}"
        exit 2
    fi
    domain_resolve=$(curl -sH 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=${domain}&type=A" | jq -r '.Answer[0].data')
fi
nip_domain=${address_ip}.sslip.io

[ -z "$password" ] && password=$(echo $RANDOM | md5sum | cut -c1-16)
[ -n "$domain" ] && [ "$domain_resolve" != "$address_ip" ] && { echo -e "${red}Error: Could not resolve hostname"; exit 1; }
[ -z "$port" ] && port=443
[ -z "$type" ] && type=trojan
[ -n "$(ss -Hlnp sport = :${port})" ] && { echo -e "${red}Error: Port ${port} is already in use${plain}"; exit 1; }
[ -e "/usr/local/bin/caddy" ] && [ -e "/etc/caddy/Caddyfile" ] && echo -e "${yellow}Warning: Caddy Installed, Override Installation${plain}"

install_caddy
if [ "$type" = "trojan" ]; then
    config_trojan
    clear
    echo -e "${green}You have successfully installed Trojan.${plain}"
    if [ "$ssl" = "0" ]; then
        echo -e "${green}Address: ${address_ip} | Port: ${port}${plain}"
        echo -e "${green}Password: ${password} | Alpn: h2,http/1.1${plain}"
        echo -e "${green}Sni: ${domain}${plain}"
        echo -e "${yellow}Turn on Skip Certificate Validation${plain}"
    elif [ "$ssl" = "1" ]; then
        echo -e "${green}Address: ${domain} | Port: ${port}${plain}"
        echo -e "${green}Password: ${password} | Alpn: h2,http/1.1${plain}"
    fi
elif [ "$type" = "naiveproxy" ]; then
    [ -z "$username" ] && username=$(echo $RANDOM | md5sum | cut -c1-8)
    config_naiveproxy
    clear
    echo -e "${green}You have successfully installed Naiveproxy.${plain}"
    echo "{"
    echo "    \"listen\": \"socks://127.0.0.1:1080\","
    echo "    \"proxy\": \"https://${username}:${password}@${domain}:${port}\""
    echo "}"
fi
