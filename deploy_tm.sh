#!/usr/bin/env bash

# TraffMonetizer universal deploy script for x86_64 and ARM64 VPS/LXC hosts.
# Project: https://github.com/ypq123456789/traffmonetizer-fix

TOKEN="${1:-}"

if [ -z "$TOKEN" ]; then
    echo "ERROR: missing token."
    echo "Usage: bash $0 <your-token>"
    exit 1
fi

SERVICE_NAME="traffmonetizer"
BIN_PATH="/usr/local/bin/tm_cli"
DOWNLOAD_PATH="${BIN_PATH}.download.$$"
REPO_URL="https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/tm_cli"

cleanup_download() {
    rm -f "$DOWNLOAD_PATH"
}
trap cleanup_download EXIT

kill_tm_processes() {
    pids="$(ps aux | awk '/[t]m_cli start accept/ {print $2}')"
    if [ -n "$pids" ]; then
        echo "$pids" | xargs -r kill -TERM >/dev/null 2>&1 || true
        sleep 2
        pids="$(ps aux | awk '/[t]m_cli start accept/ {print $2}')"
        if [ -n "$pids" ]; then
            echo "$pids" | xargs -r kill -KILL >/dev/null 2>&1 || true
        fi
    fi
}

install_base_deps() {
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y curl procps cron "$@"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl procps cronie "$@"
    elif command -v apk >/dev/null 2>&1; then
        apk update && apk add curl procps dcron "$@"
    else
        echo "ERROR: unsupported package manager. Please install curl and procps manually."
        exit 1
    fi
}

ARCH="$(uname -m)"
echo "--- Detecting system architecture: $ARCH ---"

if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    echo "Detected x86_64 architecture; using native mode."
    EXEC_CMD="${BIN_PATH}"

    if ! command -v curl >/dev/null 2>&1 || ! command -v ps >/dev/null 2>&1; then
        echo "Installing base dependencies..."
        install_base_deps
    fi
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "Detected ARM64 architecture; using QEMU x86_64 translation mode."

    if command -v apt-get >/dev/null 2>&1; then
        install_base_deps qemu-user-static
    elif command -v yum >/dev/null 2>&1; then
        yum install -y epel-release
        install_base_deps qemu-user-static
    elif command -v apk >/dev/null 2>&1; then
        apk update && apk add curl procps dcron qemu-aarch64 qemu-x86_64
    else
        echo "ERROR: unsupported package manager. Please install curl, procps, and qemu-x86_64 manually."
        exit 1
    fi

    QEMU_BIN="$(command -v qemu-x86_64-static || command -v qemu-x86_64 || true)"
    if [ -z "$QEMU_BIN" ]; then
        echo "ERROR: qemu-x86_64 is not available after dependency installation."
        exit 1
    fi
    EXEC_CMD="${QEMU_BIN} ${BIN_PATH}"
else
    echo "ERROR: unsupported system architecture: $ARCH"
    exit 1
fi

echo "--- Cleaning up old services and processes ---"
if command -v systemctl >/dev/null 2>&1; then
    systemctl stop traffmonetizer traffmonetizer-qemu >/dev/null 2>&1 || true
    systemctl disable traffmonetizer traffmonetizer-qemu >/dev/null 2>&1 || true
fi
if command -v rc-service >/dev/null 2>&1; then
    rc-service "$SERVICE_NAME" stop >/dev/null 2>&1 || true
    rc-update del "$SERVICE_NAME" >/dev/null 2>&1 || true
    rm -f "/var/run/${SERVICE_NAME}.pid"
fi
if command -v docker >/dev/null 2>&1; then
    docker rm -f tm >/dev/null 2>&1 || true
fi
kill_tm_processes

echo "--- Downloading TraffMonetizer client ---"
if ! curl -fL --retry 3 --retry-delay 2 -o "$DOWNLOAD_PATH" "$REPO_URL"; then
    echo "ERROR: failed to download tm_cli from repository."
    exit 1
fi
if [ ! -s "$DOWNLOAD_PATH" ] || grep -q "404: Not Found" "$DOWNLOAD_PATH"; then
    echo "ERROR: repository download returned invalid content."
    exit 1
fi
chmod +x "$DOWNLOAD_PATH"
mv -f "$DOWNLOAD_PATH" "$BIN_PATH"
chmod +x "$BIN_PATH"

echo "--- Configuring background service ---"

if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    echo "Detected systemd; configuring service..."
    cat <<EOF > "/etc/systemd/system/${SERVICE_NAME}.service"
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
    systemctl enable "$SERVICE_NAME"
    systemctl restart "$SERVICE_NAME"
    sleep 2
    systemctl status "$SERVICE_NAME" --no-pager
    echo "Deployment complete. TraffMonetizer is running under systemd."
elif command -v rc-update >/dev/null 2>&1; then
    echo "Detected OpenRC; configuring service..."
    cat <<EOF > "/etc/init.d/${SERVICE_NAME}"
#!/sbin/openrc-run
name="TraffMonetizer"
command="/bin/sh"
command_args="-c 'exec ${EXEC_CMD} start accept --token \"${TOKEN}\" >> /var/log/tm_cli.log 2>&1'"
pidfile="/var/run/${SERVICE_NAME}.pid"
command_background="true"
EOF

    chmod +x "/etc/init.d/${SERVICE_NAME}"
    rc-update add "$SERVICE_NAME" default
    rc-service "$SERVICE_NAME" stop >/dev/null 2>&1 || true
    kill_tm_processes
    rm -f "/var/run/${SERVICE_NAME}.pid"
    if ! rc-service "$SERVICE_NAME" start; then
        echo "ERROR: OpenRC service failed to start. Check /var/log/tm_cli.log or /var/log/tm_cli.err."
        exit 1
    fi
    echo "Deployment complete. TraffMonetizer is running under OpenRC."
else
    echo "No systemd/OpenRC detected; using nohup and crontab watchdog."
    nohup ${EXEC_CMD} start accept --token "${TOKEN}" >> /var/log/tm_cli.log 2>&1 &

    WATCHDOG_SCRIPT="/usr/local/bin/tm_watchdog.sh"
    cat <<EOF > "$WATCHDOG_SCRIPT"
#!/usr/bin/env bash
if ! ps aux | grep -v grep | grep -q "tm_cli start accept"; then
    nohup ${EXEC_CMD} start accept --token "${TOKEN}" >> /var/log/tm_cli.log 2>&1 &
fi
EOF
    chmod +x "$WATCHDOG_SCRIPT"

    if command -v crontab >/dev/null 2>&1; then
        (crontab -l 2>/dev/null | grep -v "tm_watchdog.sh"; echo "* * * * * $WATCHDOG_SCRIPT") | crontab -
        (crontab -l 2>/dev/null | grep -v "tm_cli start accept"; echo "@reboot $WATCHDOG_SCRIPT") | crontab -
        if command -v service >/dev/null 2>&1; then
            service cron start >/dev/null 2>&1 || service crond start >/dev/null 2>&1 || true
        fi
        echo "Watchdog installed with crontab."
    else
        echo "WARNING: crontab is not installed; rerun this script after reboot."
    fi
    echo "Deployment complete. TraffMonetizer is running with PID $!."
    echo "Use: tail -f /var/log/tm_cli.log"
fi
