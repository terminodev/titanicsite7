#!/usr/bin/env bash
#
# @Description: 适用于 CentOS / Debian / Ubuntu 的系统初始化优化脚本
# @Warning: 脚本仅供内部测试，请谨慎用于生产环境
#

# 启用严格模式
set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly YELLOWFLASH='\033[0;33;5m'
readonly BLACKFLASH='\033[0;47;30;5m'
readonly PLAIN='\033[0m'

# 图标定义
readonly INFO="ℹ"
readonly OK="✓"
readonly WARN="⚠"
readonly ERROR="✗"
readonly ARROW="➜"

# 全局变量
GITHUB_RAW_URL="raw.githubusercontent.com"
GITHUB_DOWNLOAD_URL="github.com"
NTPSERVER="time.cloudflare.com"
TIMEZONE="Asia/Hong_Kong"
release="unknown"
os_version="unknown"
bbr_run_status="unknown"

# 打印带颜色的消息
msg_info() {
    echo -e "${YELLOW}${ARROW} $1${PLAIN}"
}

msg_ok() {
    echo -e "${GREEN}${OK} $1${PLAIN}"
}

msg_warn() {
    echo -e "${YELLOW}${WARN} $1${PLAIN}"
}

msg_error() {
    echo -e "${RED}${ERROR} $1${PLAIN}"
}

# 检查命令执行结果
check_command() {
    local exit_code=$?
    local cmd_desc="$1"
    if [[ ${exit_code} -ne 0 ]]; then
        msg_error "${cmd_desc} 失败 (退出码: ${exit_code})"
        return 1
    fi
    return 0
}

# 显示使用帮助
show_usage() {
    cat << EOF
使用方法: bash $0 [选项]

选项:
    -c, --cdn     启用 CDN 镜像加速
    -h, --help    显示此帮助信息

示例:
    $0 -c -k      启用 CDN 并部署 SSH 密钥
    $0 --cdn      仅启用 CDN 镜像
EOF
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "需要 root 权限运行此脚本！"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            centos|rhel|almalinux|rocky|ol|fedora|scientific|openeuler|anolis|opencloudos)
                release="centos"
                ;;
            debian|raspbian|mx|uos|deepin)
                release="debian"
                ;;
            ubuntu|linuxmint|kylin)
                release="ubuntu"
                ;;
            *)
                if [[ "$ID_LIKE" == *"rhel"* ]] || [[ "$ID_LIKE" == *"centos"* ]] || [[ "$ID_LIKE" == *"fedora"* ]]; then
                    release="centos"
                elif [[ "$ID_LIKE" == *"debian"* ]] || [[ "$ID_LIKE" == *"ubuntu"* ]]; then
                    if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "linuxmint" ]] || [[ "$ID" == "kylin" ]]; then
                        release="ubuntu"
                    else
                        release="debian"
                    fi
                else
                    msg_error "不支持的系统: $ID"
                    exit 1
                fi
                ;;
        esac
        os_version=${VERSION_ID%%.*}
        if [[ -z "$os_version" ]]; then
            os_version=$(echo "$VERSION_ID" | grep -oE '^[0-9]+' | head -1)
        fi
    elif command -v lsb_release >/dev/null 2>&1; then
        local distro_id=$(lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]')
        case "$distro_id" in
            centos|rhel|almalinux|rocky|ol|fedora|scientific|openeuler|anolis|opencloudos)
                release="centos"
                ;;
            debian|raspbian|mx|uos|deepin)
                release="debian"
                ;;
            ubuntu|linuxmint|kylin)
                release="ubuntu"
                ;;
            *)
                msg_error "不支持的系统: $distro_id"
                exit 1
                ;;
        esac
        os_version=$(lsb_release -rs 2>/dev/null | grep -oE '^[0-9]+' | head -1)
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        case "$DISTRIB_ID" in
            CentOS|RedHatEnterpriseLinux|AlmaLinux|Rocky|Fedora|Scientific|openEuler|Anolis|OpenCloudOS)
                release="centos"
                ;;
            Debian|Raspbian|MX|UOS|Deepin)
                release="debian"
                ;;
            Ubuntu|LinuxMint|Kylin)
                release="ubuntu"
                ;;
            *)
                msg_error "不支持的系统: $DISTRIB_ID"
                exit 1
                ;;
        esac
        os_version=$(echo "$DISTRIB_RELEASE" | grep -oE '^[0-9]+' | head -1)
    elif [[ -f /etc/redhat-release ]]; then
        release="centos"
        os_version=$(grep -oE '[0-9]+' /etc/redhat-release | head -1)
    elif [[ -f /etc/issue ]]; then
        local issue_content=$(cat /etc/issue 2>/dev/null)
        if echo "$issue_content" | grep -Eqi "debian"; then
            release="debian"
        elif echo "$issue_content" | grep -Eqi "ubuntu"; then
            release="ubuntu"
        elif echo "$issue_content" | grep -Eqi "centos|red hat|redhat|fedora"; then
            release="centos"
        fi
        if [[ "$release" != "unknown" ]]; then
            os_version=$(echo "$issue_content" | grep -oE '[0-9]+' | head -1)
        fi
    elif [[ -f /proc/version ]]; then
        if grep -Eqi "debian|raspbian|deepin|uos" /proc/version 2>/dev/null; then
            release="debian"
        elif grep -Eqi "ubuntu|linux mint|kylin" /proc/version 2>/dev/null; then
            release="ubuntu"
        elif grep -Eqi "centos|red hat|redhat|rocky|alma|oracle|anolis|opencloudos|openeuler" /proc/version 2>/dev/null; then
            release="centos"
        fi
    fi

    if [[ "$release" == "unknown" ]]; then
        msg_error "无法识别系统类型"
        exit 1
    fi
    
    if [[ -z "$os_version" ]] || [[ "$os_version" == "unknown" ]]; then
        msg_error "无法识别系统版本"
        exit 1
    fi
}

