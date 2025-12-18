#!/bin/bash

# init.sh

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

# GitHub: @yhxpie
# https://github.com/yhxpie/server-init
# Version 1.0.0
# Last Update: 2025-12-18

# 从 tty 读取输入是为了兼容 curl | bash 的运行方式

# 面板安装链接会定期手动更新

# ===> 基础设置与检查
# 遇到错误立即停止
set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
# No Color
NC='\033[0m' 

# ===> 逻辑开始
echo -e "\n${RED} ===> 开始执行服务器初始化... <=== ${NC}"
sleep 1s

# ===> 检查是否以 root 运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED} 请使用 root 权限运行此脚本 $0${NC}"
   exit 1
fi

# ===> 定义全局步骤数量
# 不包含最初的修改主机名称
TOTAL_STEPS=10

# ===> 输出基本内容
echo -e "\n${RED} ===> 执行内容：${NC}"
echo -e "\n${GREEN} 0. 设置主机名称 "
echo -e " 1. 设置 Asia/Shanghai 时区 "
echo -e " 2. 启用系统 BBR 算法 "
echo -e " 3. 配置 Swap 交换空间 "
echo -e " 4. 调整 apt 源并配置软件、系统更新 "
echo -e " 5. 启用 ufw 防火墙 "
echo -e " 6. 配置防爆破组件 "
echo -e " 7. 执行系统内核更新 "
echo -e " 8. 卸载 Ubuntu Snap "
echo -e " 9. 系统磁盘空间优化 "
echo -e " 10. 可选：安装增强性组件 "
echo -e "     - 面板 / Docker ... ${NC}"
echo -e "\n ${RED} 执行时建议时刻保持状态监控 ${NC}"
echo -e "\n 等待 5 秒... "
sleep 5s

# ===> 0. 交互式修改主机名
echo -e "\n${GREEN} [0/$TOTAL_STEPS] ===> 主机名配置 ${NC}"
echo -e " 当前主机名: ${GREEN} $(hostname) ${NC}"
echo -ne "\n${GREEN} 是否需要修改主机名? [y/N]: ${NC}"
read -r CHANGE_HOSTNAME < /dev/tty
sleep 1s

if [[ "$CHANGE_HOSTNAME" =~ ^[Yy]$ ]]; then
    echo -e "\n${RED} 主机名仅允许只允许字母、数字、下划线、短横线 ${NC}"
    echo -ne "${YELLOW} ===> 请输入新的主机名: ${NC}"
    read -r NEW_HOSTNAME < /dev/tty
    if [[ -n "$NEW_HOSTNAME" ]]; then
        echo -e "\n${GREEN} ===> 正在设置... ${NC}"
        hostnamectl set-hostname "$NEW_HOSTNAME"
        # 尝试修正 /etc/hosts 里的记录，防止 sudo 解析慢
        sed -i "s/127.0.1.1.*/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts
        echo -e "\n${GREEN} ===> 主机名修改完成 ${NC}"
        echo -e "${GREEN} ===> Done. ${NC}"
        sleep 3s
    else
        echo -e "\n${GREEN} 跳过修改 ${NC}"
        sleep 1s
    fi
else
    echo -e "\n${GREEN} 跳过修改 ${NC}"
    sleep 1s
fi
clear

# ===> 1. 设置时区
echo -e "${GREEN} ===> [1/$TOTAL_STEPS] 正在设置时区为 Asia/Shanghai... ${NC}"
sleep 1s
timedatectl set-timezone Asia/Shanghai

# 同步时间
timedatectl set-ntp true
sleep 1s

# 重启时间同步服务，确保立即生效
# 加 || true 防止部分 Minimal 系统没有该服务报错
systemctl restart systemd-timesyncd.service 2>/dev/null || true
sleep 1s

# 显示时间
echo -e "\n${RED} 当前时间${NC}: $(date)"
echo -e "${GREEN} ===> Done. ${NC}"
sleep 3s
clear

# ===> 2. 启用系统 TCP BBR
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... DONE √ "
echo -e " ===> [2/$TOTAL_STEPS] 配置 TCP BBR... ${NC}"
sleep 1s

if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    echo -e "\n${GREEN} ===> BBR 已成功启用 ${NC}"
    echo -e "${GREEN} ===> Done. ${NC}"
    sleep 3s
else
    echo -e "\n${GREEN} BBR 配置已存在，跳过当前步骤 ${NC}"
    sleep 1s
fi
clear

# ===> 3. 配置 Swap (智能判断内存大小)
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... DONE √ "
echo -e " [2/$TOTAL_STEPS] 配置 TCP BBR... DONE √ "
echo -e " ===> [3/$TOTAL_STEPS] 检查并配置 Swap... ${NC}"
sleep 1s

# 检查是否已经存在 swapfile
if [ -f /swapfile ]; then
    echo -e "\n${GREEN} Swap 已存在，跳过创建步骤 ${NC}"
    sleep 1s
