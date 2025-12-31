#!/bin/bash

# init-clean.sh

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

# ===> 基础设置与检查
# 遇到错误立即停止
set -e

# 颜色定义
GREEN='\033[0;32m'

# 直接执行最终清理
echo -e "${GREEN} ===> 正在执行最终清理 ... ${NC}"
sleep 1s

# 使用 sed 移除 .bashrc 里提示标记
sed -i '/# \[Server-init\] Stage 2 Reminder/,/fi/d' /root/.bashrc
echo -e "\n${GREEN} ===> Partly Done. (1/3) ${NC}"
sleep 1s

# 删除多余脚本
rm init2.sh SSH_GUIDE.md init.sh || true
echo -e "\n${GREEN} ===> Partly Done. (2/3) ${NC}"
sleep 1s

# apt 缓存清理
apt autoremove -y --purge
apt clean
echo -e "\n${GREEN} ===> Done. (/3) ${NC}"
sleep 3s

clear

echo -e "\n${GREEN} =============================================${NC}"
echo -e "${GREEN}                系统初始化全部完成 ${NC}"
echo -e "${GREEN} =============================================\n${NC}"
sleep 1s

# 自行清理
if [ -f "$0" ]; then
    rm -f "$0"
    echo " init-clean.sh 脚本清理已完成 "
fi

sleep 1s

echo -e "\n  ____________________________ "
echo -e " | GitHub: yhxpie/server-init | \n"

# Done.

# GitHub: @yhxpie
# https://github.com/yhxpie/server-init
# Version 1.0.4
# Last Update: 2025-12-31
