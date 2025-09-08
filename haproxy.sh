#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================================#
#   System Required: CentOS, Debian, Ubuntu                       #
#   Description: Install haproxy server                           #
#=================================================================#

clear
echo ""
echo "#############################################################"
echo "# Install haproxy server                                    #"
echo "#############################################################"
echo ""

rootness(){
    if [[ $EUID -ne 0 ]]; then
       echo "Error:This script must be run as root!" 1>&2
       exit 1
    fi
}

checkos(){
    if [[ -f /etc/redhat-release ]];then
        OS=CentOS
    elif cat /etc/issue | grep -q -E -i "debian";then
        OS=Debian
    elif cat /etc/issue | grep -q -E -i "ubuntu";then
        OS=Ubuntu
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat";then
        OS=CentOS
    elif cat /proc/version | grep -q -E -i "debian";then
        OS=Debian
    elif cat /proc/version | grep -q -E -i "ubuntu";then
        OS=Ubuntu
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat";then
        OS=CentOS
    else
        echo "Not supported OS, Please reinstall OS and try again."
        exit 1
    fi
}

disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

config_haproxy(){
    [ -e /etc/haproxy ] || mkdir -p /etc/haproxy
    if [ -f /etc/haproxy/haproxy.cfg ];then
        cp -p /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
    fi

    cat > /etc/haproxy/haproxy.cfg<<-EOF
global
    ulimit-n    51200
    log         127.0.0.1 local2
    chroot      /var/spool/haproxy
    user        haproxy
    group       haproxy
    daemon

defaults
    mode                    tcp
    log                     global
    option                  dontlognull
    timeout connect         5s
    timeout client          1m
    timeout server          1m
    retries                 3
    maxconn                 20480
    balance                 roundrobin

listen stats
    mode    http
    bind    :::9999 v4v6
    stats   refresh 5s
    stats   uri  /status
    stats   auth admin:123456
    stats   hide-version
    stats   admin if TRUE

frontend lb-in1
        bind :::40001 v4v6
        default_backend lb-out1

frontend lb-in2
        bind :::40002 v4v6
        default_backend lb-out2

backend lb-out1
        server server1 1.1.1.1:1080 check inter 1s rise 2 fall 5 weight 100
        server server2 1.0.0.1:1080 check inter 1s rise 2 fall 5 weight 100

backend lb-out2
        server server1 1.1.1.1:1080 check inter 1s rise 2 fall 5 weight 100
        server server2 1.0.0.1:1080 check inter 1s rise 2 fall 5 weight 100
EOF

    cat > /usr/lib/systemd/system/haproxy.service<<-EOF
[Unit]
Description=HAProxy Load Balancer
After=network-online.target
Wants=network-online.target

[Service]
#EnvironmentFile=-/etc/default/haproxy
#EnvironmentFile=-/etc/sysconfig/haproxy
Environment="CONFIG=/etc/haproxy/haproxy.cfg" "PIDFILE=/run/haproxy.pid" "EXTRAOPTS=-S /run/haproxy-master.sock"
ExecStart=/usr/local/haproxy/sbin/haproxy -Ws -f \$CONFIG -p \$PIDFILE \$EXTRAOPTS
ExecReload=/usr/local/haproxy/sbin/haproxy -Ws -f \$CONFIG -c -q \$EXTRAOPTS
ExecReload=/bin/kill -USR2 \$MAINPID
KillMode=mixed
Restart=always
SuccessExitStatus=143
Type=notify
LimitCORE=infinity
LimitNOFILE=512000
LimitNPROC=512000

# The following lines leverage SystemD's sandboxing options to provide
# defense in depth protection at the expense of restricting some flexibility
# in your setup (e.g. placement of your configuration files) or possibly
# reduced performance. See systemd.service(5) and systemd.exec(5) for further
# information.

# NoNewPrivileges=true
# ProtectHome=true
# If you want to use 'ProtectSystem=strict' you should whitelist the PIDFILE,
# any state files and any other files written using 'ReadWritePaths' or
# 'RuntimeDirectory'.
# ProtectSystem=true
# ProtectKernelTunables=true
# ProtectKernelModules=true
# ProtectControlGroups=true
# If your SystemD version supports them, you can add: @reboot, @swap, @sync
# SystemCallFilter=~@cpu-emulation @keyring @module @obsolete @raw-io

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
}

install(){
    # Install haproxy
    if [ "${OS}" == 'CentOS' ];then
        yum install wget gcc gcc-c++ make readline-devel openssl openssl-devel pcre pcre-devel systemd systemd-devel -y
    else
        apt -y update
        apt install wget gcc openssl libssl-dev libpcre3 libpcre3-dev zlib1g-dev openssh-server libreadline-dev libsystemd-dev -y
    fi
    cd /usr/local/src
    [ -e lua-5.4.7 ] && rm -rf lua-5.4.7
    wget -O lua-5.4.7.tar.gz http://www.lua.org/ftp/lua-5.4.7.tar.gz
    tar zxf lua-5.4.7.tar.gz
    cd lua-5.4.7
    make linux test
    cd /usr/local/src
    targetversion=$(wget -qO- -t1 -T2 "https://www.haproxy.org/download/3.0/src/releases.json" | grep "latest_release" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
    [ -e haproxy-${targetversion} ] && rm -rf haproxy-${targetversion}
    wget -O haproxy-${targetversion}.tar.gz https://www.haproxy.org/download/3.0/src/haproxy-${targetversion}.tar.gz
    tar xvf haproxy-${targetversion}.tar.gz
    cd haproxy-${targetversion}
    make -j $(nproc) ARCH_FLAGS='-g' TARGET=linux-glibc USE_PCRE=1 USE_OPENSSL=1 USE_ZLIB=1 USE_SYSTEMD=1 USE_LUA=1 LUA_INC=/usr/local/src/lua-5.4.7/src/ LUA_LIB=/usr/local/src/lua-5.4.7/src/
    make install PREFIX=/usr/local/haproxy
    mkdir -p /var/spool/haproxy
    groupadd -g 200 haproxy
    useradd -u 200 -g 200 -d /var/spool/haproxy -s /sbin/nologin haproxy
    chown haproxy:haproxy /var/spool/haproxy
    config_haproxy
    if [ -e /usr/local/haproxy/sbin/haproxy ]; then
        systemctl enable haproxy --now
    else
        echo ""
        echo "haproxy install failed."
        exit 1
    fi
    echo
    echo "Congratulations, haproxy install completed."
    echo "Enjoy it."
    echo
    exit 0
}


# Install haproxy
install_haproxy(){
    checkos
    rootness
    disable_selinux
    install
}

# Initialization step
install_haproxy