# 检查系统版本兼容性
check_version() {
    if [[ -z "${os_version}" ]] || [[ "${os_version}" == "unknown" ]]; then
        msg_error "系统版本未知，无法检查兼容性"
        exit 1
    fi

    case "${release}" in
        centos)
            if [[ "${os_version}" -lt 7 ]]; then
                msg_error "不支持 ${ID:-CentOS/RHEL} ${os_version}，需要 7+"
                exit 1
            fi
            ;;
        ubuntu)
            if [[ "${os_version}" -lt 16 ]]; then
                msg_error "不支持 ${ID:-Ubuntu} ${os_version}，需要 16+"
                exit 1
            fi
            ;;
        debian)
            if [[ "${os_version}" -lt 9 ]]; then
                msg_error "不支持 ${ID:-Debian} ${os_version}，需要 9+"
                exit 1
            fi
            ;;
        *)
            msg_error "未知系统类型: ${release}"
            exit 1
            ;;
    esac
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--cdn)
                GITHUB_RAW_URL="ghfast.top/https://raw.githubusercontent.com"
                GITHUB_DOWNLOAD_URL="ghfast.top/https://github.com"
                NTPSERVER="ntp1.aliyun.com"
                TIMEZONE="Asia/Shanghai"
                msg_info "已启用 CDN 镜像加速"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                msg_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# 安装基础工具包