else
    # 获取物理内存大小 (MB)
    MEM_Total=$(free -m | awk '/Mem:/ { print $2 }')
    # 策略：如果内存大于 1G，给 1G Swap；否则给 512MB

    # 这一步尽量手动调整
    # 默认的设计哲学是，小内存机器的各项配置包括磁盘配置不会太高
    # 所以自然而然也不会跑高负载的服务，此时就不再需要过大的 Swap 了
    if [ $MEM_Total -lt 1024 ]; then
        SWAP_SIZE="512M"
    else
        SWAP_SIZE="1G"
    fi
    
    echo -e "\n${GREEN} ===> 检测到系统内存: ${MEM_Total} MB，准备创建 ${SWAP_SIZE} Swap... ${NC}"
    sleep 1s
    
    # fallocate 开始创建
    fallocate -l $SWAP_SIZE /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    sleep 1s
    echo -e "\n${GREEN} Swap 创建完成 ${NC}"
    echo -e "${GREEN} ===> Done. ${NC}"
    sleep 3s
fi
clear

# ===> 4. 配置 apt 源与基础软件
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... DONE √ "
echo -e " [2/$TOTAL_STEPS] 配置 TCP BBR... DONE √ "
echo -e " [3/$TOTAL_STEPS] 检查并配置 Swap... DONE √ "
echo -e " ===> [4/$TOTAL_STEPS] 正在更新 apt 源... "
sleep 1s

# 在开始前，先检查并修复可能中断的包管理器状态
echo -e "\n${GREEN} ===> 正在检查包管理器状态... ${NC}"
dpkg --configure -a || true
apt --fix-broken install -y || true
sleep 1s

# ===> 预定义获取服务器地区的逻辑
function check_network_region() {
    # 返回: "GLOBAL" 或 "CNMainLand" 或 "UNKNOWN" (无工具)
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 3 https://www.google.com > /dev/null; then
            echo "GLOBAL"
        else
            echo "CNMainLand"
        fi
    elif command -v wget &> /dev/null; then
        if wget -q --spider --timeout=3 https://www.google.com; then
            echo "GLOBAL"
        else
            echo "CNMainLand"
        fi
    else
        echo "UNKNOWN"
    fi
}

# ===> 预定义获取 apt 资源文件的逻辑
function get_apt_source_file() {
    # Ubuntu 24.04+ 使用 deb822 格式 /etc/apt/sources.list.d/ubuntu.sources
    # 旧版 Ubuntu/Debian 使用 /etc/apt/sources.list
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        SOURCE_FILE="/etc/apt/sources.list.d/ubuntu.sources"
    else
        SOURCE_FILE="/etc/apt/sources.list"
    fi
}

# ===> 预定义修改 apt 资源文件的逻辑
function change_apt_source() {
    local REGION=$1
    local SOURCE_FILE=$(get_source_file)

    # 备份原文件
    if [ ! -f "${SOURCE_FILE}.bak" ]; then
        cp "$SOURCE_FILE" "${SOURCE_FILE}.bak"
    fi
    
    # ===> 对于国内服务器，切换至 NJU 源
    if [ "$SERVER_LOCATION" = "CNMainLand" ]; then
        echo -e "\n${YELLOW} ===> 正在切换至南京大学 NJU 镜像源... ${NC}"

        if grep -q "Ubuntu" /etc/issue; then
            # Ubuntu 逻辑：替换 archive.ubuntu.com, security.ubuntu.com 等主流域名
            # deb822 格式虽然结构变了，但 URL 依然存在，sed 替换依然有效
            sed -i 's@http://.*archive.ubuntu.com@http://mirrors.nju.edu.cn@g' "$SOURCE_FILE"
            sed -i 's@http://.*security.ubuntu.com@http://mirrors.nju.edu.cn@g' "$SOURCE_FILE"
            sed -i 's@http://ports.ubuntu.com@http://mirrors.nju.edu.cn@g' "$SOURCE_FILE"
        elif grep -q "Debian" /etc/issue; then
            # Debian 逻辑：替换 deb.debian.org, security.debian.org
            sed -i 's@http://deb.debian.org@http://mirrors.nju.edu.cn@g' "$SOURCE_FILE"
            sed -i 's@http://security.debian.org@http://mirrors.nju.edu.cn@g' "$SOURCE_FILE"
        fi
    else
        # ===> 恢复/保持 默认源 (GLOBAL)
        # 如果当前文件已经被改过，即含有 nju.edu.cn，则恢复备份
        if grep -q "nju.edu.cn" "$SOURCE_FILE"; then
            echo -e "${GREEN} ===> 正在恢复至官方源... ${NC}"
            cp "${SOURCE_FILE}.bak" "$SOURCE_FILE"
        fi
    fi
}

# ===> 逻辑开始

# ===> 第一次确定地区
echo -e "\n${GREEN} ===> 正在确定服务器地区信息... (1/5) ${NC}"
sleep 1s
apt update -y
sleep 1s

if [ "$LOCATION" = "UNKNOWN" ]; then
    
    # 1. 强制切到 NJU HTTP 源 (无需证书即可连接)
    change_apt_source "CNMainLand"
    sleep 1s
    
    # 2. 更新并安装必备检测工具
    apt install -y curl wget
    sleep 1s
    
    # 3. 第二次确定地区，现在可以正常使用 wget 或者 curl 工具
    LOCATION=$(check_network_region)
    sleep 1s
    
    # 4. 根据真实结果修正源
    if [ "$LOCATION" = "GLOBAL" ]; then
        # 如果发现是海外机器，恢复默认源
        change_apt_source "GLOBAL"
    fi
