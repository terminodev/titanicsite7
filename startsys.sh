#!/usr/bin/env bash
###
 # @Description: 适用于Centos Debian Ubuntu的新系统初始优化脚本,内部测试使用,仅供参考
 # @From: https://github.com/terminodev
###

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
yellowflash='\033[0;33;5m'
blackflash='\033[0;47;30;5m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

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
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
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
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 9 ]]; then
        echo -e "${red}请使用 Debian 9 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

GITHUB_URL="github.com"
GITHUB_RAW_URL="raw.githubusercontent.com"
GITHUB_DOWNLOAD_URL="github.com"
NTPSERVER="time.cloudflare.com"
TIMEZONE="Asia/Singapore"
if [ -n "$*" ]; then
    if echo "$*" | grep -qwi "cn"; then
        GITHUB_URL="gitclone.com"
        GITHUB_RAW_URL="ghfast.top/https://raw.githubusercontent.com"
        GITHUB_DOWNLOAD_URL="ghfast.top/https://github.com"
        NTPSERVER="ntp1.aliyun.com"
        TIMEZONE="Asia/Shanghai"
    fi
fi
#安装常用软件包
install(){
        echo -e "${yellow}安装常用软件包${plain}"
        if [[ x"${release}" == x"centos" ]]; then
            if [ ${os_version} -eq 7 ]; then
                yum clean all
                yum makecache
                yum -y install epel-release
                yum -y install vim wget curl zip unzip bash-completion git tree mlocate lrzsz crontabs libsodium tar lsof nload screen nano python-devel python-pip python3-devel python3-pip socat nc mtr bind-utils yum-utils ntpdate gcc gcc-c++ make iftop traceroute net-tools vnstat pciutils iperf3 iotop htop sysstat bc cmake openssl openssl-devel gnutls ca-certificates systemd sudo
                update-ca-trust force-enable
            else
                #fix https://almalinux.org/blog/2023-12-20-almalinux-8-key-update/
                if [ ${os_version} -eq 8 ]; then
                    (
                       . "/etc/os-release"
                       if [ "$ID" == "almalinux" ]; then
                           if ! rpm -q "gpg-pubkey-ced7258b-6525146f" > /dev/null 2>&1; then
                               rpm --import "https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux"
                           fi
                       fi
                    )
                fi
                dnf -y install epel-release
                dnf -y install vim wget curl zip unzip bash-completion git tree mlocate lrzsz crontabs libsodium tar lsof nload screen nano python3-devel python3-pip socat nc mtr bind-utils yum-utils gcc gcc-c++ make iftop traceroute net-tools vnstat pciutils iperf3 iotop htop sysstat bc cmake openssl openssl-devel gnutls ca-certificates systemd sudo libmodulemd langpacks-zh_CN glibc-locale-source glibc-langpack-en
            fi
        elif [[ x"${release}" == x"ubuntu" ]]; then
            apt update -y
            echo "iperf3 iperf3/start_daemon boolean false" | debconf-set-selections
            echo "libc6 glibc/restart-services string ssh exim4 cron" | debconf-set-selections
            echo "*	libraries/restart-without-asking	boolean	true" | debconf-set-selections
            apt install -y vim wget curl lrzsz tar lsof dnsutils nload iperf3 screen cron openssl libsodium-dev libgnutls30 ca-certificates systemd python3-dev python3-pip locales-all
            update-ca-certificates
        elif [[ x"${release}" == x"debian" ]]; then
            apt update -y
            echo "iperf3 iperf3/start_daemon boolean false" | debconf-set-selections
            echo "libc6 glibc/restart-services string ssh exim4 cron" | debconf-set-selections
            echo "*	libraries/restart-without-asking	boolean	true" | debconf-set-selections
            apt install -y vim wget curl lrzsz tar lsof dnsutils nload iperf3 screen cron openssl libsodium-dev libgnutls30 ca-certificates systemd python3-dev python3-pip locales-all
            update-ca-certificates
        fi
        if [ ! -e /usr/local/bin/tcping ];then
            wget -O /tmp/tcping-linux-amd64-static.tar.gz https://${GITHUB_DOWNLOAD_URL}/pouriyajamshidi/tcping/releases/latest/download/tcping-linux-amd64-static.tar.gz
            tar xf /tmp/tcping-linux-amd64-static.tar.gz -C /usr/local/bin/
            chmod +x /usr/local/bin/tcping
            rm -f /tmp/tcping-linux-amd64-static.tar.gz
        fi
        echo -e "${green}完成${plain}"
}

