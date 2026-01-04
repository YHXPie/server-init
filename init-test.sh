#!/bin/bash

# init-test.sh

# Copyright (C) 2025 StreamingHX/yhxpie
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# 从 tty 读取输入是为了兼容 curl | bash 的运行方式
# 面板安装链接会定期手动更新

set -e
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' 

echo -e "\n${RED} ===> 开始执行快速服务器初始化... <=== ${NC}"

# ===> 检查是否以 root 运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED} 请使用 root 权限运行此脚本：sudo $0${NC}"
   exit 1
fi

TOTAL_STEPS=5
echo -e "\n${RED} ===> 执行内容：${NC}"
echo -e "\n${GREEN} 1. 设置 Asia/Shanghai 时区 "
echo -e " 2. 启用系统 BBR 算法 "
echo -e " 3. 配置 Swap 交换空间 "
echo -e " 4. 调整 apt 源并配置软件更新 "
echo -e " 5. 安装宝塔面板和 Docker "
echo -e "\n ${RED} 执行时建议时刻保持状态监控 ${NC}"
sleep 1s

# ===> 1. 设置时区
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true || true
systemctl restart systemd-timesyncd.service 2>/dev/null || TIME_SYNC_AGAIN=yes
timedatectl set-local-rtc 0 || true

# ===> 2. 启用系统 TCP BBR
if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# ===> 3. 配置 Swap：512MB
if [ ! -f /swapfile ]; then
    fallocate -l 512M /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$(echo 512M | sed 's/G/*1024/;s/M//' | bc)
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab 
fi

# ===> 4. 配置 apt 源与基础软件
apt --fix-broken install -y || true
# 直接使用 curl 获取服务器地区
if curl -s --retry 2 --connect-timeout 3 https://www.google.com > /dev/null; then
    SERVER_LOCATION=GLOBAL
else
    SERVER_LOCATION=CNMainLand
fi
# 获取 apt 资源文件
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    SOURCE_FILE="/etc/apt/sources.list.d/ubuntu.sources"
else
    SOURCE_FILE="/etc/apt/sources.list"
fi
# 修改 apt 资源文件
if [ "$SERVER_LOCATION" = "CNMainLand" ]; then
    if grep -q "Ubuntu" /etc/issue; then
        sed -i 's@http://.*archive.ubuntu.com@http://mirrors.nju.edu.cn@g' "$SOURCE_FILE"
        sed -i 's@http://.*security.ubuntu.com@http://mirrors.nju.edu.cn@g' "$SOURCE_FILE"
        sed -i 's@http://ports.ubuntu.com@http://mirrors.nju.edu.cn@g' "$SOURCE_FILE"
    elif grep -q "Debian" /etc/issue; then
        sed -i 's@http://deb.debian.org@http://mirrors.nju.edu.cn@g' "$SOURCE_FILE"
        sed -i 's@http://security.debian.org@http://mirrors.nju.edu.cn@g' "$SOURCE_FILE"
    fi
fi

apt update

PACKAGES="vim nano bash curl wget htop qemu-guest-agent locales systemd-timesyncd"
apt purge -y needrestart || true
apt install -y $PACKAGES
if command -v locale-gen &> /dev/null; then
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8
else
    dpkg-reconfigure -f noninteractive locales || true
fi
# 有必要则使用 systemd-timesyncd 再次同步时间
if [ "$TIME_SYNC_AGAIN" = "yes" ]; then
    systemctl enable --now systemd-timesyncd || true
    timedatectl set-ntp on || true
    timedatectl set-local-rtc 0 || true
    timedatectl
fi

apt upgrade -y

# ===> 5. 安装增强性组件
echo -e "\n${RED} 是否需要安装最新版宝塔面板 [Y/n]： \n${NC}"
read -r PANEL_CHOICE < /dev/tty
# 开始面板安装逻辑
dpkg --configure -a || true
apt --fix-broken install -y || true
if [[ "$PANEL_CHOICE" =~ ^[Yy]$ ]]; then
# 面板安装脚本将统一命名为 install_panel.sh 方便清理
# https://www.bt.cn/new/download.html
    wget --tries=5 --timeout=25 -O install_panel.sh https://download.bt.cn/install/install_panel.sh
    bash install_panel.sh ssl251104
    NEED_SAVE_PANEL_INFO=true