else
    # 如果一开始就有工具，直接根据检测结果配置
    if [ "$LOCATION" = "CNMainLand" ]; then
        # ===> 对于国内服务器，切换至 NJU 源
        change_apt_source "CNMainLand"
        # ===> 对于海外服务器则无需换源
    fi
fi
echo -e "\n${GREEN} ===> Partly Done. (1/5) ${NC}"
sleep 1s
clear

# ===> 换源逻辑完成，开始切换至 HTTPS
echo -e "\n ===> apt 源将切换至 https 模式 (2/5) ${NC}"
sleep 1s

# 这一步对于 Ubuntu 24.04 有点特殊，它的源格式变了：/etc/apt/sources.list.d/ubuntu.sources
# 简单的 sed 替换在旧版有效，新版可能无效
# 对于自动化处理，建议主要依赖 install transport-https
apt install -y apt-transport-https ca-certificates
sleep 1s

# 如果是旧版 sources.list，尝试替换 http -> https
if [ -f /etc/apt/sources.list ]; then
    sed -i 's/http:/https:/g' /etc/apt/sources.list
fi
echo -e "\n${GREEN} ===> Partly Done. (2/5) ${NC}"
sleep 1s
clear

echo -e "\n${GREEN} ===> 正在更新软件包列表... (3/5) ${NC}"
apt update
echo -e "\n${GREEN} ===> Partly Done. (3/5) ${NC}"
sleep 1s
clear

echo -e "\n${GREEN} ===> 正在安装基础软件... (4/5) ${NC}"
# 安装基础软件
PACKAGES="sudo vim nano ufw bash curl wget htop qemu-guest-agent"

echo -e "\n${GREEN} 即将安装：$PACKAGES ${NC}"

# 直接卸载 needrestart，避免干扰运行
if dpkg -l | grep -q needrestart; then
    apt purge -y needrestart
fi

apt install -y $PACKAGES
echo -e "\n${GREEN} ===> Partly Done. (4/5) ${NC}"
sleep 1s
clear

echo -e "\n${GREEN} ===> 正在更新系统及软件... (5/5) ${NC}"
apt upgrade -y
echo -e "\n${GREEN} 系统更新完毕 ${NC}"
echo -e "\n${GREEN} ===> Done. (5/5) ${NC}"
sleep 3s
clear

# ===> 5. 配置 ufw 防火墙
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... DONE √ "
echo -e " [2/$TOTAL_STEPS] 配置 TCP BBR... DONE √ "
echo -e " [3/$TOTAL_STEPS] 检查并配置 Swap... DONE √ "
echo -e " [4/$TOTAL_STEPS] 正在更新 apt 源... DONE √ "
echo -e " ===> [5/$TOTAL_STEPS] 配置 ufw 防火墙... ${NC}"

# 设置默认策略：拒绝入站，允许出站
ufw default deny incoming
ufw default allow outgoing

# 放行 SSH 端口
ufw allow OpenSSH || ufw allow ssh
# 一些情况下写数字更明确，但是为了避免更换端口导致无法放行，这里改为 ssh

# 放行常用 Web 端口
ufw allow 80/tcp
ufw allow 443/tcp

# 启用防火墙
# 使用 --force 参数来避免 "Command may disrupt existing ssh connections" 的交互式确认
echo "\n${GREEN} ===> 正在启用 ufw 防火墙... ${NC}"
ufw --force enable

# 显示状态
ufw status verbose
echo -e "\n${GREEN} ufw 已配置并启动 ${NC}"
echo -e "${GREEN} ===> Done. ${NC}"
sleep 3s
clear

# ===> 6. 交互式选择安全放爆破组件
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... DONE √ "
echo -e " [2/$TOTAL_STEPS] 配置 TCP BBR... DONE √ "
echo -e " [3/$TOTAL_STEPS] 检查并配置 Swap... DONE √ "
echo -e " [4/$TOTAL_STEPS] 正在更新 apt 源... DONE √ "
echo -e " [5/$TOTAL_STEPS] 配置 ufw 防火墙... DONE √ "
echo -e " ===> [6/$TOTAL_STEPS] 配置安全组件... ${NC}"
sleep 1s
echo -e "\n${RED} 选择要安装的安全防护工具： \n${NC}"
echo -e "${GREEN} 1) ${NC} Fail2ban (${GREEN} 默认 ${NC} - 功能强大，日志清晰，但负载占用稍高) "
echo -e "${GREEN} 2) ${NC} SSHGuard (更加轻量，资源占用更低) "
echo -ne "\n${RED} 请输入选项 [1/2] : ${NC}"

# 从 tty 读取输入
read -r SECURITY_CHOICE < /dev/tty

