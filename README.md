# server-init for Debian / Ubuntu

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Bash](https://img.shields.io/badge/Language-Bash-blue.svg)]()
[![OS](https://img.shields.io/badge/OS-Debian%20%7C%20Ubuntu-orange)]()

一个适用于 Debian / Ubuntu 服务器的自动化初始化脚本套件，
包含系统基础配置、安全加固、内核升级、面板安装以及 Docker 环境部署等功能。

> [!IMPORTANT]
> 最低系统要求：
> **Debian 11**
> &
> **Ubuntu 22.04 LTS**

> [!CAUTION]
> 项目名称为 `server-init` ，即只主动适配服务器系统，一些功能；理论上支持桌面端系统，但仍然不建议桌面端系统使用
>
> 例如脚本会清除 Snap，这会导致桌面端的 Ubuntu Software 出现问题
---

## 如何使用

> [!CAUTION]
> 仅建议在全新安装完成的系统环境下使用

### 第一步：`init.sh` 基础配置

> [!IMPORTANT]
> 非常建议提前安装 `curl`，虽然较新的 Minimal 系统中应该都会自带这一命令
>
> 如果没有，请使用命令：
> ```
> apt install curl
> ```

**使用 root 用户运行以下命令：**

国外服务器：

```bash
curl -O https://raw.githubusercontent.com/yhxpie/server-init/main/init.sh || wget -O ${_##*/} $_ && bash init.sh
```
国内服务器：

```bash
curl -O https://yhxpie-server-init.netlify.app/init.sh || wget -O ${_##*/} $_ && bash init.sh
```
> [!TIP]
> 对于某些 Minimal 系统如果没有安装 wget，则可以使用 curl | bash 尝试：
> 
> **国外服务器：**
> ```bash
> curl -sS https://raw.githubusercontent.com/yhxpie/server-init/main/init.sh | bash
> ```
> 
> **国内服务器：**
> ```bash
> curl -sS https://yhxpie-server-init.netlify.app/init.sh | bash
> ```

> [!WARNING]
> 脚本执行完毕后，系统将强制重启以应用新内核。

### 第二步：配置用户与清理

**重启完成后请重新连接终端。**
此时会看到终端中有相应提示。

- 方案 A：完成配置（推荐）输入以下命令，进行 SSH 密钥配置和旧内核清理：
```bash
sudo bash init2.sh
```

- 方案 B：跳过配置。如果测试环境下不需要配置用户密钥，则输入以下命令清理残留文件：
```bash
sudo bash init-clean.sh
```

`init-clean.sh` 仅删除控制台消息并删除所有残余内容，如果是仅测试环境，也可以不执行。

- - -

## 功能特性

分为 Stage 1 & Stage 2，旨在实现“开箱即用”的最佳实践配置。

### Stage 1: `init.sh`：服务器基础配置

- **基础设置**：
  - 设置时区为 `Asia/Shanghai`，开启 NTP 时间同步
- **智能源配置**：
  - 自动检测服务器地区，大陆地区自动切换至南京大学 NJU 镜像源
  - 将更新源从 HTTP 切换为 HTTPS
- **网络优化**：
  - 开启 TCP BBR 拥塞控制算法
- **安全防护**：
  - 配置 UFW 防火墙
  - 提供 **Fail2ban** 或 **SSHGuard** 防暴力破解组件
- **内核升级**：
  - 自动更新系统内核
  - Ubuntu 支持更新至 HWE 硬件增强堆栈内核
- **系统清理优化**：
  - Ubuntu 卸载 Snap
  - 释放 ext4 预留磁盘空间至 1%
- **环境部署 (可选)**：
  - 安装 Docker CE & Docker Compose，自动匹配国内/官方源
  - 安装服务器面板：
    - 宝塔面板：最新版/稳定版
    - aaPanel (宝塔国际版) (English Only)
    - 1Panel
   
> [!IMPORTANT]
> 在国际环境中安装 **中文版宝塔面板** 的速度较慢，安装过程中请耐心等待
> 
> 同样地，在国内环境中安装 **aaPanel** 的速度也会较慢

> [!IMPORTANT]
> 脚本不保存任何安装文件，面板的所有文件全部从官方服务器直接获取
>
> 面板安装同步的版本号会有几天的延迟，可以在面板安装完成后进行更新

### Stage 2: `init2.sh`：进阶配置

> [!WARNING]
> `init2.sh` 或者 `init-clean.sh` 请务必在系统重启后执行

- **SSH 安全加固**：
  - 强制清理 SSH Drop-in 干扰配置
  - 配置 SSH 密钥登录，**禁用密码登录**。
  - 禁用 Root 密码登录，同样仅允许密钥
- **用户管理**：
  -  创建 sudo 免密用户并同步公钥
- **深度清理**：
  - 精准识别并移除旧版本内核
  - 移除无用依赖与残留配置文件

---

## 兼容性：

> [!WARNING]
> 标准版内置版本检测，不支持过旧的系统运行。
> **对于列表中未列出的系统，请转到。**
- ✅ = 支持所有功能
- ⚠️ = 需要注意
- ❌ = 无法提供支持

### Ubuntu <img width="16" height="16" src="https://documentation.ubuntu.com/server/_static/favicon.png" /> 

| OS Version | Status | init.sh | init2.sh |
| :----- | :-----: | :-----: | :-----: |
| 25.10 (Questing Quokka) | Verifed | ✅ | ✅ |
| 25.04 (Plucky Puffin) | Verifed | ✅ | ✅ |
| 24.04 LTS (Noble Numbat) | Verifed | ✅ | ✅ |
| 22.04 LTS (Jammy Jellyfish) | Verifed | ✅ | ✅ |
| 20.04 LTS (Focal Fossa) | ❌ | ⚠️ Docker 无法安装 |  |
| 18.04 LTS (Bionic Beaver) | ❌ | ⚠️ Docker 无法安装 |  |
| 16.04 LTS (Xenial Xerus) | ❌ | ⚠️ Docker 无法安装 |  |
| 14.04 LTS (Trusty Tahr) | ❌ | ⚠️ Docker 无法安装 |  |

### Debian <img width="16" height="16" src="https://www.debian.org/favicon.ico" />

| OS Version | Status | init.sh | init2.sh |
| :----- | :-----: | :-----: | :-----: |
| 13 Testing (Trixie) | Verifed | ✅ | ✅ |
| 12 (Bookworm) | Verifed | ✅ | ✅ |
| 11 (Bullseye) | Verifed | ✅ | ✅ |
| 10 (Buster) |  |  |  |

## 免责声明

1. 建议在新安装完成的**官方原版纯净系统**上运行
2. 请务必在执行 Stage 2 前自行保存好您的 SSH 公私钥

不建议在生产环境运行。作者不对因脚本执行导致的任何数据丢失或系统故障负责。

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