#优化SSH安全及其他设置
set_securite(){
    echo -e "${yellow}优化SSH安全及SELINUX设置${plain}"
        if grep -q "^UseDNS" /etc/ssh/sshd_config; then
            sed -i '/^UseDNS/s/yes/no/' /etc/ssh/sshd_config
        else
           sed -i '$a UseDNS no' /etc/ssh/sshd_config
        fi
        if grep -q "^GSSAPIAuthentication" /etc/ssh/sshd_config; then
            sed -i '/^GSSAPIAuthentication/s/yes/no/' /etc/ssh/sshd_config
        else
           sed -i '$a GSSAPIAuthentication no' /etc/ssh/sshd_config
        fi
        if grep -q "^PermitEmptyPasswords" /etc/ssh/sshd_config; then
            sed -i '/^PermitEmptyPasswords/s/yes/no/' /etc/ssh/sshd_config
        else
           sed -i '$a PermitEmptyPasswords no' /etc/ssh/sshd_config
        fi
        if grep -q "^IgnoreRhosts" /etc/ssh/sshd_config; then
            sed -i 's/^IgnoreRhosts.*/IgnoreRhosts yes/' /etc/ssh/sshd_config
        else
           sed -i '$a IgnoreRhosts yes' /etc/ssh/sshd_config
        fi
        if grep -q "^HostbasedAuthentication" /etc/ssh/sshd_config; then
            sed -i '/^HostbasedAuthentication/s/yes/no/' /etc/ssh/sshd_config
        else
           sed -i '$a HostbasedAuthentication no' /etc/ssh/sshd_config
        fi
        if grep -q "^UsePAM" /etc/ssh/sshd_config; then
            sed -i '/^UsePAM/s/no/yes/' /etc/ssh/sshd_config
        else
           sed -i '$a UsePAM yes' /etc/ssh/sshd_config
        fi
        if grep -qiP '^Protocol' /etc/ssh/sshd_config; then
            sed -i "/^Protocol/cProtocol 2" /etc/ssh/sshd_config
        else
           sed -i '$a Protocol 2' /etc/ssh/sshd_config
        fi
        if grep -qiP '^MaxAuthTries' /etc/ssh/sshd_config; then
            sed -i '/^MaxAuthTries[[:space:]]/cMaxAuthTries 3' /etc/ssh/sshd_config
        else
            sed -i '$a MaxAuthTries 3' /etc/ssh/sshd_config
        fi
        if grep -qiP '^ClientAliveInterval' /etc/ssh/sshd_config; then
            sed -i '/^ClientAliveInterval[[:space:]]/cClientAliveInterval 300' /etc/ssh/sshd_config
        else
            sed -i '$a ClientAliveInterval 300' /etc/ssh/sshd_config
        fi
        if grep -qiP '^LoginGraceTime' /etc/ssh/sshd_config; then
            sed -i '/^LoginGraceTime[[:space:]]/cLoginGraceTime 30' /etc/ssh/sshd_config
        else
            sed -i '$a LoginGraceTime 30' /etc/ssh/sshd_config
        fi
        if grep -qiP '^MaxStartups' /etc/ssh/sshd_config; then
            sed -i '/^MaxStartups[[:space:]]/cMaxStartups 10:30:60' /etc/ssh/sshd_config
        else
            sed -i '$a MaxStartups 10:30:60' /etc/ssh/sshd_config
        fi
        sed -i '/^SELINUX/s/enforcing/disabled/' /etc/selinux/config && setenforce 0
        sed -i '/^SELINUX/s/permissive/disabled/' /etc/selinux/config && setenforce 0
    echo -e "${green}完成${plain}"
    echo -e "${yellow}检查系统时区${plain}"
        if [[ x"${release}" == x"centos" ]]; then
            if [ ${os_version} -eq 7 ]; then
                if [ `timedatectl | grep "Time zone" | grep -c "${TIMEZONE}"` -eq 0 ];then
                    timedatectl set-timezone ${TIMEZONE}
                    sed -i 's%SYNC_HWCLOCK=no%SYNC_HWCLOCK=yes%' /etc/sysconfig/ntpdate
                fi
                ntpdate ${NTPSERVER}
                hwclock -w
            else
                if [ `timedatectl | grep "Time zone" | grep -c "${TIMEZONE}"` -eq 0 ];then
                    timedatectl set-timezone ${TIMEZONE}
                    echo "server ${NTPSERVER} iburst" >>/etc/chrony.conf
                    systemctl restart chronyd.service
                    chronyc -a makestep
                fi
            fi
        elif [[ x"${release}" == x"ubuntu" ]]; then
            if [ `timedatectl | grep "Time zone" | grep -c "${TIMEZONE}"` -eq 0 ];then
                timedatectl set-timezone ${TIMEZONE}
            fi 
        elif [[ x"${release}" == x"debian" ]]; then
            if [ `timedatectl | grep "Time zone" | grep -c "${TIMEZONE}"` -eq 0 ];then
                timedatectl set-timezone ${TIMEZONE}
            fi 
        fi
    echo -e "${green}完成${plain}"
    echo -e "${yellow}设置历史命令记录时间点${plain}"
        if ! grep -q 'HISTTIMEFORMAT=' /etc/profile; then
            echo "export HISTTIMEFORMAT=\"%F %T \`whoami\` \"" >> /etc/profile
        fi
    echo -e "${green}完成${plain}"
    echo -e "${yellow}禁止键盘重启系统命令${plain}"
        rm -rf /usr/lib/systemd/system/ctrl-alt-del.target
    echo -e "${green}完成${plain}"
    echo -e "${yellow}检查系统字符集${plain}"
        if [[ x"${release}" == x"centos" ]]; then
            localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8
            export LC_ALL=zh_CN.UTF-8
            if grep -q "^LANG" /etc/locale.conf;then
                sed -i '/^LANG=/s/.*/LANG=zh_CN.UTF-8/' /etc/locale.conf
            else
               sed -i '$a LANG=zh_CN.UTF-8' /etc/locale.conf
            fi
        elif [[ x"${release}" == x"ubuntu" ]]; then
            echo -e "${yellow}暂无调整${plain}"
        elif [[ x"${release}" == x"debian" ]]; then
            echo -e "${yellow}暂无调整${plain}"
        fi
    echo -e "${green}完成${plain}"
    echo -e "${yellow}检查定时释放内存${plain}"
        crontab -l > /tmp/drop_cachescronconf
        if grep -wq "drop_caches" /tmp/drop_cachescronconf;then
            sed -i "/drop_caches/d" /tmp/drop_cachescronconf
        fi
        echo "0 6 * * * sync; echo 3 > /proc/sys/vm/drop_caches" >> /tmp/drop_cachescronconf
        crontab /tmp/drop_cachescronconf
        rm -f /tmp/drop_cachescronconf
    echo -e "${green}完成${plain}"
}