# 逻辑判断：只有输入 2 才安装 SSHGuard，其他情况直接安装 Fail2ban
if [[ "$SECURITY_CHOICE" == "2" ]]; then
    # 选项 B: SSHGuard 
    echo -e "\n${GREEN} ===> 已选择: SSHGuard (轻量级方案) ${NC}"
    INSTALLED_SECURITY_TOOL="SSHGuard"
    
    # 开始安装
    if ! command -v sshguard &> /dev/null; then
        apt install -y sshguard
    fi

    # 配置白名单
    # SSHGuard 默认配置较少，主要靠白名单防止误封
    # 首先创建配置目录。有的发行版可能不一样，这里做个保险
    mkdir -p /etc/sshguard
    WHITELIST_FILE="/etc/sshguard/whitelist"
    
    # 如果文件不存在则创建它
    if [ ! -f "$WHITELIST_FILE" ]; then
        touch "$WHITELIST_FILE"
    fi
    
    # 追加写入白名单，防止覆盖
    if ! grep -q "127.0.0.1" "$WHITELIST_FILE"; then
        echo "127.0.0.1" >> "$WHITELIST_FILE"
        echo "::1" >> "$WHITELIST_FILE"
    fi
    sleep 1s

    # 重启服务
    systemctl restart sshguard
    systemctl enable sshguard
    echo -e "\n${GREEN} ===> SSHGuard 已启动 ${NC}"

else
    # 选项 A: Fail2ban (默认) 
    echo -e "\n${GREEN} ===> 已选择: Fail2ban (默认方案) ${NC}"
    INSTALLED_SECURITY_TOOL="Fail2ban"
    
    # 开始安装
    if ! command -v fail2ban-client &> /dev/null; then
        apt install -y fail2ban
    fi

    # 配置 jail.local ，覆盖默认配置
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime  = 86400
findtime = 600
maxretry = 5
backend  = systemd

[sshd]
enabled = true
port    = ssh
mode    = normal
EOF
    # Debian/Ubuntu 现代版通常不需要指定 logpath，会自动监测 systemd journal
    # 但显式指定 backend 为 systemd 更稳妥

    sleep 1s
    # 重启服务
    systemctl restart fail2ban
    systemctl enable fail2ban
    echo -e "\n${GREEN} ===> Fail2ban 已启动 "
    echo -e "${GREEN} 防护策略: 10 分钟错误 5 次 → 封禁 24 小时 ${NC}"
fi
echo -e "\n${GREEN} ===> Done. ${NC}"
sleep 3s
clear

# ===> 7. 系统内核更新
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... DONE √ "
echo -e " [2/$TOTAL_STEPS] 配置 TCP BBR... DONE √ "
echo -e " [3/$TOTAL_STEPS] 检查并配置 Swap... DONE √ "
echo -e " [4/$TOTAL_STEPS] 正在更新 apt 源... DONE √ "
echo -e " [5/$TOTAL_STEPS] 配置 ufw 防火墙... DONE √ "
echo -e " [6/$TOTAL_STEPS] 配置安全组件... DONE √ "
echo -e " ===> [7/$TOTAL_STEPS] 检查内核更新... ${NC}"
KERNEL_VERSION=$(uname -r)
echo -e "\n${GREEN} 当前内核: $KERNEL_VERSION ${NC}" 
sleep 1s

# 判断是否为云厂商专用内核 (Azure, GCP, AWS, Oracle)
if [[ "$KERNEL_VERSION" == *"azure"* ]] || \
   [[ "$KERNEL_VERSION" == *"gcp"* ]] || \
   [[ "$KERNEL_VERSION" == *"aws"* ]] || \
   [[ "$KERNEL_VERSION" == *"uek"* ]] || \
   [[ "$KERNEL_VERSION" == *"oracle"* ]]; then
    echo -e "\n${GREEN} 检测到专用内核，已跳过安装步骤 ${NC}"
    sleep 1s
else
    echo -e "\n${GREEN} ===> 检测到通用 Linux 内核，正在准备内核更新... ${NC}"
    sleep 1s
    # 仅在 Ubuntu 下尝试安装 HWE
    if grep -q "Ubuntu" /etc/issue; then
        apt install -y --install-recommends linux-generic-hwe-$(lsb_release -rs) || echo -e "${GREEN} HWE 安装跳过或已是最新 ${NC}"
    else
        echo -e "\n${GREEN} ===> 正在执行内核升级... ${NC}"
        apt upgrade -y linux-image-amd64 || true
    fi
    update-grub
    sleep 1s
    echo -e "\n${GREEN} ===> Done. ${NC}"
    sleep 3s
fi
clear

