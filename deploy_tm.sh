#!/bin/bash

# =================================================================
# 脚本名称: deploy_arm_qemu.sh
# 功能: 解决 Traffmonetizer 官方 ARM 架构支持失效及 LXC 容器内核限制问题
# 原理: 下载 AMD64 二进制文件，利用 qemu-user-static 在 ARM64 上强制转译运行
# 项目地址: https://github.com/ypq123456789/traffmonetizer-fix
# =================================================================

TOKEN=$1

if [ -z "$TOKEN" ]; then
    echo "❌ 错误: 请提供 Token 参数。"
    echo "用法: sudo bash $0 <你的Token>"
    exit 1
fi

SERVICE_NAME="traffmonetizer-qemu"
BIN_PATH="/usr/local/bin/tm_cli_x86_64"
REPO_URL="https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/tm_cli"

echo "--- [1/4] 正在安装基础依赖和 QEMU 静态转译器 ---"
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y curl qemu-user-static
elif command -v yum >/dev/null 2>&1; then
    yum install -y curl epel-release
    yum install -y qemu-user-static
elif command -v apk >/dev/null 2>&1; then
    apk update
    apk add curl qemu-aarch64 qemu-x86_64
else
    echo "❌ 无法自动安装 qemu-user-static，请检查您的包管理器。"
    exit 1
fi

# 检查 QEMU 是否成功安装
if ! command -v qemu-x86_64-static >/dev/null 2>&1 && ! command -v qemu-x86_64 >/dev/null 2>&1; then
    echo "❌ QEMU 转译器安装失败，程序无法继续。"
    exit 1
fi

# 统一获取 QEMU 命令路径
QEMU_CMD=$(command -v qemu-x86_64-static || command -v qemu-x86_64)

echo "--- [2/4] 正在下载 AMD64 客户端核心文件 ---"
curl -sSL -o $BIN_PATH $REPO_URL

if [ ! -s "$BIN_PATH" ] || grep -q "404: Not Found" "$BIN_PATH"; then
    echo "❌ 错误: 从仓库下载二进制文件失败。"
    rm -f $BIN_PATH
    exit 1
fi

chmod +x $BIN_PATH

echo "--- [3/4] 正在配置 Systemd 后台守护服务 ---"
if command -v systemctl >/dev/null 2>&1; then
    cat <<EOF > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=TraffMonetizer QEMU Translated Service (ARM64 fix)
After=network.target

[Service]
Type=simple
# 显式调用 QEMU 翻译器包载运行 AMD64 程序，绕过 LXC 内核 binfmt 限制
ExecStart=${QEMU_CMD} ${BIN_PATH} start accept --token "${TOKEN}"
Restart=always
RestartSec=5
StandardOutput=append:/var/log/tm_qemu.log
StandardError=append:/var/log/tm_qemu.err

[Install]
WantedBy=multi-user.target
EOF

    echo "--- [4/4] 正在启动服务并设置开机自启 ---"
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    systemctl restart ${SERVICE_NAME}
    
    sleep 2
    systemctl status ${SERVICE_NAME} --no-pager
    echo "✅ 部署完毕！QEMU 跨架构挂机服务已在后台运行。"

else
    echo "❌ 错误: 未检测到 Systemd 服务管理器。"
    echo "请手动使用以下命令在前台运行或自行编写守护进程："
    echo "${QEMU_CMD} ${BIN_PATH} start accept --token \"${TOKEN}\""
    exit 1
fi