#优化系统最大句柄数限制
set_file(){
    echo -e "${yellow}优化系统最大句柄数限制${plain}"
    limits=/etc/security/limits.conf
    grep -Fxq "root soft nofile 512000"  $limits || echo "root soft nofile 512000"  >> $limits
    grep -Fxq "root hard nofile 512000"  $limits || echo "root hard nofile 512000"  >> $limits
    grep -Fxq "* soft nofile 512000"     $limits || echo "* soft nofile 512000"     >> $limits
    grep -Fxq "* hard nofile 512000"     $limits || echo "* hard nofile 512000"     >> $limits
    grep -Fxq "* soft nproc 512000"      $limits || echo "* soft nproc 512000"      >> $limits
    grep -Fxq "* hard nproc 512000"      $limits || echo "* hard nproc 512000"      >> $limits
    if [[ x"${release}" == x"centos" ]]; then
        if [ ${os_version} -eq 7 ]; then
            [[ -f /etc/security/limits.d/20-nproc.conf ]] && sed -i 's/4096/65535/' /etc/security/limits.d/20-nproc.conf
        fi
    fi
    ulimit -SHn 512000
    if grep -q "^ulimit" /etc/profile;then
        sed -i '/ulimit -SHn/d' /etc/profile
        echo -e "\nulimit -SHn 512000" >> /etc/profile
    else
        echo -e "\nulimit -SHn 512000" >> /etc/profile
    fi
    if [ -e /etc/pam.d/common-session ];then
        if ! grep -q "pam_limits.so" /etc/pam.d/common-session;then
            echo "session required pam_limits.so" >> /etc/pam.d/common-session
        fi
    else
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
    if [ -e /etc/pam.d/common-session-noninteractive ];then
        if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive;then
            echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
        fi
    else
        echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
    fi
    if grep -q "^DefaultLimitCORE" /etc/systemd/system.conf;then
        sed -i '/DefaultLimitCORE/d' /etc/systemd/system.conf
        echo "DefaultLimitCORE=infinity" >> /etc/systemd/system.conf
    else
        echo "DefaultLimitCORE=infinity" >> /etc/systemd/system.conf
    fi
    if grep -q "^DefaultLimitNOFILE" /etc/systemd/system.conf;then
        sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf
        echo "DefaultLimitNOFILE=512000" >> /etc/systemd/system.conf
    else
        echo "DefaultLimitNOFILE=512000" >> /etc/systemd/system.conf
    fi
    if grep -q "^DefaultLimitNPROC" /etc/systemd/system.conf;then
        sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf
        echo "DefaultLimitNPROC=512000" >> /etc/systemd/system.conf
    else
        echo "DefaultLimitNPROC=512000" >> /etc/systemd/system.conf
    fi
    systemctl daemon-reload
    echo -e "${green}完成${plain}"
}

