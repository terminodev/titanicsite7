#!/bin/bash
#########################################################################
# File Name: motd.sh
# Update Time: 2025.05.30
#########################################################################

# Don't change! We want predictable outputs
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

        一个真诚的人会做他想做的事，不是他必须做的事。
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
# Source: https://github.com/KittyKatt/screenFetch/issues/386#issuecomment-249312716

mem_info=$(</proc/meminfo)
mem_total=$(awk '$1=="MemTotal:" {print $2}' <<< ${mem_info})
mem_used=$((${mem_total} + $(cat /proc/meminfo | awk '$1=="Shmem:" {print $2}')))
mem_used=$((${mem_used} - $(cat /proc/meminfo | awk '$1=="MemFree:" {print $2}')))
mem_used=$((${mem_used} - $(cat /proc/meminfo | awk '$1=="Buffers:" {print $2}')))
mem_used=$((${mem_used} - $(cat /proc/meminfo | awk '$1=="Cached:" {print $2}')))
mem_used=$((${mem_used} - $(cat /proc/meminfo | awk '$1=="SReclaimable:" {print $2}')))

mem_total=$((mem_total / 1024))
mem_used=$((mem_used / 1024))
mem_usage=$((100 * ${mem_used} / ${mem_total}))

#
# Load average
#

load_average=$(awk '{print $1" "$2" "$3}' /proc/loadavg)

#
# Disk
#

disk_used=$(df -h | grep " /$" | cut -f4 | awk '{printf "%s / %s (%s)", $3, $2, $5}')

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

user_num=$(who -u | wc -l)

echo -e "\033[0;36;40m$logo\033[0m"
echo -e "操作系统: \t$system_os"
echo -e "内核版本: \t$kernel_version"
echo -e "拥塞控制: \t$tcpcc + $qdisc"
echo -e "系统时间: \t$time_cur"
echo -e "运行时间: \t$up_time"
echo -e "系统负载: \t\033[0;33;40m$load_average\033[0m"
echo -e "内存使用: \t\033[0;31;40m$mem_used\033[0m MiB / \033[0;32;40m$mem_total\033[0m MiB ($mem_usage%)"
echo -e "磁盘使用: \t$disk_used"
echo -e "在线用户: \t${user_num}\n"