# ===> 8. 移除 Snap (对于 Ubuntu)
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... DONE √ "
echo -e " [2/$TOTAL_STEPS] 配置 TCP BBR... DONE √ "
echo -e " [3/$TOTAL_STEPS] 检查并配置 Swap... DONE √ "
echo -e " [4/$TOTAL_STEPS] 正在更新 apt 源... DONE √ "
echo -e " [5/$TOTAL_STEPS] 配置 ufw 防火墙... DONE √ "
echo -e " [6/$TOTAL_STEPS] 配置安全组件... DONE √ "
echo -e " [7/$TOTAL_STEPS] 检查内核更新... DONE √ ${NC}"
if grep -q "Ubuntu" /etc/issue; then
    echo -e "\n${GREEN} ===> [8/$TOTAL_STEPS] 处理 Snap... ${NC}"
    if command -v snap &> /dev/null; then
        echo -e "\n${GREEN} 检测到 Snap，正在移除... ${NC}"
        sleep 1s
        # 彻底移除 snap 需要一点耐心
        systemctl stop snapd.service || true
        systemctl stop snapd.socket || true
        apt purge snapd -y
        rm -rf /root/snap /snap /var/snap /var/lib/snapd
        sleep 1s
        apt-mark hold snap
        echo -e "\n${GREEN} ===> Snap 已移除并锁定 ${NC}"
        echo -e "${GREEN} ===> Done. ${NC}"
        sleep 3s
    else
        echo -e "\n${GREEN} Snap 未安装，跳过当前步骤 ${NC}"
        sleep 1s
    fi
else
    echo -e "${GREEN} ===> [8/$TOTAL_STEPS] 非 Ubuntu 系统，跳过 Snap 清理步骤 ${NC}"
    sleep 1s
fi
clear

# ===> 9. 磁盘空间优化
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... DONE √ "
echo -e " [2/$TOTAL_STEPS] 配置 TCP BBR... DONE √ "
echo -e " [3/$TOTAL_STEPS] 检查并配置 Swap... DONE √ "
echo -e " [4/$TOTAL_STEPS] 正在更新 apt 源... DONE √ "
echo -e " [5/$TOTAL_STEPS] 配置 ufw 防火墙... DONE √ "
echo -e " [6/$TOTAL_STEPS] 配置安全组件... DONE √ "
echo -e " [7/$TOTAL_STEPS] 检查内核更新... DONE √ "
echo -e " [8/$TOTAL_STEPS] 处理 Snap... DONE √ "
echo -e " ===> [9/$TOTAL_STEPS] 磁盘空间优化... ${NC}"
# 只有 ext4 文件系统支持 tune2fs，执行前需要判断。
ROOT_FS=$(df -T / | awk 'NR==2 {print $2}')
if [ "$ROOT_FS" == "ext4" ]; then
    # 获取根目录分区名
    ROOT_DEV=$(findmnt / -o SOURCE -n)
    # 建议留 1% 给 root 救急，改成 0 有极端风险
    tune2fs -m 1 "$ROOT_DEV" 
    echo -e "\n${GREEN} ===> 已将 $ROOT_DEV 的保留空间调整为 1% ${NC}"
    echo -e "${GREEN} ===> Done. ${NC}"
    sleep 3s
else
    echo -e "\n${GREEN} 根文件系统为 $ROOT_FS，跳过 tune2fs 优化 ${NC}"
    sleep 1s
fi
clear

# ===> 10. 安装增强性组件
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... DONE √ "
echo -e " [2/$TOTAL_STEPS] 配置 TCP BBR... DONE √ "
echo -e " [3/$TOTAL_STEPS] 检查并配置 Swap... DONE √ "
echo -e " [4/$TOTAL_STEPS] 正在更新 apt 源... DONE √ "
echo -e " [5/$TOTAL_STEPS] 配置 ufw 防火墙... DONE √ "
echo -e " [6/$TOTAL_STEPS] 配置安全组件... DONE √ "
echo -e " [7/$TOTAL_STEPS] 检查内核更新... DONE √ "
echo -e " [8/$TOTAL_STEPS] 处理 Snap... DONE √ "
echo -e " [9/$TOTAL_STEPS] 磁盘空间优化... DONE √ "
echo -e " ===> [10/$TOTAL_STEPS] 安装增强性组件... ${NC}"
sleep 1s

echo -e "${GREEN} 服务器面板/ Docker 环境安装 ${NC}"

echo -e "\n${RED} 请选择要安装的面板： \n${NC}"
echo -e "${GREEN} A) 宝塔面板${NC} - 最新版 (v11.4.0) "
echo -e "${GREEN} B) 宝塔面板${NC} - 稳定版 (v10.0) "
echo -e "${GREEN} C) aaPanel${NC} - 宝塔国际版 (v7.0.28) (English Only) "
echo -e "${GREEN} D) 1Panel${NC} - 容器化面板 (自带 Docker) "
echo -e "${GREEN} E)${NC} 跳过面板安装步骤 "
echo -ne "\n${RED} 请输入选项 [A-E]: ${NC}"
read -r PANEL_CHOICE < /dev/tty

# ===> 要求用户保存面板登录信息
function wait_for_ok() {
    echo -e "\n${RED} ===> 关键信息确认： ${NC}"
    echo -e "${RED} 请务必保存上方的面板登录信息 ${NC}"
    while true; do
        echo -ne "\n${RED} ===> 输入 'ok' 以继续... (Type 'ok' to continue): ${NC}"
        # 强制从终端读取，防止管道干扰
        read -r CONFIRM < /dev/tty
        if [[ "$CONFIRM" == "ok" ]] || [[ "$CONFIRM" == "OK" ]]; then
            echo -e "\n${GREEN} ===> 确认成功，继续执行... ${NC}"
            break
        else
            echo -e "\n${RED} ===> 输入 'ok' 以继续... (Type 'ok' to continue): ${NC}"
        fi
    done
}