#优化sysctl.conf
set_sysctl(){
echo -e "${yellow}优化系统内核参数${plain}"
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
sed -i '/net.ipv4.tcp_fack/d' /etc/sysctl.conf
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
net.ipv4.tcp_fack = 1
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
vm.swappiness = 0
net.core.somaxconn = 32768
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
echo -e "${yellow}→ 加载 sysctl 配置...${plain}"
/sbin/sysctl -p /etc/sysctl.conf 2>/dev/null | awk -F' = ' '{printf "  ✔ %-40s = %s\n", $1, $2}'
echo -e "${green}✓ 参数已生效${plain}"
echo -e "${green}完成${plain}"
}

#检查bbr状态
check_bbr(){
    kernel_version=$(uname -r | awk -F "-" '{print $1}')
    if [[ $(echo ${kernel_version} | awk -F'.' '{print $1}') == "4" ]] && [[ $(echo ${kernel_version} | awk -F'.' '{print $2}') -ge 9 ]] || [[ $(echo ${kernel_version} | awk -F'.' '{print $1}') == "5" ]] || [[ $(echo ${kernel_version} | awk -F'.' '{print $1}') == "6" ]]; then
        kernel_status="BBR"
    else
        kernel_status="noinstall"
    fi
    if [[ ${kernel_status} == "BBR" ]]; then
        bbr_run_status=$(cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}')
        if [[ ${bbr_run_status} == "bbr" ]]; then
            bbr_run_status=$(cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}')
            if [[ ${bbr_run_status} == "bbr" ]]; then
                bbr_run_status="${green}开启成功${plain}"
            else
                bbr_run_status="${yellow}开启失败${plain}"
            fi
        else
            bbr_run_status="${yellow}未安装加速模块${plain}"
        fi
    else
        bbr_run_status="${yellow}开启失败，请确保当前运行内核版本不低于4.9，当前版本：${kernel_version}${plain}"
    fi
}

