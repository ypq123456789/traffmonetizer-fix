#!/bin/bash

# =================================================================
# 脚本名称: deploy_tm.sh
# 功能: Traffmonetizer LXC/NAT VPS 通用修复部署脚本 (支持 x86_64 & ARM64)
# 特性: 增加对无 Systemd 容器 (LXC/Docker/Alpine) 的 OpenRC 及 Crontab 兜底支持
# 项目地址: https://github.com/ypq123456789/traffmonetizer-fix
# =================================================================

TOKEN=$1

if [ -z "$TOKEN" ]; then
    echo "❌ 错误: 请提供 Token 参数。"
    echo "用法: sudo bash $0 <你的Token>"
    exit 1
fi

SERVICE_NAME="traffmonetizer"
BIN_PATH="/usr/local/bin/tm_cli"
REPO_URL="https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/tm_cli"

# --- [1] 架构检测与依赖配置 ---
ARCH=$(uname -m)
echo "--- 正在检测系统架构: $ARCH ---"

if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    echo "✅ 检测到 x86_64 架构，将使用原生模式运行。"
    EXEC_CMD="${BIN_PATH}"
    
    # 仅安装基础依赖
    if ! command -v curl >/dev/null 2>&1 || ! command -v ps >/dev/null 2>&1; then
        echo "正在安装基础依赖 (curl, procps)..."
        if command -v apt-get >/dev/null 2>&1; then apt-get update -y && apt-get install -y curl procps cron
        elif command -v yum >/dev/null 2>&1; then yum install -y curl procps cronie
        elif command -v apk >/dev/null 2>&1; then apk update && apk add curl procps dcron
        fi
    fi

elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "⚠️ 检测到 ARM64 架构，将自动启用 QEMU 跨架构转译模式！"
    
    # 安装基础依赖和 QEMU
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y curl procps cron qemu-user-static
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl procps cronie epel-release && yum install -y qemu-user-static
    elif command -v apk >/dev/null 2>&1; then
        apk update && apk add curl procps dcron qemu-aarch64 qemu-x86_64
    else
        echo "❌ 无法自动安装 qemu-user-static，请手动安装后重试。"
        exit 1
    fi

    # 检查 QEMU 命令是否就绪
    QEMU_BIN=$(command -v qemu-x86_64-static || command -v qemu-x86_64)
    if [ -z "$QEMU_BIN" ]; then
        echo "❌ QEMU 转译器安装或配置失败，程序无法继续。"
        exit 1
    fi
    # 核心：将启动命令包上一层 QEMU 壳
    EXEC_CMD="${QEMU_BIN} ${BIN_PATH}"
else
    echo "❌ 错误: 暂不支持当前的系统架构 ($ARCH)。"
    exit 1
fi

# --- [2] 自动清理可能冲突的旧服务和容器 ---
echo "--- 正在清理可能冲突的旧进程/服务 ---"
if command -v systemctl >/dev/null 2>&1; then
    systemctl stop traffmonetizer traffmonetizer-qemu >/dev/null 2>&1
    systemctl disable traffmonetizer traffmonetizer-qemu >/dev/null 2>&1
fi
if command -v rc-service >/dev/null 2>&1; then
    rc-service traffmonetizer stop >/dev/null 2>&1
    rc-update del traffmonetizer >/dev/null 2>&1
fi
if command -v docker >/dev/null 2>&1; then
    docker rm -f tm >/dev/null 2>&1
fi
# 强杀旧进程
ps aux | grep "[t]m_cli start accept" | awk '{print $2}' | xargs -r kill -9 >/dev/null 2>&1

# --- [3] 下载核心文件 ---
echo "--- 正在下载客户端核心文件 ---"
curl -sSL -o $BIN_PATH $REPO_URL
if [ ! -s "$BIN_PATH" ] || grep -q "404: Not Found" "$BIN_PATH"; then
    echo "❌ 错误: 从仓库下载二进制文件失败。"
    rm -f $BIN_PATH
    exit 1
