#!/bin/bash

# =================================================================
# 脚本名称: deploy_tm_auto.sh
# 功能: 自动检测架构下载 tm_cli 并识别服务管理器（Systemd/OpenRC）配置开机自启
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

# 自动检测系统架构并分配对应的下载链接
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    REPO_URL="https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/tm_cli"
    echo "👉 检测到 $ARCH 架构，准备下载 AMD64 版本..."
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    # 此处假设仓库中 aarch64 版本的二进制文件名为 tm_cli_aarch64。
    # 如果原作者使用了其他命名规则，请手动修改此处的链接后缀。
    REPO_URL="https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/tm_cli_aarch64"
    echo "👉 检测到 $ARCH 架构，准备下载 ARM64 版本..."
else
    echo "❌ 错误: 暂不支持当前的系统架构 ($ARCH)。"
    exit 1
fi

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

# 校验文件是否下载成功（防止仓库中没有对应的 ARM64 文件导致下载到 404 页面）
if [ ! -s "$BIN_PATH" ] || grep -q "404: Not Found" "$BIN_PATH"; then
    echo "❌ 错误: 从 $REPO_URL 下载二进制文件失败，文件可能不存在。"
    rm -f $BIN_PATH
    exit 1
fi

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