#优化系统熵池
set_entropy(){
    entropy_value=$(cat /proc/sys/kernel/random/entropy_avail)
    if [[ ${entropy_value} -lt 1000 && ${entropy_value} -ne 256 ]]; then
        echo -e "${yellow}优化系统熵池${plain}"
        if grep -q "rdrand" /proc/cpuinfo;then
            if [[ x"${release}" == x"centos" ]]; then
                yum -y install rng-tools
                systemctl enable --now rngd
            elif [[ x"${release}" == x"ubuntu" ]]; then
                apt install -y rng-tools
                systemctl enable --now rngd
            elif [[ x"${release}" == x"debian" ]]; then
                apt install -y rng-tools
                systemctl enable --now rngd
            fi
        else
            if [[ x"${release}" == x"centos" ]]; then
                yum -y install haveged
                systemctl enable --now haveged
            elif [[ x"${release}" == x"ubuntu" ]]; then
                apt install -y haveged
                systemctl enable --now haveged
            elif [[ x"${release}" == x"debian" ]]; then
                apt install -y haveged
                systemctl enable --now haveged
            fi
        fi
        echo -e "${green}完成${plain}"

    fi
}

# 个性化vim编辑器
set_vimserver(){
    if [[ x"${release}" == x"centos" ]]; then
        echo -e "${yellow}个性化vim编辑器${plain}"
        sys_vimrc=/etc/vimrc
        user_vimrc=~/.vimrc
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
            grep -Fxq "$opt" "$sys_vimrc" || echo "$opt" >> "$sys_vimrc"
        done

        [[ -e $user_vimrc ]] || touch "$user_vimrc"
        for enc in \
            'set fileencodings=utf-8,gbk,utf-16le,cp1252,iso-8859-15,ucs-bom' \
            'set termencoding=utf-8' \
            'set encoding=utf-8'
        do
            grep -Fxq "$enc" "$user_vimrc" || echo "$enc" >> "$user_vimrc"
        done
        echo -e "${green}完成${plain}"
    elif [[ x"${release}" == x"ubuntu" ]]; then
        echo -e "${yellow}个性化vim编辑器${plain}"
        sys_vimrc=/etc/vim/vimrc
        user_vimrc=~/.vimrc
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
            grep -Fxq "$opt" "$sys_vimrc" || echo "$opt" >> "$sys_vimrc"
        done

        [[ -e $user_vimrc ]] || touch "$user_vimrc"
        for enc in \
            'set fileencodings=utf-8,gbk,utf-16le,cp1252,iso-8859-15,ucs-bom' \
            'set termencoding=utf-8' \
            'set encoding=utf-8'
        do
            grep -Fxq "$enc" "$user_vimrc" || echo "$enc" >> "$user_vimrc"
        done
        echo -e "${green}完成${plain}"
    elif [[ x"${release}" == x"debian" ]]; then
        echo -e "${yellow}个性化vim编辑器${plain}"
        sys_vimrc=/etc/vim/vimrc
        user_vimrc=~/.vimrc
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
            grep -Fxq "$opt" "$sys_vimrc" || echo "$opt" >> "$sys_vimrc"
        done

        [[ -e $user_vimrc ]] || touch "$user_vimrc"
        for enc in \
            'set fileencodings=utf-8,gbk,utf-16le,cp1252,iso-8859-15,ucs-bom' \
            'set termencoding=utf-8' \
            'set encoding=utf-8'
        do
            grep -Fxq "$enc" "$user_vimrc" || echo "$enc" >> "$user_vimrc"
        done
        echo -e "${green}完成${plain}"
    fi
}