fi
chmod +x $BIN_PATH

# --- [4] 配置后台守护进程 (多系统自适应) ---
echo "--- 正在配置后台守护服务 ---"

# 检查系统实际运行的初始化系统 (部分 LXC 虽然有 systemctl 命令，但并未运行 systemd)
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    # ================== Systemd 模式 ==================
    echo "✅ 检测到 Systemd，正在配置..."
    cat <<EOF > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=TraffMonetizer Fix Service (Auto Arch)
After=network.target

[Service]
Type=simple
ExecStart=${EXEC_CMD} start accept --token "${TOKEN}"
Restart=always
RestartSec=5
StandardOutput=append:/var/log/tm_cli.log
StandardError=append:/var/log/tm_cli.err

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    systemctl restart ${SERVICE_NAME}
    sleep 2
    systemctl status ${SERVICE_NAME} --no-pager
    echo "✅ 部署完毕！TraffMonetizer 已在 Systemd 后台稳定运行。"

elif command -v rc-update >/dev/null 2>&1; then
    # ================== OpenRC 模式 (Alpine 等) ==================
    echo "✅ 检测到 OpenRC 服务管理器，正在配置..."
    cat <<EOF > /etc/init.d/${SERVICE_NAME}
#!/sbin/openrc-run
name="TraffMonetizer"
command="/bin/sh"
command_args="-c 'exec ${EXEC_CMD} start accept --token \"${TOKEN}\" >> /var/log/tm_cli.log 2>&1'"
pidfile="/var/run/${SERVICE_NAME}.pid"
command_background="true"
EOF
    chmod +x /etc/init.d/${SERVICE_NAME}
    rc-update add ${SERVICE_NAME} default
    rc-service ${SERVICE_NAME} restart
    echo "✅ 部署完毕！TraffMonetizer 已在 OpenRC 后台稳定运行。"

else
    # ================== 纯净容器兜底模式 (nohup + Crontab) ==================
    echo "⚠️ 未检测到服务管理器(Systemd/OpenRC)，将启用 nohup 纯净守护模式..."
    
    # 启动进程
    nohup ${EXEC_CMD} start accept --token "${TOKEN}" >> /var/log/tm_cli.log 2>&1 &
    
    # 创建守护脚本
    WATCHDOG_SCRIPT="/usr/local/bin/tm_watchdog.sh"
    cat <<EOF > $WATCHDOG_SCRIPT
#!/bin/bash
if ! ps aux | grep -v grep | grep -q "tm_cli start accept"; then
    nohup ${EXEC_CMD} start accept --token "${TOKEN}" >> /var/log/tm_cli.log 2>&1 &
fi
EOF
    chmod +x $WATCHDOG_SCRIPT

    # 配置 Crontab 定时任务保活
    if command -v crontab >/dev/null 2>&1; then
        # 移除可能存在的旧任务并添加新任务 (每分钟检查一次，并在重启时启动)
        (crontab -l 2>/dev/null | grep -v "tm_watchdog.sh"; echo "* * * * * $WATCHDOG_SCRIPT") | crontab -
        (crontab -l 2>/dev/null | grep -v "tm_cli start accept"; echo "@reboot $WATCHDOG_SCRIPT") | crontab -
        
        # 尝试启动 cron 服务（不同系统命令不同）
        if command -v service >/dev/null 2>&1; then
            service cron start >/dev/null 2>&1 || service crond start >/dev/null 2>&1
        fi
        echo "✅ 已通过 Crontab 添加进程守护与开机自启。"
    else
        echo "⚠️ 系统未安装 Crontab，进程已在后台运行，但重启服务器后需重新运行本脚本！"
    fi
    echo "✅ 部署完毕！TraffMonetizer 现已在后台运行 (PID: $!)。"
    echo "你可以使用命令 tail -f /var/log/tm_cli.log 查看运行日志。"
fi
