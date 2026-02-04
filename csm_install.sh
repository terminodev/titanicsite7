#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

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

setcrontask(){ 
    crontab -l >/tmp/csmcrontab.tmp
    if grep -wq "csm.sh" /tmp/csmcrontab.tmp;then
        sed -i "/csm.sh/d" /tmp/csmcrontab.tmp
    fi
    echo "0 */6 * * * /bin/bash /opt/csm.sh" >>/tmp/csmcrontab.tmp
    crontab /tmp/csmcrontab.tmp
    rm -rf /tmp/csmcrontab.tmp
    echo -e "${green}默认检测时间：每隔6小时检测一次${plain}"
    echo -e "${green}如需时间修改请执行命令：crontab -e ${plain}"
}

install_csm(){
    getConfig() {
        wget -N --no-check-certificate -O /opt/csm.sh https://raw.githubusercontent.com/iamsaltedfish/check-stream-media/main/csm.sh
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
        chmod +x /opt/csm.sh
        curl -s "${apihost}/mod_mu/nodes?key=${apikey}" | grep "invalid" > /dev/null
        if [[ "$?" = "0" ]];then
            echo -e "${red}网站地址或MUKEY错误，请重试。${plain}"
            exit 1
        fi
        echo "${apihost}" > /root/.csm.config
        echo "${apikey}" >> /root/.csm.config
        echo "${nodeid}" >> /root/.csm.config
        setcrontask
        /bin/bash /opt/csm.sh
    }

    if [[ -e "/root/.csm.config" ]];then
        confirm "流媒体检测后端已安装，是否继续覆盖安装?" "n"
        if [[ $? != 0 ]]; then
            echo -e "${red}已取消${plain}"
        else
            getConfig
        fi
    else
        getConfig
    fi
}

hello(){
    echo ""
    echo -e "${yellow}流媒体解锁测试后端一键安装脚本${plain}"
    echo -e "${yellow}支持系统:  CentOS 7+, Debian8+, Ubuntu16+${plain}"
    echo ""
}

help(){
    hello
    echo "使用示例：bash $0 -p SSpanel -w http://www.domain.com:80 -k apikey -i 10"
    echo ""
    echo "  -h     显示帮助信息"
    echo "  -p     【必填】指定前端面板类型，默认为SSpanel，可选：SSPanel,V2board,PMpanel,Proxypanel"
    echo "  -w     【必填】指定WebApi地址，例：http://www.domain.com:80"
    echo "  -k     【必填】指定WebApikey"
    echo "  -i     【必填】指定节点ID"
    echo ""
}

apihost=www.domain.com
apikey=demokey
nodeid=demoid

if [[ $# -eq 0 ]];then
    help
    exit 1
fi
while getopts ":p:w:k:i:h" optname
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
if [[ ! "${nodeid}" =~ ^[0-9]+$ ]]; then   
    echo -e "${red}-i 选项参数值仅限数字格式，请输入正确的参数值并重新运行${plain}"
    exit 1
fi 

install_csm