#优化journald服务
set_journal(){
    echo -e "${yellow}优化journald服务${plain}"
    [ -e /var/log/journal ] || mkdir /var/log/journal
    if grep -q "^Storage" /etc/systemd/journald.conf;then
        sed -i '/^Storage/s/auto/persistent/' /etc/systemd/journald.conf
    else
       sed -i '$a Storage=persistent' /etc/systemd/journald.conf
    fi
    if grep -q "^ForwardToSyslog" /etc/systemd/journald.conf;then
        sed -i '/^ForwardToSyslog/s/yes/no/' /etc/systemd/journald.conf
    else
       sed -i '$a ForwardToSyslog=no' /etc/systemd/journald.conf
    fi
    if grep -q "^ForwardToWall" /etc/systemd/journald.conf;then
        sed -i '/^ForwardToWall/s/yes/no/' /etc/systemd/journald.conf
    else
       sed -i '$a ForwardToWall=no' /etc/systemd/journald.conf
    fi
    if grep -q "^SystemMaxUse" /etc/systemd/journald.conf;then
        sed -i '/^SystemMaxUse/s/.*/SystemMaxUse=384M/' /etc/systemd/journald.conf
    else
       sed -i '$a SystemMaxUse=384M' /etc/systemd/journald.conf
    fi
    if grep -q "^SystemMaxFileSize" /etc/systemd/journald.conf;then
        sed -i '/^SystemMaxFileSize/s/.*/SystemMaxFileSize=128M/' /etc/systemd/journald.conf
    else
       sed -i '$a SystemMaxFileSize=128M' /etc/systemd/journald.conf
    fi
    systemctl restart systemd-journald
    echo -e "${green}完成${plain}"
}

#个性化快捷键
set_readlines(){
    echo -e "${yellow}个性化快捷键${plain}"
    if grep -q '^"\\e.*": history-search-backward' /etc/inputrc;then
        sed -i 's/^"\\e.*": history-search-backward/"\\e\[A": history-search-backward/g' /etc/inputrc
    else
        sed -i '$a # map "up arrow" to search the history based on lead characters typed' /etc/inputrc
        sed -i '$a "\\e\[A": history-search-backward' /etc/inputrc
    fi
    if grep -q '^"\\e.*": history-search-forward' /etc/inputrc;then
        sed -i 's/^"\\e.*": history-search-forward/"\\e\[B": history-search-forward/g' /etc/inputrc
    else
        sed -i '$a # map "down arrow" to search history based on lead characters typed' /etc/inputrc
        sed -i '$a "\\e\[B": history-search-forward' /etc/inputrc
    fi
    if grep -q '"\\e.*": kill-word' /etc/inputrc;then
        sed -i 's/"\\e.*": kill-word/"\\e[3;3~": kill-word/g' /etc/inputrc
    else
        sed -i '$a # map ALT+Delete to remove word forward' /etc/inputrc
        sed -i '$a "\\e[3;3~": kill-word' /etc/inputrc
    fi
    echo -e "${green}完成${plain}"
}

#Centos增加virtio-blk和xen-blkfront外置驱动
set_drivers(){
    if [[ x"${release}" == x"centos" ]]; then
        echo -e "${yellow}优化外置驱动${plain}"
        if [ ! -e /etc/dracut.conf.d/virt-drivers.conf ];then
            echo 'add_drivers+=" xen-blkfront virtio_blk "' >> /etc/dracut.conf.d/virt-drivers.conf
        else
            if ! grep -wq "xen-blkfront" /etc/dracut.conf.d/virt-drivers.conf;then
                echo 'add_drivers+=" xen-blkfront virtio_blk "' >> /etc/dracut.conf.d/virt-drivers.conf
            fi
        fi
        echo -e "${green}完成${plain}"
    fi
}

#个性化登录展示
set_welcome(){
    echo -e "${yellow}个性化登录展示${plain}"
    if [ ! -e /etc/profile.d/motd.sh ];then
        wget -O /etc/profile.d/motd.sh https://${GITHUB_RAW_URL}/terminodev/titanicsite7/main/motd.sh
        chmod a+x /etc/profile.d/motd.sh
    fi
    echo -e "${green}完成${plain}"
}

main(){
    install
    set_securite
    set_file
    set_sysctl
    check_bbr
    set_entropy
    set_vimserver
    set_journal
    set_readlines
    set_drivers
    set_welcome
}
main

rm -f startsys.sh && history -c
echo -e "【提示】优化完成，BBR拥塞控制状态：${bbr_run_status}"