else
    NEED_SAVE_PANEL_INFO=false
fi
if [ "$NEED_SAVE_PANEL_INFO" = true ]; then
    # 确认保存登录信息
    echo -e "\n${RED} ===> 关键信息确认：请务必保存上方的面板登录信息 ${NC}"
    while true; do
        echo -ne "\n${RED} ===> 输入 'ok' 以继续... (Type 'ok' to continue): ${NC}"
        read -r PANEL_INFO_SAVE_CONFIRM < /dev/tty
        if [[ "$PANEL_INFO_SAVE_CONFIRM" == "ok" ]] || [[ "$PANEL_INFO_SAVE_CONFIRM" == "OK" ]]; then
            break
        else
            echo -e "\n${RED} ===> 输入 'ok' 以继续... (Type 'ok' to continue): ${NC}"
        fi
    done
fi
# 预定义 Docker 安装步骤
function install_docker() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
        VERSION_ID=$(lsb_release -rs)
    fi
    # 版本号检查
    if [[ "$ID" == "ubuntu" ]]; then
        if [[ "$VERSION_ID" < "22.00" ]]; then
            HOW_TO_INSTALL_DOCKER=apt
        else
            HOW_TO_INSTALL_DOCKER=official
        fi
    elif [[ "$ID" == "debian" ]]; then
        local DEB_MAIN=$(echo "$VERSION_ID" | cut -d. -f1)
        if [[ "$DEB_MAIN" -lt 11 ]]; then
            HOW_TO_INSTALL_DOCKER=apt
        else
            HOW_TO_INSTALL_DOCKER=official
        fi
    fi
    if [ "$HOW_TO_INSTALL_DOCKER" = official ]; then
        curl -fsSL --retry 25 --retry-delay 5 --retry-all-errors --connect-timeout 20 https://get.docker.com -o get-docker.sh
        case "$SERVER_LOCATION" in
        "GLOBAL")
            bash get-docker.sh
            ;;
        "CNMainLand")
            bash get-docker.sh --mirror Aliyun
            ;;
        *)
            bash get-docker.sh
            ;;
        esac
    else
        apt install -y docker docker.io || true
    fi
}
install_docker || true

# ===> 采集基本系统信息
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | awk -F: '{print $2}' | sed 's/^[ \t]*//')
MEM_USAGE=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
SWAP_USAGE=$(free -h | awk '/Swap:/ {print $3 "/" $2}')
DISK_USAGE=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
if [ -f /etc/os-release ]; then
    . /etc/os-release
    SYSTEM_INFO="$PRETTY_NAME"
else
    SYSTEM_INFO="Unknown Linux"
fi
KERNEL_VER=$(uname -r)
PUBLIC_IP=$(curl -s --max-time 3 https://api.ip.sb/ip -A Mozilla || echo "获取失败")
sleep 1s

echo -e "\n${GREEN} ============================================= ${NC}"
echo -e "${GREEN}               系统状态信息检查 ${NC}"
echo -e "${GREEN} ============================================= ${NC}"
echo -e "${GREEN} CPU 信息 ${NC}     : ${CPU_MODEL} "
echo -e "${GREEN} 内存占用 ${NC}     : ${MEM_USAGE} "
echo -e "${GREEN} Swap 占用 ${NC}    : ${SWAP_USAGE} "
echo -e "${GREEN} 磁盘空间占用 ${NC} : ${DISK_USAGE} "
echo -e "${GREEN} 系统信息 ${NC}     : ${SYSTEM_INFO} "
echo -e "${GREEN} 内核版本 ${NC}     : ${KERNEL_VER} "
echo -e "${GREEN} 公网 IP 信息 ${NC} : ${PUBLIC_IP} "
echo -e "\n${RED} 快速初始化已完成 ${NC} "

# 自行清理
if [ -f "$0" ]; then
    rm -f "$0"
    echo " init-test.sh 脚本清理已完成 "
fi

echo -e "\n  ____________________________ "
echo -e " | GitHub: yhxpie/server-init | \n"

# Done.

# GitHub: @yhxpie
# https://github.com/yhxpie/server-init
# Version 1.0.5
# Last Update: 2026-1-4