install_pkg() {
    msg_info "安装基础工具包..."
    if [[ "${release}" == "centos" ]]; then
        if [ ${os_version} -eq 7 ]; then
            yum clean all; check_command "yum clean"
            yum makecache -y; check_command "yum makecache"
            yum -y install epel-release; check_command "安装 epel-release"
            yum -y install vim wget curl zip unzip bash-completion lrzsz crontabs libsodium tar lsof nload screen python-devel python-pip python3-devel python3-pip socat nc mtr bind-utils yum-utils ntpdate chrony gcc gcc-c++ make iftop traceroute net-tools vnstat pciutils iperf3 iotop htop sysstat cmake openssl openssl-devel gnutls ca-certificates systemd sudo
            check_command "安装基础工具包"
            update-ca-trust force-enable; check_command "更新 CA 证书"
        else
            # fix https://almalinux.org/blog/2023-12-20-almalinux-8-key-update/
            if [[ "${os_version}" -eq 8 && "${ID}" == "almalinux" ]]; then
                if ! rpm -q "gpg-pubkey-ced7258b-6525146f" > /dev/null 2>&1; then
                   rpm --import "https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux"
                   check_command "导入 AlmaLinux GPG 密钥"
                fi
            fi
            dnf makecache -y
            dnf -y install epel-release; check_command "安装 epel-release"
            dnf -y install vim wget curl zip unzip bash-completion lrzsz crontabs libsodium tar lsof nload screen python3-devel python3-pip socat nc mtr bind-utils yum-utils chrony gcc gcc-c++ make iftop traceroute net-tools vnstat pciutils iperf3 iotop htop sysstat cmake openssl openssl-devel gnutls ca-certificates systemd sudo libmodulemd langpacks-zh_CN glibc-locale-source glibc-langpack-en
            check_command "安装基础工具包"
        fi
    elif [[ "${release}" == "ubuntu" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y; check_command "apt-get update"
        echo "iperf3 iperf3/start_daemon boolean false" | debconf-set-selections
        echo "libc6 glibc/restart-services string ssh exim4 cron" | debconf-set-selections
        echo "*	libraries/restart-without-asking	boolean	true" | debconf-set-selections
        apt-get install -y --no-install-recommends vim wget curl lrzsz tar lsof dnsutils nload iperf3 screen cron chrony openssl libsodium-dev libgnutls30 ca-certificates systemd python3-dev python3-pip locales
        check_command "安装基础工具包"
        update-ca-certificates; check_command "更新 CA 证书"
    elif [[ "${release}" == "debian" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y; check_command "apt-get update"
        echo "iperf3 iperf3/start_daemon boolean false" | debconf-set-selections
        echo "libc6 glibc/restart-services string ssh exim4 cron" | debconf-set-selections
        echo "*	libraries/restart-without-asking	boolean	true" | debconf-set-selections
        apt-get install -y --no-install-recommends vim wget curl lrzsz tar lsof dnsutils nload iperf3 screen cron chrony openssl libsodium-dev libgnutls30 ca-certificates systemd python3-dev python3-pip locales
        check_command "安装基础工具包"
        update-ca-certificates; check_command "更新 CA 证书"
    fi
    if [[ ! -e /usr/local/bin/tcping ]]; then
        local tcping_tmpdir=$(mktemp -d)
        if wget --timeout=30 --tries=3 -O "${tcping_tmpdir}/tcping-linux-amd64-static.tar.gz" "https://${GITHUB_DOWNLOAD_URL}/pouriyajamshidi/tcping/releases/latest/download/tcping-linux-amd64-static.tar.gz"; then
            tar xf "${tcping_tmpdir}/tcping-linux-amd64-static.tar.gz" -C /usr/local/bin/; check_command "解压 tcping"
            chmod +x /usr/local/bin/tcping
        else
            msg_warn "tcping 下载失败，跳过安装"
        fi
        rm -rf "${tcping_tmpdir}"
    fi
    msg_ok "基础工具包安装完成"
}

#配置 SSH 安全策略
set_ssh() {
    msg_info "配置 SSH 安全策略..."
    local sshd_config="/etc/ssh/sshd_config"
    if [[ ! -f "${sshd_config}" ]]; then
        msg_error "SSH 配置文件不存在: ${sshd_config}"
        return 1
    fi
    if grep -q "^UseDNS" "${sshd_config}"; then
        sed -i '/^UseDNS/s/yes/no/' "${sshd_config}"
    else
       sed -i '$a UseDNS no' "${sshd_config}"
    fi
    if grep -q "^GSSAPIAuthentication" "${sshd_config}"; then
        sed -i '/^GSSAPIAuthentication/s/yes/no/' "${sshd_config}"
    else
       sed -i '$a GSSAPIAuthentication no' "${sshd_config}"
    fi
    if grep -q "^PermitEmptyPasswords" "${sshd_config}"; then
        sed -i '/^PermitEmptyPasswords/s/yes/no/' "${sshd_config}"
    else
       sed -i '$a PermitEmptyPasswords no' "${sshd_config}"
    fi
    if grep -q "^IgnoreRhosts" "${sshd_config}"; then
        sed -i 's/^IgnoreRhosts.*/IgnoreRhosts yes/' "${sshd_config}"
    else
       sed -i '$a IgnoreRhosts yes' "${sshd_config}"
    fi
    if grep -q "^HostbasedAuthentication" "${sshd_config}"; then
        sed -i '/^HostbasedAuthentication/s/yes/no/' "${sshd_config}"
    else
       sed -i '$a HostbasedAuthentication no' "${sshd_config}"
    fi
    if grep -q "^UsePAM" "${sshd_config}"; then
        sed -i '/^UsePAM/s/no/yes/' "${sshd_config}"
    else
       sed -i '$a UsePAM yes' "${sshd_config}"
    fi
    if grep -q '^MaxAuthTries' "${sshd_config}"; then
        sed -i '/^MaxAuthTries[[:space:]]/cMaxAuthTries 3' "${sshd_config}"
    else
        sed -i '$a MaxAuthTries 3' "${sshd_config}"
    fi
    if grep -q '^ClientAliveInterval' "${sshd_config}"; then
        sed -i '/^ClientAliveInterval[[:space:]]/cClientAliveInterval 300' "${sshd_config}"
    else
        sed -i '$a ClientAliveInterval 300' "${sshd_config}"
    fi
    if grep -q '^LoginGraceTime' "${sshd_config}"; then
        sed -i '/^LoginGraceTime[[:space:]]/cLoginGraceTime 30' "${sshd_config}"
    else
        sed -i '$a LoginGraceTime 30' "${sshd_config}"
    fi
    if grep -q '^MaxStartups' "${sshd_config}"; then
        sed -i '/^MaxStartups[[:space:]]/cMaxStartups 10:30:60' "${sshd_config}"
    else
        sed -i '$a MaxStartups 10:30:60' "${sshd_config}"
    fi
    if sshd -t -f "${sshd_config}" 2>/dev/null; then
        msg_ok "SSH 配置语法检查通过"
        if command -v systemctl &>/dev/null; then
            if systemctl is-enabled sshd >/dev/null 2>&1 || systemctl status sshd >/dev/null 2>&1; then
                systemctl reload sshd 2>/dev/null || systemctl restart sshd
                check_command "重载 SSH 服务"
            elif systemctl is-enabled ssh >/dev/null 2>&1 || systemctl status ssh >/dev/null 2>&1; then
                systemctl reload ssh 2>/dev/null || systemctl restart ssh
                check_command "重载 SSH 服务"
            else
                msg_warn "请手动重启 SSH 服务以加载配置"
            fi
        elif service ssh status &>/dev/null; then
            service ssh reload 2>/dev/null || service ssh restart
            check_command "重载 SSH 服务"
        elif service sshd status &>/dev/null; then
            service sshd reload 2>/dev/null || service sshd restart
            check_command "重载 SSH 服务"
        else
            msg_warn "请手动重启 SSH 服务以加载配置"
        fi
    else
        msg_error "SSH 配置语法错误，请手动检查"
        return 1
    fi
    msg_ok "SSH 安全策略配置完成"
}

# 禁用 SELinux
set_selinux() {
    if [ -f /etc/selinux/config ] || command -v getenforce &>/dev/null; then
        msg_info "禁用 SELinux..."
        if [ -f /etc/selinux/config ]; then
            if grep -q "^SELINUX=" /etc/selinux/config 2>/dev/null; then
                sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
            else
                echo "SELINUX=disabled" >> /etc/selinux/config
            fi
        fi
        if command -v getenforce &>/dev/null && [[ "$(getenforce 2>/dev/null)" != "Disabled" ]]; then
            setenforce 0 2>/dev/null
            check_command "临时禁用 SELinux"
        fi
        msg_ok "SELinux 已禁用"
    fi

}

# 配置系统时区
set_timezone() {
    msg_info "配置系统时区..."

    if command -v timedatectl &>/dev/null; then
        if ! timedatectl | grep -q "Time zone.*${TIMEZONE}"; then
            timedatectl set-timezone "${TIMEZONE}"
            check_command "设置时区"
        fi
    else
        ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
        check_command "设置时区"
    fi
    if [[ "${release}" == "centos" ]]; then
        if command -v chronyd &>/dev/null; then
            if ! grep -Eq "^[#[:space:]]*(server|pool)[[:space:]]+${NTPSERVER}([[:space:]]|$)" /etc/chrony.conf 2>/dev/null; then
                sed -i 's/^\s*\(server\|pool\)\s\+/#&/g' /etc/chrony.conf 2>/dev/null || true
                echo "server ${NTPSERVER} iburst" >> /etc/chrony.conf
            fi
            systemctl enable chronyd.service >/dev/null 2>&1 || true
            systemctl restart chronyd.service
            check_command "配置 chronyd"
            chronyc -a makestep 2>/dev/null || chronyd -q "server ${NTPSERVER} iburst" 2>/dev/null || true
        else
            sed -i 's/SYNC_HWCLOCK=no/SYNC_HWCLOCK=yes/' /etc/sysconfig/ntpdate 2>/dev/null || true
            ntpdate "${NTPSERVER}" && hwclock -w
            check_command "NTP 时间同步"
        fi
    elif [[ "${release}" == "ubuntu" ]] || [[ "${release}" == "debian" ]]; then
        if command -v chronyd &>/dev/null; then
            if ! grep -Eq "^[#[:space:]]*(server|pool)[[:space:]]+${NTPSERVER}([[:space:]]|$)" /etc/chrony/chrony.conf 2>/dev/null; then
                sed -i 's/^\s*\(server\|pool\)\s\+/#&/g' /etc/chrony/chrony.conf 2>/dev/null || true
                echo "server ${NTPSERVER} iburst" >> /etc/chrony/chrony.conf
            fi
            systemctl enable chrony >/dev/null 2>&1 || systemctl enable chronyd >/dev/null 2>&1 || true
            systemctl restart chrony >/dev/null 2>&1 || systemctl restart chronyd
            check_command "配置 chrony"
            chronyc -a makestep 2>/dev/null || chronyd -q "server ${NTPSERVER} iburst" 2>/dev/null || true
        else
            if [ -f /etc/systemd/timesyncd.conf ]; then
                if grep -q "^#*NTP=" /etc/systemd/timesyncd.conf 2>/dev/null; then
                    sed -i "s/^#*NTP=.*/NTP=${NTPSERVER}/" /etc/systemd/timesyncd.conf
                else
                    echo "NTP=${NTPSERVER}" >> /etc/systemd/timesyncd.conf
                fi
                systemctl enable systemd-timesyncd >/dev/null 2>&1 || true
                systemctl restart systemd-timesyncd
                check_command "配置 systemd-timesyncd"
            fi
            timedatectl set-ntp true 2>/dev/null || true
        fi
    fi
    msg_ok "系统时区配置完成"
}

# 启用历史命令时间戳
set_history() {
    msg_info "启用历史命令时间戳..."
    if [[ ! -f /etc/profile ]]; then
        msg_error "/etc/profile 不存在"
        return 1
    fi
    if [[ ! -w /etc/profile ]]; then
        msg_error "/etc/profile 无写入权限"
        return 1
    fi
    if ! grep -qE '^[[:space:]]*export[[:space:]]+HISTTIMEFORMAT=' /etc/profile; then
        echo 'export HISTTIMEFORMAT="%F %T $USER "' >> /etc/profile
        check_command "写入 HISTTIMEFORMAT 配置"
    fi
    msg_ok "历史命令时间戳已启用"
}

# 禁用 Ctrl+Alt+Del 重启
set_ctrlaltdel() {
    msg_info "禁用 Ctrl+Alt+Del 重启..."
    if command -v systemctl >/dev/null 2>&1; then
        systemctl mask ctrl-alt-del.target >/dev/null 2>&1
        check_command "禁用 ctrl-alt-del.target 服务"
    else
        msg_error "systemctl 不存在，无法禁用 Ctrl+Alt+Del 重启"
        return 1
    fi
    msg_ok "Ctrl+Alt+Del 重启已禁用"
}

# 配置系统字符集
set_locale() {
    msg_info "配置系统字符集..."
    if [[ "${release}" == "centos" ]]; then
        localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8 >/dev/null 2>&1 || true
        if command -v localectl >/dev/null 2>&1; then
            localectl set-locale LANG=zh_CN.UTF-8 >/dev/null 2>&1 || true
        fi
        if grep -q "^LANG=" /etc/locale.conf 2>/dev/null; then
            sed -i 's/^LANG=.*/LANG=zh_CN.UTF-8/' /etc/locale.conf
        else
            echo "LANG=zh_CN.UTF-8" > /etc/locale.conf
        fi
    else
        if [[ -f /etc/locale.gen ]]; then
            sed -i 's/^[#[:space:]]*zh_CN\.UTF-8[[:space:]]\+UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
            grep -q '^zh_CN.UTF-8[[:space:]]\+UTF-8' /etc/locale.gen || echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
        fi
        command -v locale-gen >/dev/null 2>&1 && locale-gen zh_CN.UTF-8 >/dev/null 2>&1 || true
        command -v update-locale >/dev/null 2>&1 && update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 >/dev/null 2>&1 || true
        if [[ -f /etc/default/locale ]]; then
            grep -q '^LANG=' /etc/default/locale 2>/dev/null && \
                sed -i 's/^LANG=.*/LANG=zh_CN.UTF-8/' /etc/default/locale || \
                echo 'LANG=zh_CN.UTF-8' >> /etc/default/locale
            grep -q '^LC_ALL=' /etc/default/locale 2>/dev/null && \
                sed -i 's/^LC_ALL=.*/LC_ALL=zh_CN.UTF-8/' /etc/default/locale || \
                echo 'LC_ALL=zh_CN.UTF-8' >> /etc/default/locale
        fi
    fi
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8
    msg_ok "系统字符集配置完成"
}

# 配置定时内存回收
set_drop_cache() {
    msg_info "配置定时内存回收..."
    local cron_tmp=$(mktemp)
    crontab -l 2>/dev/null | grep -v "/proc/sys/vm/drop_caches" > "$cron_tmp" || true
    echo '0 6 * * * sync && echo 3 > /proc/sys/vm/drop_caches' >> "$cron_tmp"
    crontab "$cron_tmp"
    check_command "配置 crontab"
    rm -f "$cron_tmp"
    msg_ok "定时内存回收已配置"
}

# 配置系统资源限制
set_limit() {
    msg_info "配置系统资源限制..."
    local limits=/etc/security/limits.conf
    grep -Fxq "root soft nofile 512000"  "$limits" || echo "root soft nofile 512000"  >> "$limits"
    grep -Fxq "root hard nofile 512000"  "$limits" || echo "root hard nofile 512000"  >> "$limits"
    grep -Fxq "* soft nofile 512000"     "$limits" || echo "* soft nofile 512000"     >> "$limits"
    grep -Fxq "* hard nofile 512000"     "$limits" || echo "* hard nofile 512000"     >> "$limits"
    grep -Fxq "* soft nproc 512000"      "$limits" || echo "* soft nproc 512000"      >> "$limits"
    grep -Fxq "* hard nproc 512000"      "$limits" || echo "* hard nproc 512000"      >> "$limits"

    if [[ "${release}" == "centos" && "${os_version}" -eq 7 ]]; then
        if [[ -f /etc/security/limits.d/20-nproc.conf ]]; then
            sed -i 's/^[[:space:]]*\*.*soft.*nproc.*$/\* soft nproc 65535/' /etc/security/limits.d/20-nproc.conf
            check_command "修改 20-nproc.conf"
        fi
    fi

    ulimit -SHn 512000
    check_command "应用 ulimit 限制"
    sed -i '/^[[:space:]]*ulimit -SHn[[:space:]]\+/d' /etc/profile 2>/dev/null || true
    echo -e "\nulimit -SHn 512000" >> /etc/profile
    check_command "配置 /etc/profile"

    if [[ -e /etc/pam.d/common-session ]]; then
        if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
            echo "session required pam_limits.so" >> /etc/pam.d/common-session
        fi
    fi
    if [[ -e /etc/pam.d/common-session-noninteractive ]]; then
        if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive; then
            echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
        fi
    fi
    sed -i '/^DefaultLimitCORE=/d' /etc/systemd/system.conf 2>/dev/null || true
    echo "DefaultLimitCORE=infinity" >> /etc/systemd/system.conf
    sed -i '/^DefaultLimitNOFILE=/d' /etc/systemd/system.conf 2>/dev/null || true
    echo "DefaultLimitNOFILE=512000" >> /etc/systemd/system.conf
    sed -i '/^DefaultLimitNPROC=/d' /etc/systemd/system.conf 2>/dev/null || true
    echo "DefaultLimitNPROC=65535" >> /etc/systemd/system.conf
    systemctl daemon-reload 2>/dev/null || true
    msg_ok "系统资源限制配置完成"
}

# 配置网络与内核参数
set_sysctl() {
    msg_info "配置网络与内核参数..."
    sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.conf
    sed -i '/net.ipv4.icmp_ignore_bogus_error_responses/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.all.rp_filter/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.default.rp_filter/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.all.accept_source_route/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.default.accept_source_route/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.all.accept_source_route/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.default.accept_source_route/d' /etc/sysctl.conf
    sed -i '/kernel.sysrq/d' /etc/sysctl.conf
    sed -i '/kernel.core_uses_pid/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
    sed -i '/kernel.msgmnb/d' /etc/sysctl.conf
    sed -i '/kernel.msgmax/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_sack/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_window_scaling/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
    sed -i '/net.core.wmem_default/d' /etc/sysctl.conf
    sed -i '/net.core.rmem_default/d' /etc/sysctl.conf
    sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
    sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
    sed -i '/net.ipv4.udp_rmem_min/d' /etc/sysctl.conf
    sed -i '/net.ipv4.udp_wmem_min/d' /etc/sysctl.conf
    sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_tw_recycle/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
    sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
    sed -i '/net.ipv4.ip_local_reserved_ports/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.all.accept_redirects/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.default.accept_redirects/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.all.accept_redirects/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.default.accept_redirects/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.all.secure_redirects/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.default.secure_redirects/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_moderate_rcvbuf/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_retries2/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_slow_start_after_idle/d' /etc/sysctl.conf
    sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf
    sed -i '/net.ipv6.bindv6only/d' /etc/sysctl.conf
    sed -i '/fs.file-max/d' /etc/sysctl.conf
    sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
    sed -i '/vm.swappiness/d' /etc/sysctl.conf
    sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_keepalive_time/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_keepalive_probes/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_keepalive_intvl/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_fastopen/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    
    cat << EOF >> /etc/sysctl.conf
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
kernel.sysrq = 0
kernel.core_uses_pid = 1
net.ipv4.tcp_syncookies = 1
kernel.msgmnb = 65535
kernel.msgmax = 65535
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.wmem_default = 65536
net.core.rmem_default = 65536
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.udp_rmem_min=4096
net.ipv4.udp_wmem_min=4096
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.ip_local_port_range = 16384 65535
#net.ipv4.ip_local_reserved_ports = 10001-10005
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.route.gc_timeout = 100
net.ipv6.bindv6only = 0
fs.file-max = 512000
fs.inotify.max_user_instances = 8192
vm.swappiness = 1
net.core.somaxconn = 32768
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
#net.ipv4.tcp_notsent_lowat = 16384
EOF

    msg_info "应用 sysctl 配置..."
    /sbin/sysctl -p /etc/sysctl.conf 2>/dev/null | awk -F' = ' -v g="$GREEN" -v o="$OK" -v p="$PLAIN" '{printf "  %s%s%s %-35s = %s\n", g, o, p, $1, $2}'
    msg_ok "网络与内核参数配置完成"
}

# 检查 BBR 状态
check_bbr() {
    local kernel_version=$(uname -r | cut -d'-' -f1)
    local major_version=$(echo "${kernel_version}" | cut -d'.' -f1)
    local minor_version=$(echo "${kernel_version}" | cut -d'.' -f2)
    local patch_version=$(echo "${kernel_version}" | cut -d'.' -f3)
    local tcp_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    if [[ "${major_version}" -gt 4 ]] || [[ "${major_version}" == "4" && "${minor_version}" -ge 9 ]]; then
        if sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw "bbr"; then
            kernel_status="BBR"
        elif command -v lsmod >/dev/null 2>&1 && lsmod 2>/dev/null | grep -qw "tcp_bbr"; then
            kernel_status="BBR"
        elif grep -qw "tcp_bbr" /proc/modules 2>/dev/null; then
            kernel_status="BBR"
        else
            kernel_status="noinstall"
        fi
    else
        kernel_status="noinstall"
    fi
    if [[ "${kernel_status}" == "BBR" ]]; then
        if [[ "${tcp_cc}" == "bbr" ]]; then
            if [[ "${qdisc}" == "fq" ]]; then
                bbr_run_status="${GREEN}已启用${PLAIN}"
            else
                bbr_run_status="${YELLOW}已启用 BBR，但建议将 net.core.default_qdisc 设为 fq${PLAIN}"
            fi
        else
            bbr_run_status="${YELLOW}已支持 BBR，但未启用${PLAIN}"
        fi
    else
        bbr_run_status="${YELLOW}内核/模块未支持 BBR（当前: ${kernel_version}，需要 4.9+ 且支持 tcp_bbr）${PLAIN}"
    fi
}

# 配置熵池增强服务
set_entropy() {
    local entropy_value
    entropy_value=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null) || entropy_value=0
    if [[ "${entropy_value}" -lt 1000 && "${entropy_value}" -ne 256 ]]; then
        msg_info "配置熵池增强服务..."
        if grep -q "rdrand" /proc/cpuinfo 2>/dev/null; then
            if [[ "${release}" == "centos" ]]; then
                yum -y install rng-tools
                systemctl enable --now rngd 2>/dev/null
            elif [[ "${release}" == "ubuntu" ]] || [[ "${release}" == "debian" ]]; then
                apt-get install -y rng-tools
                systemctl enable --now rngd 2>/dev/null
            fi
            check_command "启动 rngd 服务"
        else
            if [[ "${release}" == "centos" ]]; then
                yum -y install haveged
                systemctl enable --now haveged 2>/dev/null
            elif [[ "${release}" == "ubuntu" ]] || [[ "${release}" == "debian" ]]; then
                apt-get install -y haveged
                systemctl enable --now haveged 2>/dev/null
            fi
            check_command "启动 haveged 服务"
        fi
        msg_ok "熵池增强服务已启用"
    fi
}

# 配置 Vim 编辑器
set_vim() {
    msg_info "配置 Vim 编辑器..."

    local sys_vimrc=""
    local vimrc_target=""
    if [[ "${release}" == "centos" ]]; then
        sys_vimrc="/etc/vimrc"
    else
        [[ -f "/etc/vim/vimrc" ]] && sys_vimrc="/etc/vim/vimrc"
        [[ -z "${sys_vimrc}" && -f "/etc/vimrc" ]] && sys_vimrc="/etc/vimrc"
    fi
    local user_vimrc="${HOME}/.vimrc"
    if [[ -n "${sys_vimrc}" ]]; then
        vimrc_target="${sys_vimrc}"
        [[ -e "${vimrc_target}" ]] || touch "${vimrc_target}"
    else
        vimrc_target="${user_vimrc}"
        [[ -e "${vimrc_target}" ]] || touch "${vimrc_target}"
    fi
    
    for opt in \
        'set cursorline' \
        'set autoindent' \
        'set showmode' \
        'set ruler' \
        'syntax on' \
        'filetype on' \
        'set smartindent' \
        'set tabstop=4' \
        'set shiftwidth=4' \
        'set hlsearch' \
        'set incsearch' \
        'set ignorecase'
    do
        grep -Fxq "${opt}" "${vimrc_target}" || echo "${opt}" >> "${vimrc_target}"
    done

    [[ -e "$user_vimrc" ]] || touch "$user_vimrc"
    for enc in \
        'set fileencodings=utf-8,gbk,utf-16le,cp1252,iso-8859-15,ucs-bom' \
        'set fileencoding=utf-8' \
        'set encoding=utf-8'
    do
        grep -Fxq "$enc" "$user_vimrc" || echo "$enc" >> "$user_vimrc"
    done
    msg_ok "Vim 编辑器配置完成"
}

# 配置 Journald 日志服务
set_journal() {
    msg_info "配置 Journald 日志服务..."
    local journal_conf="/etc/systemd/journald.conf"
    [[ -d /var/log/journal ]] || mkdir -p /var/log/journal
    if grep -Eq '^[#[:space:]]*Storage=' "$journal_conf"; then
        sed -i 's|^[#[:space:]]*Storage=.*|Storage=persistent|' "$journal_conf"
    else
        sed -i '$a Storage=persistent' "$journal_conf"
    fi
    if grep -Eq '^[#[:space:]]*Compress=' "$journal_conf"; then
        sed -i 's|^[#[:space:]]*Compress=.*|Compress=yes|' "$journal_conf"
    else
        sed -i '$a Compress=yes' "$journal_conf"
    fi
    if grep -Eq '^[#[:space:]]*SystemMaxUse=' "$journal_conf"; then
        sed -i 's|^[#[:space:]]*SystemMaxUse=.*|SystemMaxUse=384M|' "$journal_conf"
    else
        sed -i '$a SystemMaxUse=384M' "$journal_conf"
    fi
    if grep -Eq '^[#[:space:]]*SystemMaxFileSize=' "$journal_conf"; then
        sed -i 's|^[#[:space:]]*SystemMaxFileSize=.*|SystemMaxFileSize=128M|' "$journal_conf"
    else
        sed -i '$a SystemMaxFileSize=128M' "$journal_conf"
    fi
    if grep -Eq '^[#[:space:]]*RuntimeMaxUse=' "$journal_conf"; then
        sed -i 's|^[#[:space:]]*RuntimeMaxUse=.*|RuntimeMaxUse=128M|' "$journal_conf"
    else
        sed -i '$a RuntimeMaxUse=128M' "$journal_conf"
    fi
    if grep -Eq '^[#[:space:]]*ForwardToSyslog=' "$journal_conf"; then
        sed -i 's|^[#[:space:]]*ForwardToSyslog=.*|ForwardToSyslog=no|' "$journal_conf"
    else
        sed -i '$a ForwardToSyslog=no' "$journal_conf"
    fi
    if grep -Eq '^[#[:space:]]*ForwardToWall=' "$journal_conf"; then
        sed -i 's|^[#[:space:]]*ForwardToWall=.*|ForwardToWall=no|' "$journal_conf"
    else
        sed -i '$a ForwardToWall=no' "$journal_conf"
    fi
    systemctl daemon-reload 2>/dev/null
    systemctl restart systemd-journald 2>/dev/null
    journalctl --flush >/dev/null 2>&1
    check_command "重启 systemd-journald"
    msg_ok "Journald 日志服务配置完成"
}

# 配置 Readline 快捷键
set_readline() {
    msg_info "配置 Readline 快捷键..."
    local inputrc="/etc/inputrc"
    [ -e "${inputrc}" ] || touch "${inputrc}"
    if grep -q '^"\\e.*": history-search-backward' "${inputrc}"; then
        sed -i 's/^"\\e.*": history-search-backward/"\\e\[A": history-search-backward/g' "${inputrc}"
    else
        sed -i '$a # map "up arrow" to search the history based on lead characters typed' "${inputrc}"
        sed -i '$a "\\e\[A": history-search-backward' "${inputrc}"
    fi
    
    if grep -q '^"\\e.*": history-search-forward' "${inputrc}"; then
        sed -i 's/^"\\e.*": history-search-forward/"\\e\[B": history-search-forward/g' "${inputrc}"
    else
        sed -i '$a # map "down arrow" to search history based on lead characters typed' "${inputrc}"
        sed -i '$a "\\e\[B": history-search-forward' "${inputrc}"
    fi
    
    if grep -q '"\\e.*": kill-word' "${inputrc}"; then
        sed -i 's/"\\e.*": kill-word/"\\e[3;3~": kill-word/g' "${inputrc}"
    else
        sed -i '$a # map ALT+Delete to remove word forward' "${inputrc}"
        sed -i '$a "\\e[3;3~": kill-word' "${inputrc}"
    fi
    msg_ok "Readline 快捷键配置完成"
}

# 配置虚拟化驱动（CentOS 外置 virtio-blk 和 xen-blkfront），安装或升级kernel时可能会出现的驱动问题，仅修复不重建
set_driver() {
    if [[ "${release}" == "centos" ]]; then
        msg_info "检查虚拟化驱动..."
        local dracut_conf="/etc/dracut.conf.d/virt-drivers.conf"
        local drivers='add_drivers+=" xen-blkfront virtio_blk "'
        local initramfs="/boot/initramfs-$(uname -r).img"
        if [[ -f "${initramfs}" ]] && command -v lsinitrd >/dev/null 2>&1 && lsinitrd "${initramfs}" 2>/dev/null | grep -qE 'virtio_blk|xen-blkfront'; then
            msg_ok "虚拟化驱动已包含在 initramfs 中，无需配置"
            return 0
        fi
        msg_info "配置虚拟化驱动..."
        mkdir -p /etc/dracut.conf.d 2>/dev/null || true
        if [[ ! -f "${dracut_conf}" ]] || ! grep -qs 'add_drivers.*xen-blkfront' "${dracut_conf}" 2>/dev/null || ! grep -qs 'add_drivers.*virtio_blk' "${dracut_conf}" 2>/dev/null; then
            echo "${drivers}" > "${dracut_conf}"
            check_command "配置虚拟化驱动"
        else
            msg_info "虚拟化驱动配置已存在"
        fi
        msg_ok "虚拟化驱动配置完成"
    fi
}

# 配置登录欢迎信息
set_motd() {
    msg_info "配置登录欢迎信息..."
    if [[ ! -e /etc/profile.d/motd.sh ]]; then
        wget --timeout=30 --tries=3 -O /etc/profile.d/motd.sh "https://${GITHUB_RAW_URL}/terminodev/titanicsite7/main/motd.sh"
        chmod a+x /etc/profile.d/motd.sh
    fi
    msg_ok "登录欢迎信息配置完成"
}

# 脚本自删除
remove_self() {
    local script_path="${BASH_SOURCE[0]:-$0}"
    if [[ -f "$script_path" ]]; then
        rm -f "$script_path"
    fi
}

# 显示执行摘要
show_summary() {
    echo -e "${INFO} BBR 状态：${bbr_run_status}  |  完成时间：$(date '+%F %T')\n"
}

# 退出清理（trap 调用）
trap_exit() {
    local exit_code=$?
    rm -f /tmp/id_rsa_4096.pub 2>/dev/null || true
    if [[ ${exit_code} -ne 0 ]]; then
        msg_error "脚本异常退出（退出码: ${exit_code}）"
    fi
    exit ${exit_code}
}

# 主函数
main() {
    check_root
    parse_args "$@"
    detect_os
    check_version

    # 开始边框
    echo -e "\n${GREEN}╔════════════════════════════════════════════════╗${PLAIN}"
    echo -e "${GREEN}║${PLAIN}     系统初始化优化脚本 - 开始执行              ${GREEN}║${PLAIN}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${PLAIN}\n"

    install_pkg
    set_ssh
    set_selinux
    set_timezone
    set_history
    set_ctrlaltdel
    set_locale
    set_drop_cache
    set_limit
    set_sysctl
    check_bbr
    set_entropy
    set_vim
    set_journal
    set_readline
    set_driver
    set_motd
    
    # 结束边框
    echo -e "\n${GREEN}╔════════════════════════════════════════════════╗${PLAIN}"
    echo -e "${GREEN}║${PLAIN}     系统初始化优化脚本 - 执行完毕              ${GREEN}║${PLAIN}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${PLAIN}\n"

    show_summary
    # remove_self
}

# 设置清理陷阱
trap trap_exit EXIT INT TERM

# 执行主函数
main "$@"