# ===> 预定义 Docker 安装步骤
function install_docker() {
    echo -e "\n${GREEN} ===>  正在检查 Docker 安装条件... ${NC}"
    
    # 读取系统信息
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        # 极老系统的 fallback
        ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
        VERSION_ID=$(lsb_release -rs)
    fi
    
    local SKIP_DOCKER_INSTALL=false

    # 版本号检查
    # Ubuntu 22.04 +
    if [[ "$ID" == "ubuntu" ]]; then
        if [[ "$VERSION_ID" < "22.00" ]]; then
            echo -e "\n${RED} 错误: 当前为 Ubuntu $VERSION_ID，Docker 官方脚本仅支持 22.04+ "
            echo -e " 请使用其他途径自行安装 Docker ${NC}"
            SKIP_DOCKER_INSTALL=true
            sleep 3s
        fi
    # Debian 11 +
    elif [[ "$ID" == "debian" ]]; then
        local DEB_MAIN=$(echo "$VERSION_ID" | cut -d. -f1)
        if [[ "$DEB_MAIN" -lt 11 ]]; then
            echo -e "\n${RED} 错误: 当前为 Debian $VERSION_ID，Docker 官方脚本仅支持 11+ "
            echo -e " 请使用其他途径自行安装 Docker ${NC}"
            SKIP_DOCKER_INSTALL=true
            sleep 3s
        fi
    fi
    sleep 1s

    # 如果不满足条件，直接跳过
    if [ "$SKIP_DOCKER_INSTALL" = true ]; then
        echo -e "\n${RED}  ===> 为了系统安全，已自动跳过 Docker 安装 ${NC}"
        INSTALLED_DOCKER="否 (系统版本过低)"
        sleep 3
        # 直接退出
        return 
    fi

    echo -e "\n${GREEN} ===> 正在执行 Docker 安装... ${NC}"
    # 下载脚本并重命名为 get-docker.sh 以方便清理
    curl -fsSL https://get.docker.com -o get-docker.sh
    case "$SERVER_LOCATION" in
    "GLOBAL")
        bash get-docker.sh
        ;;

    "CNMainLand")
        bash get-docker.sh --mirror Aliyun
        ;;

    *)
        echo " 未知的服务器位置: $SERVER_LOCATION "
        bash get-docker.sh
        ;;
    esac

}

# ===> 开始面板安装逻辑
case $PANEL_CHOICE in
# 面板安装脚本将统一命名为 install_panel.sh 方便清理
    [aA])
    # https://www.bt.cn/new/download.html
        echo -e "\n${GREEN} ===> 安装宝塔最新版... "
        echo -e " 请先根据安装脚本提示就行操作... ${NC}"
        wget -O install_panel.sh https://download.bt.cn/install/install_panel.sh
        bash install_panel.sh ssl251104
        INSTALLED_PANEL=" 宝塔面板 - 最新版 "
        NEED_DOCKER_ASK=true
        ;;

    [bB])
    # https://www.bt.cn/new/download.html
        echo -e "\n${GREEN} ===> 安装宝塔稳定版... "
        echo -e " 请先根据安装脚本提示就行操作... ${NC}"
        sleep 3s
        wget -O install_panel.sh https://download.bt.cn/install/installStable.sh
        bash install_panel.sh ed8484bec
        INSTALLED_PANEL=" 宝塔面板 - 稳定版 v10.0 "
        NEED_DOCKER_ASK=true
        ;;

    [cC])
    # https://www.bt.cn/new/download.html
        echo -e "\n${GREEN} ===> 安装宝塔国际版 aaPanel ... "
        echo -e " 请先根据安装脚本提示就行操作... ${NC}"
        sleep 3s
        wget --no-check-certificate -O install_panel.sh https://www.aapanel.com/script/install_7.0_en.sh
        bash install_panel.sh aapanel
        INSTALLED_PANEL=" aaPanel v7.0.28 "
        NEED_DOCKER_ASK=true
        ;;

    [dD])
    # https://1panel.cn/#quickstart
        echo -e "\n${GREEN} ===> 安装 1Panel ... "
        echo -e " 请先根据安装脚本提示就行操作，并直接安装 Docker... ${NC}"
        echo -e "${RED} 请注意，后续步骤中将不再单独安装 Docker ${NC}"
        sleep 3s
        wget -O install_panel.sh https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh
        bash install_panel.sh
        INSTALLED_PANEL=" 1Panel "
        INSTALLED_DOCKER="是 (包含于 1Panel)"
        NEED_DOCKER_ASK=false
        
        # 对于 1Panel，直接确认保存登录信息
        echo -e "\n${GREEN} ===> Done. ${NC}"
        wait_for_ok
        sleep 3s
        ;;

    *)
        echo -e "\n${GREEN} 已跳过面板安装 ${NC}"
        NEED_DOCKER_ASK=true
        ;;
esac

