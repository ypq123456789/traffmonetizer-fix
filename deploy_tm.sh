#!/bin/bash

# =================================================================
# 脚本名称: deploy_tm.sh
# 功能: Traffmonetizer LXC/NAT VPS 通用修复部署脚本 (支持 x86_64 & ARM64)
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
    if ! command -v curl >/dev/null 2>&1; then
        echo "正在安装 curl..."
        if command -v apt-get >/dev/null 2>&1; then apt-get update -y && apt-get install -y curl
        elif command -v yum >/dev/null 2>&1; then yum install -y curl
        elif command -v apk >/dev/null 2>&1; then apk update && apk add curl
        fi
    fi

elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "⚠️ 检测到 ARM64 架构，将自动启用 QEMU 跨架构转译模式！"
    
    # 安装基础依赖和 QEMU
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y curl qemu-user-static
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl epel-release && yum install -y qemu-user-static
    elif command -v apk >/dev/null 2>&1; then
        apk update && apk add curl qemu-aarch64 qemu-x86_64
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
echo "--- 正在清理可能冲突的旧服务 ---"
systemctl stop traffmonetizer traffmonetizer-qemu >/dev/null 2>&1
systemctl disable traffmonetizer traffmonetizer-qemu >/dev/null 2>&1
if command -v docker >/dev/null 2>&1; then
    docker rm -f tm >/dev/null 2>&1
fi

# --- [3] 下载核心文件 ---
echo "--- 正在下载客户端核心文件 ---"
curl -sSL -o $BIN_PATH $REPO_URL
if [ ! -s "$BIN_PATH" ] || grep -q "404: Not Found" "$BIN_PATH"; then
    echo "❌ 错误: 从仓库下载二进制文件失败。"
    rm -f $BIN_PATH
    exit 1
fi
chmod +x $BIN_PATH

# --- [4] 配置 Systemd 守护进程 ---
echo "--- 正在配置 Systemd 后台守护服务 ---"
if command -v systemctl >/dev/null 2>&1; then
    cat <<EOF > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=TraffMonetizer Fix Service (Auto Arch)
After=network.target

[Service]
Type=simple
# 这里的 EXEC_CMD 会根据架构自动变成原生执行或 QEMU 翻译执行
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
    echo "✅ 部署完毕！TraffMonetizer 已在后台稳定运行。"

else
    echo "❌ 错误: 未检测到 Systemd 服务管理器。"
    echo "请手动运行以下命令进行挂机:"
    echo "${EXEC_CMD} start accept --token \"${TOKEN}\""
    exit 1
fi
