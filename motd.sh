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
            ^        \"\"         ^
           ^   ***************    ^
         ^   *                 *   ^
        ^   *   /\\   /\\   /\\    *    ^
       ^   *                     *    ^
      ^   *   /\\   /\\   /\\   /\\   *    ^
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
         ╔═══════════════════════════════════════╗
         ║  服务器状态：活着，且不想死            ║
         ╚═══════════════════════════════════════╝
              \\
               \\   /\\
                \\ /  \\
                 |    |
                /      \\
               /   /\\   \\
              /___/  \\___\\
"

logo[3]="
            ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
            █  正在运行...大概吧  █
            ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
                 \\   ^__^
                  \\  (oo)\\_______
                     (__)\\       )\\/\\
                         ||----w |
                         ||     ||
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

logo[6]="
         ┌─────────────────────────────┐
         │  系统状态：薛定谔的稳定      │
         └─────────────────────────────┘
              /\\
             /  \\    /\\
            /    \\  /  \\
           /  /\\  \\/  /\\
          /  /  \\    /  \\
         /__/    \\  /____\\
              也许能用
"

logo[7]="
         ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
         ▓  正在假装很忙的样子...    ▓
         ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
              \\    /
               \\  /
            ┌──┴──┐
            │ ●  ● │
            │   皿  │
            └──┬──┘
               │
          ┌────┴────┐
          │ 咖啡续命中 │
          └─────────┘
"

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

os_info=$(grep -w PRETTY_NAME /etc/os-release|awk -F '"' '{printf $2}')

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
# MemUsed = Memtotal + Shmem - MemFree - Buffers - Cached - SReclaimable (From: https://github.com/KittyKatt/screenFetch/issues/386#issuecomment-249312716  )

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

disk_info=$(df -h / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')

#
# Time
#

time_cur=$(date "+%F %T %Z %z")

#
# Uptime
#

uptime_info=$(uptime | awk -F'( |,|:)+' '{d=h=m=0; if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d+0,"天,",h+0,"小时,",m+0,"分钟"}')

#
# Username
#

user=${USER:-$(id -un)}
hostname=${HOSTNAME:-$(hostname)}

#
# Users
#

active_users=$(who -q | awk '{print NF; exit}')

#
# Show Start
#

echo -e "\033[0;36m$logo\033[0m"
echo -e "操作系统: \t$os_info"
echo -e "内核版本: \t$kernel_version"
echo -e "拥塞控制: \t$tcpcc + $qdisc"
echo -e "系统时间: \t$time_cur"
echo -e "运行时长: \t$uptime_info"
echo -e "系统负载: \t\033[0;33;40m$load_average\033[0m"
echo -e "内存使用: \t\033[0;31;40m$mem_used\033[0m MiB / \033[0;32;40m$mem_total\033[0m MiB ($mem_usage%)"
echo -e "磁盘使用: \t$disk_info"
echo -e "登录用户: \t$user@$hostname"
echo -e "在线会话: \t${active_users}\n"
