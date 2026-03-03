#!/bin/sh

# =================================================================
# 脚本名称: setup_tm_service_alpine.sh
# 功能: 下载 tm_cli 并配置为 OpenRC 服务（开机自启+自动重启）
# 使用方法: sudo sh setup_tm_service_alpine.sh <你的Token>
# =================================================================

TOKEN=$1

if [ -z "$TOKEN" ]; then
    echo "错误: 请提供 Token 参数。"
    echo "用法: sudo sh $0 <你的Token>"
    exit 1
fi

# 变量定义
SERVICE_NAME="traffmonetizer"
BIN_PATH="/usr/local/bin/tm_cli"
REPO_URL="https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/tm_cli"

echo "--- [1/3] 正在检查依赖并下载二进制文件到 $BIN_PATH ---"
# Alpine 默认通常只带 wget，这里确保安装了 curl 以兼容原有逻辑
if ! command -v curl >/dev/null 2>&1; then
    apk add --no-cache curl
fi

curl -L -o $BIN_PATH $REPO_URL
chmod +x $BIN_PATH

echo "--- [2/3] 正在创建 OpenRC 服务配置 ---"
# Alpine 使用 OpenRC，服务脚本必须存放在 /etc/init.d/ 目录下
cat <<EOF > /etc/init.d/${SERVICE_NAME}
#!/sbin/openrc-run

name="TraffMonetizer Fix Service"
description="TraffMonetizer client background service"

# 执行命令
command="${BIN_PATH}"
# 传入的 token 会直接写入到这个配置文件中
command_args="start accept --token \"${TOKEN}\""

# 以后台方式运行
command_background="yes"
pidfile="/run/\${RC_SVCNAME}.pid"

# 使用 supervise-daemon 实现失败后自动重启 (对应 Restart=always 和 RestartSec=5)
supervisor="supervise-daemon"
respawn_delay="5"
respawn_max="0"

# 日志输出配置 (替代 systemd 的 syslog)
output_log="/var/log/tm_cli.log"
error_log="/var/log/tm_cli.err"

depend() {
    need net
}
EOF

# 必须赋予服务脚本执行权限
chmod +x /etc/init.d/${SERVICE_NAME}

echo "--- [3/3] 正在启动服务并设置开机自启 ---"
# OpenRC 设置开机自启 (添加到 default 运行级别)
rc-update add ${SERVICE_NAME} default

# 启动/重启服务
rc-service ${SERVICE_NAME} restart

# 检查状态
sleep 2
rc-service ${SERVICE_NAME} status
