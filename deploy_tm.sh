#!/bin/bash

# =================================================================
# 脚本名称: deploy_tm_auto.sh
# 功能: 下载 tm_cli 并自动识别系统服务管理器（Systemd 或 OpenRC），配置开机自启
# 使用方法: sudo bash deploy_tm_auto.sh <你的Token>
# =================================================================

TOKEN=$1

if [ -z "$TOKEN" ]; then
    echo "错误: 请提供 Token 参数。"
    echo "用法: sudo bash $0 <你的Token>"
    exit 1
fi

SERVICE_NAME="traffmonetizer"
BIN_PATH="/usr/local/bin/tm_cli"
REPO_URL="https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/tm_cli"

echo "--- [1/3] 正在检查依赖并下载二进制文件到 $BIN_PATH ---"
# 自动检测包管理器并安装 curl
if ! command -v curl >/dev/null 2>&1; then
    echo "正在安装 curl..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y curl
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache curl
    else
        echo "无法自动安装 curl，请手动安装后重试。"
        exit 1
    fi
fi

# 下载二进制文件
curl -L -o $BIN_PATH $REPO_URL
chmod +x $BIN_PATH

echo "--- [2/3] 正在识别系统服务管理器并创建配置 ---"

# 判断是否为 Systemd 环境
if command -v systemctl >/dev/null 2>&1; then
    echo "✅ 检测到 Systemd 服务管理器 (适用于 Ubuntu/Debian/CentOS 等主流系统)"
    cat <<EOF > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=TraffMonetizer Fix Service
After=network.target

[Service]
Type=simple
ExecStart=${BIN_PATH} start accept --token "${TOKEN}"
Restart=always
RestartSec=5
StandardOutput=append:/var/log/tm_cli.log
StandardError=append:/var/log/tm_cli.err

[Install]
WantedBy=multi-user.target
EOF

    echo "--- [3/3] 正在启动服务并设置开机自启 ---"
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    systemctl restart ${SERVICE_NAME}
    
    sleep 2
    systemctl status ${SERVICE_NAME} --no-pager

# 判断是否为 OpenRC 环境
elif command -v rc-update >/dev/null 2>&1; then
    echo "✅ 检测到 OpenRC 服务管理器 (适用于 Alpine Linux 等轻量系统)"
    cat <<EOF > /etc/init.d/${SERVICE_NAME}
#!/sbin/openrc-run

name="TraffMonetizer Fix Service"
description="TraffMonetizer client background service"

command="${BIN_PATH}"
command_args="start accept --token \"${TOKEN}\""
command_background="yes"
pidfile="/run/\${RC_SVCNAME}.pid"

supervisor="supervise-daemon"
respawn_delay="5"
respawn_max="0"

output_log="/var/log/tm_cli.log"
error_log="/var/log/tm_cli.err"

depend() {
    need net
}
EOF

    chmod +x /etc/init.d/${SERVICE_NAME}

    echo "--- [3/3] 正在启动服务并设置开机自启 ---"
    rc-update add ${SERVICE_NAME} default
    rc-service ${SERVICE_NAME} restart
    
    sleep 2
    rc-service ${SERVICE_NAME} status

else
    echo "❌ 错误: 未检测到受支持的服务管理器 (Systemd 或 OpenRC)。"
    echo "如果您使用的是非常规系统，请优先使用 nano 自行编写进程守护配置文件。"
    exit 1
fi

echo "部署流程执行完毕！"