# ===> 宝塔/aaPanel 后续逻辑
if [ "$NEED_DOCKER_ASK" = true ]; then
    # 确认保存登录信息
    echo -e "\n${GREEN} ===> Partly Done. (1/2) ${NC}"
    wait_for_ok
    sleep 1s

    echo -e "\n${RED} ===> 是否安装 Docker 环境? [Y/n] ${NC}"
    read -r DOCKER_CONFIRM < /dev/tty
    if [[ "$DOCKER_CONFIRM" =~ ^[Yy]$ ]] || [[ -z "$DOCKER_CONFIRM" ]]; then
        sleep 1s
        install_docker
        echo -e "\n${GREEN} ===> Done. ${NC}"
        
        # 用 ufw 强制关掉不安全的端口
        echo -e "\n${RED} ===> 正在加固 ufw 防火墙... ${NC}"
        ufw delete allow 20/tcp >/dev/null 2>&1 || true
        ufw delete allow 21/tcp >/dev/null 2>&1 || true
        ufw delete allow 888/tcp >/dev/null 2>&1 || true
        ufw reload
    fi
fi
sleep 3s

# ===> 读取 Docker 版本信息
if command -v docker &> /dev/null; then
    # 提取 Docker 版本 (例如: 24.0.7)
    # docker --version 输出通常是 "Docker version 24.0.7, build ..."
    D_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    
    # 提取 Compose 版本 (例如: v2.21.0)
    # docker compose version 输出通常是 "Docker Compose version v2.21.0"
    C_VER=$(docker compose version 2>/dev/null | awk '{print $4}')
    
    # 如果没取到 Compose 版本 比如旧版，则标记一下
    if [[ -z "$C_VER" ]]; then C_VER="Unknown"; fi
    
    # 更新变量，让总结更漂亮
    INSTALLED_DOCKER="${GREEN} 运行中 ：Docker $D_VER + Compose $C_VER ${NC}"
elif [[ "$INSTALLED_DOCKER" == "否"* ]]; then
    # 保持原样，什么都不做
    :
else
    # 比如安装失败了
    INSTALLED_DOCKER="${RED} 未检测到命令 (安装可能失败) ${NC}"
fi
sleep 3
clear

# ===> 清理缓存
echo -e "\n${GREEN} ===> 开始清理... ${NC}"
sleep 1s

# 清理 apt 缓存
apt update
apt autoremove --purge -y
apt clean
echo -e "\n${GREEN} ===> Partly Done. (1/4) ${NC}"
sleep 1s

# 清理增强组件缓存
rm -f install_panel.sh get-docker.sh
# 清理 1Panel 安装残留的目录和压缩包
rm -rf 1panel-v* 1panel-v*.tar.gz
# 清理 VPS 初始化的遗留日志
rm -f virt-sysprep-firstboot.log

echo -e "\n${GREEN} ===> Partly Done. (2/4) ${NC}"
sleep 1s

# ===> 采集基本系统信息，为总结做准备

# CPU 型号 (提取第一行 model name)
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | awk -F: '{print $2}' | sed 's/^[ \t]*//')

# 内存使用 (已用/总计)
MEM_USAGE=$(free -h | awk '/Mem:/ {print $3 "/" $2}')

# Swap 使用 (已用/总计)
SWAP_USAGE=$(free -h | awk '/Swap:/ {print $3 "/" $2}')

# 磁盘使用 (根目录 / 的占用)
DISK_USAGE=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')

# 系统信息
if [ -f /etc/os-release ]; then
    . /etc/os-release
    SYSTEM_INFO="$PRETTY_NAME"
else
    SYSTEM_INFO="Unknown Linux"
fi

# 内核版本
KERNEL_VER=$(uname -r)

