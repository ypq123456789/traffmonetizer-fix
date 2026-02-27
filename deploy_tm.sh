#!/bin/bash

# =================================================================
# 脚本名称: deploy_tm.sh
# 功能: 从 GitHub 下载修复版 tm_cli 并后台运行
# =================================================================

# 配置变量
REPO_URL="https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/tm_cli"
LOCAL_BIN="./tm_cli"
LOG_FILE="./tm_cli.log"

# 获取传入的参数 (Token等)
ARGS=$@

if [ -z "$ARGS" ]; then
    echo "错误: 请输入启动参数（例如 --token ...）"
    exit 1
fi

# 1. 检查并停止已有的进程
echo "--- [1/3] 检查旧进程 ---"
PID=$(pgrep -f "tm_cli")
if [ -n "$PID" ]; then
    echo "停止正在运行的旧进程: $PID"
    kill -9 $PID
fi

# 2. 下载二进制文件 (如果本地不存在)
echo "--- [2/3] 正在从 GitHub 获取二进制文件 ---"
curl -L -o $LOCAL_BIN $REPO_URL

if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络或 GitHub 链接。"
    exit 1
fi

chmod +x $LOCAL_BIN

# 3. 启动程序
echo "--- [3/3] 正在后台启动 tm_cli ---"
# 使用 nohup 保证退出终端后继续运行
nohup $LOCAL_BIN start accept $ARGS > $LOG_FILE 2>&1 &

sleep 2
if ps -p $! > /dev/null; then
    echo "启动成功！"
    echo "运行参数: start accept $ARGS"
    echo "查看日志命令: tail -f $LOG_FILE"
else
    echo "启动失败，请检查 $LOG_FILE"
fi
