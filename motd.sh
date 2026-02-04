#!/usr/bin/env bash
#####################################################
# /etc/profile.d/motd.sh - Login Welcome!
#####################################################

export LANG="en_US.UTF-8"

#
# Logo
#

logo[1]="
                !         !
               ! !       ! !
              ! . !     ! . !
                 ^^^^^^^^^ ^
               ^             ^
             ^  (0)       (0)  ^
            ^        ""         ^
           ^   ***************    ^
         ^   *                 *   ^
        ^   *   /\   /\   /\    *    ^
       ^   *                     *    ^
      ^   *   /\   /\   /\   /\   *    ^
     ^   *                         *    ^
     ^  *                           *   ^
     ^  *                           *   ^
      ^ *                           *  ^
       ^*                           * ^
        ^ *                        * ^
        ^  *                      *  ^
          ^  *       ) (         * ^
              ^^^^^^^^ ^^^^^^^^^

      别忘了备份，也别忘了爱自己。
"
logo[2]="
       ┏┓ 　┏┓+ +
　　　┏┛┻━━━┛┻┓ + +
　　　┃ 　　　┃
　　　┃　━　　┃ ++ + + +
　　 ███━███  ┃+
　　　┃　 　　┃ +
　　　┃　┻　　┃
　　　┃　 　　┃ + +
　　　┗━┓ 　┏━┛
　　　　┃ 　┃
　　　　┃ 　┃ + + + +
　　　　┃ 　┃
　　　　┃ 　┃ + 　　神兽保佑,永不宕机！
　　　　┃ 　┃
　　　　┃ 　┃　　+
　　　　┃ 　┗━━━┓ + +
　　　　┃ 　　　┣┓
　　　　┃　 　　┏┛
　　　　┗┓┓┏━┳┓┏┛ + + + +
　　 　　┃┫┫ ┃┫┫
　　 　　┗┻┛ ┗┻┛+ + + +
"
logo[3]="
  　　┏┓ 　┏┓
 　　┏┛┻━━━┛┻┓
 　　┃　　　 ┃
 　　┃ 　━　 ┃
 　　┃ ┳┛　┗┳┃
 　　┃　　　 ┃
 　　┃ 　┻　 ┃
 　　┃　　　 ┃
 　　┗━┓ 　┏━┛
 　　　┃ 　┃    神兽保佑,永不宕机！
 　　　┃ 　┃
 　　　┃ 　┗━━━┓
 　　　┃　　　 ┣┓
 　　　┃　　　 ┏┛
 　　　┗┓┓┏━┳┓┏┛
 　 　　┃┫┫ ┃┫┫
 　 　　┗┻┛ ┗┻┛
"
logo[4]='
      ___________________________
     |  =======================  |
     |    今日不炸，功德无量     |
     |  =======================  |
     |___________________________|
         \   ^__^
          \  (oo)\_______
             (__)\       )\/\
                 ||----w |
                 ||     ||
'
logo[5]='
         ██████╗  ██████╗ ██████╗
         ██╔══██╗██╔═══██╗██╔══██╗
         ██████╔╝██║   ██║██║  ██║
         ██╔══██╗██║   ██║██║  ██║
         ██║  ██║╚██████╔╝██████╔╝
         ╚═╝  ╚═╝ ╚═════╝ ╚═════╝
         代码能跑就不要动它！
'
logo[6]='
            .-~~~~~~~~~-.
        .-~           ~-.
       /   ()      ()   \
      /        ~~        \
      |  |  |      |  |  |
       \ \  \    /  /  /
        ~-._~~--~~_.-~
            ~-.__.-~
        咸鱼也要翻身！
'
logo[7]='
            __
           /  \
          /    \
         /  /\  \
        /  /  \  \
       /  /~~~~\  \
      /  /      \  \
     /__/        \__\
     搬砖不忘喝茶
'
logo[8]='
         ╔═══════════════════════╗
         ║  今日份快乐 GET ✔     ║
         ╚═══════════════════════╝
              \
               \   /\\
                \_/  \\
                  \__/\\
                     \__/
'
logo[9]='
         ░░░░░░░░░░░░░░░░░░░░
         ░  佛系运维 · 随缘 ░
         ░░░░░░░░░░░░░░░░░░░░
              ( ´･ω･)
               (  )
              (    )
'
logo[10]='
         ┌─────────────────────┐
         │  警告：内有萌物！   │
         └─────────────────────┘
             (\\__/)
             (•ㅅ•)
            c(”)(”)
'

logo=${logo[$[$RANDOM % ${#logo[@]} + 1]]}

#
# System
#

system_os=$(grep -w PRETTY_NAME /etc/os-release|awk -F '"' '{printf $2}')

#
# Kernel
#

kernel_version=$(uname -r)

#
# Tcpcc & qdisc
#

tcpcc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null)"

#
# Memory
#
# MemUsed = Memtotal + Shmem - MemFree - Buffers - Cached - SReclaimable
# From: https://github.com/KittyKatt/screenFetch/issues/386#issuecomment-249312716

read mem_total mem_free buffers cached sreclaimable shmem \
     < <(awk '/^MemTotal:/ {mt=$2}
              /^MemFree:/  {mf=$2}
              /^Buffers:/  {bf=$2}
              /^Cached:/   {cd=$2}
              /^SReclaimable:/ {sr=$2}
              /^Shmem:/    {sm=$2}
              END{print mt,mf,bf,cd,sr,sm}' /proc/meminfo)
mem_used=$(( mem_total + shmem - mem_free - buffers - cached - sreclaimable ))
mem_total=$(( mem_total / 1024 ))
mem_used=$((  mem_used  / 1024 ))
mem_usage=$(( 100 * mem_used / mem_total ))

#
# Load average
#

load_average=$(awk '{print $1" "$2" "$3}' /proc/loadavg)

#
# Disk
#

disk_used=$(df -h / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')

#
# Time
#

time_cur=$(date "+%F %T %Z %z")

#
# Uptime
#

up_time=$(uptime | awk -F'( |,|:)+' '{d=h=m=0; if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours,",m+0,"minutes"}')

#
# Username
#

user=${USER:-$(id -un)}
hostname=${HOSTNAME:-$(hostname)}

#
# Users
#

user_num=$(who -q | awk '{print NF; exit}')

#
# Show Start
#

echo -e "\033[0;36m$logo\033[0m"
echo -e "操作系统: \t$system_os"
echo -e "内核版本: \t$kernel_version"
echo -e "拥塞算法: \t$tcpcc + $qdisc"
echo -e "当前时间: \t$time_cur"
echo -e "运行时长: \t$up_time"
echo -e "系统负载: \t\033[0;33;40m$load_average\033[0m"
echo -e "内存用量: \t\033[0;31;40m$mem_used\033[0m MiB / \033[0;32;40m$mem_total\033[0m MiB ($mem_usage%)"
echo -e "磁盘用量: \t$disk_used"
echo -e "在线人数: \t${user_num}\n"
