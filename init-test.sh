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
NC='\033[0m' 
echo -e "\n${GREEN} ===> 开始执行快速服务器初始化... <=== ${NC}"
# 检查是否以 root 运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${GREEN} 请使用 root 权限运行此脚本：sudo $0${NC}"
   exit 1
fi

echo -e "\n${GREEN} ===> 执行内容：${NC}"
echo -e "\n${GREEN} 1. 设置 Asia/Shanghai 时区 "
echo -e " 2. 启用系统 BBR 算法 "
echo -e " 3. 调整 apt 源并配置软件更新 "
echo -e " 4. 安装宝塔面板和 Docker "
echo -e "\n ${GREEN} 执行时建议时刻保持状态监控 ${NC}"
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

# ===> 3. 配置 apt 源与基础软件
apt --fix-broken install -y || true
# 直接使用 curl 获取服务器地区
if ! curl -s --retry 2 --connect-timeout 3 https://www.google.com > /dev/null; then
    SERVER_LOCATION=CN
fi
# 获取 apt 资源文件
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    SOURCE_FILE="/etc/apt/sources.list.d/ubuntu.sources"
else
    SOURCE_FILE="/etc/apt/sources.list"
fi
# 修改 apt 资源文件
if [ "$SERVER_LOCATION" = "CN" ]; then
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
# 安装必备软件
PACKAGES="vim nano bash wget htop qemu-guest-agent locales systemd-timesyncd"
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
# 系统更新
apt upgrade -y

# ===> 4. 安装增强性组件
echo -ne "\n${GREEN} 是否需要安装最新版宝塔面板 [y/N]： \n${NC}"
read -r PANEL_CHOICE < /dev/tty
apt --fix-broken install -y || true
# 开始面板安装逻辑
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
    echo -e "\n${GREEN} ===> 关键信息确认：请保存上方的面板登录信息，按任意键继续 ${NC}"
    read -r PANEL_INFO_SAVE_CONFIRM < /dev/tty
fi
# 预定义 Docker 安装步骤
function official_install_docker() {
    curl -fsSL --retry 25 --retry-delay 5 --retry-all-errors --connect-timeout 20 https://get.docker.com -o get-docker.sh
    if [ "$SERVER_LOCATION" = CN ]; then
        bash get-docker.sh --mirror Aliyun
    else
        bash get-docker.sh
    fi
}
official_install_docker || apt install -y docker docker.io

# 清理
apt autoremove -y

# ===> 采集基本系统信息
MEM_USAGE=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
DISK_USAGE=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
sleep 1s
echo -e "${GREEN} 内存占用 ${NC}     : ${MEM_USAGE} "
echo -e "${GREEN} 磁盘空间占用 ${NC} : ${DISK_USAGE} "
echo -e "\n${GREEN} 快速初始化已完成 ${NC} "

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
# Version 1.0.6
# Last Update: 2026-1-6
