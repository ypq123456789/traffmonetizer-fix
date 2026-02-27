#!/bin/bash

# =================================================================
# 脚本名称: setup_tm_service.sh
# 功能: 下载 tm_cli 并配置为 systemd 服务（开机自启+自动重启）
# 使用方法: sudo bash setup_tm_service.sh <你的Token>
# =================================================================

TOKEN=$1

if [ -z "$TOKEN" ]; then
    echo "错误: 请提供 Token 参数。"
    echo "用法: sudo bash $0 <你的Token>"
    exit 1
fi

# 变量定义
SERVICE_NAME="traffmonetizer"
BIN_PATH="/usr/local/bin/tm_cli"
REPO_URL="https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/tm_cli"

echo "--- [1/3] 正在下载二进制文件到 $BIN_PATH ---"
curl -L -o $BIN_PATH $REPO_URL
chmod +x $BIN_PATH

echo "--- [2/3] 正在创建 systemd 服务配置 ---"
cat <<EOF > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=TraffMonetizer Fix Service
After=network.target

[Service]
Type=simple
# 执行命令：包含 start accept 和传入的 token
ExecStart=${BIN_PATH} start accept --token "${TOKEN}"
# 失败后自动重启
Restart=always
# 重启间隔时间（5秒）
RestartSec=5
# 运行日志输出到 syslog
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=tm_cli

[Install]
WantedBy=multi-user.target
EOF

echo "--- [3/3] 正在启动服务并设置开机自启 ---"
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl restart ${SERVICE_NAME}

# 检查状态
sleep 2
systemctl status ${SERVICE_NAME} --no-pager