# 公网 IP 
PUBLIC_IP=$(curl -s --max-time 3 https://api.ip.sb/ip -A Mozilla || echo "获取失败")

# 完成
echo -e "\n${GREEN} ===> Partly Done. (3/4) ${NC}"
sleep 1s

# 下载后续文件
if [ "$SERVER_LOCATION" = "GLOBAL" ]; then
    DOWNLOAD_DOMAIN=https://raw.githubusercontent.com/yhxpie/server-init
    curl -fLO $DOWNLOAD_DOMAIN/main/init2.sh || wget -O init2.sh $DOWNLOAD_DOMAIN/main/init2.sh
    curl -fLO $DOWNLOAD_DOMAIN/main/init-clean.sh || wget -O init-clean.sh $DOWNLOAD_DOMAIN/main/init-clean.sh
    curl -fLO $DOWNLOAD_DOMAIN/main/SSH_GUIDE.md || wget -O SSH_GUIDE.md $DOWNLOAD_DOMAIN/main/SSH_GUIDE.md
else
    DOWNLOAD_DOMAIN=https://yhxpie.netlify.app/server-init
    curl -fLO $DOWNLOAD_DOMAIN/main/init2.sh || wget -O init2.sh $DOWNLOAD_DOMAIN/main/init2.sh
    curl -fLO $DOWNLOAD_DOMAIN/main/init-clean.sh || wget -O init-clean.sh $DOWNLOAD_DOMAIN/main/init-clean.sh
    curl -fLO $DOWNLOAD_DOMAIN/main/SSH_GUIDE.md|| wget -O SSH_GUIDE.md $DOWNLOAD_DOMAIN/main/SSH_GUIDE.md
fi
sleep 1s

# 完成
echo -e "${GREEN} ===> Done. (4/4) ${NC}"
sleep 3s

clear

# ===> 完成总结
echo -e "\n${GREEN} ============================================= ${NC}"
echo -e "${GREEN}                系统初始化摘要 ${NC}"
echo -e "${GREEN} ============================================= ${NC}"
sleep 1s
echo -e " [1/$TOTAL_STEPS] 时区设置      : ${GREEN} Asia/Shanghai √ ${NC}"
echo -e " [2/$TOTAL_STEPS] TCP BBR       : ${GREEN} 已启用 √ ${NC}"
echo -e " [3/$TOTAL_STEPS] Swap 交换分区 : ${GREEN} 已配置 √ ${NC}"
echo -e " [4/$TOTAL_STEPS] APT 源与更新  : ${GREEN} 完成 √ ${NC}"
echo -e " [5/$TOTAL_STEPS] ufw 防火墙    : ${GREEN} 就绪 √ ${NC}"
echo -e " [6/$TOTAL_STEPS] 安全防护组件  : ${GREEN} 已安装 $INSTALLED_SECURITY_TOOL √ ${NC}"
echo -e " [7/$TOTAL_STEPS] 内核检查      : ${GREEN} 完成 √ ${NC}"
echo -e " [8/$TOTAL_STEPS] Snap 处理     : ${GREEN} 已清理 √ ${NC}"
echo -e " [9/$TOTAL_STEPS] 磁盘空间优化  : ${GREEN} 完成 √ ${NC}"

# 增强组件相关信息
echo -e " [10/$TOTAL_STEPS] 增强组件信息： "
echo -e " 面板环境     : ${GREEN} $INSTALLED_PANEL ${NC}"
echo -e " Docker 环境  : ${GREEN} $INSTALLED_DOCKER ${NC}"

echo " Please wait... "
sleep 3s

echo -e "\n${GREEN} ============================================= ${NC}"
echo -e "${GREEN}               系统状态信息检查 ${NC}"
echo -e "${GREEN} ============================================= ${NC}"
sleep 1s
echo -e "${GREEN} CPU 信息 ${NC}     : ${CPU_MODEL} "
echo -e "${GREEN} 内存占用 ${NC}     : ${MEM_USAGE} "
echo -e "${GREEN} Swap 占用 ${NC}    : ${SWAP_USAGE} "
echo -e "${GREEN} 磁盘空间占用 ${NC} : ${DISK_USAGE} "
echo -e "${GREEN} 系统信息 ${NC}     : ${SYSTEM_INFO} "
echo -e "${GREEN} 内核版本 ${NC}     : ${KERNEL_VER} "
echo -e "${GREEN} 公网 IP 信息 ${NC} : ${PUBLIC_IP} "

echo " Please wait... "
sleep 3s

echo -e "\n${RED} ===> 后续操作提示 <=== ${NC}"
echo -e "${GREEN} 要运行用户配置脚本，请使用命令：'sudo bash init2.sh' \n${NC} "
echo -e "${GREEN} 要查看有关如何创建 SSH 密钥的帮助，请使用命令：'sudo bash init2.sh' \n${NC} "

# 添加控制台提示信息
cat >> /root/.bashrc << 'EOF'

# [Server-init] Stage 2 Reminder
if [ -f /root/init2.sh ]; then
    echo -e "\033[0;31m=================================================\033[0m"
    echo -e "\033[1;33m 系统初始化 Stage 2 尚未执行 \033[0m"
    echo -e "\033[1;32m 请在 root 下输入 'sudo bash init2.sh' \033[0m"
    echo -e "\033[1;32m 以继续进行内核清理与用户配置 \033[0m"
    echo
    echo -e "\033[1;32m 有关如何创建 SSH 密钥的帮助， \033[0m"
    echo -e "\033[1;32m 请输入 'cat SSH_GUIDE.md' \033[0m"
    echo
    echo -e "\033[1;32m 如果无需进行后续操作 \033[0m"
    echo -e "\033[1;32m 请在 root 下输入 'sudo bash init-clean.sh' \033[0m"
    echo -e "\033[0;31m=================================================\033[0m"
fi
EOF

# 自行清理
if [ -f "$0" ]; then
    rm -f "$0"
    echo " init.sh 脚本清理已完成 "
fi

echo -e "\n${GREEN}=============================================${NC}"
echo -e "\n${RED} ===> 由于更新了内核，即将重启系统 "
sleep 3s
echo -e "\n${GREEN} ===> 正在重启... SSH 将断开连接 ${NC}"
echo -e "${RED} 涉及内核更新后的重启可能需要更多时间 ${NC}"
echo -e "${GREEN} 可以在 VNC 等控制台查看详细信息 \n${NC}"

sleep 1s

echo -e "\n  ____________________________ "
echo -e " | GitHub: yhxpie/server-init | \n"

sleep 3s
reboot

# Done.