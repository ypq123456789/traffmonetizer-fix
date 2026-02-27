
# TraffMonetizer Fix (LXC/Docker Optimization)

本项目提供了一个用于在 **LXC 容器** 中稳定运行 TraffMonetizer 的修复方案。

### 为什么需要这个项目？
在 LXC 容器内运行 Docker 版 TraffMonetizer 时，经常会遇到以下报错：
> `failed to create UnixStream: Os { code: 13, kind: PermissionDenied }`

这是由于 Tokio 异步框架在处理系统信号时，受到了 LXC/Docker 双层权限过滤（AppArmor/Seccomp）的限制。本项目通过将二进制文件提取到 LXC 宿主机层运行，彻底绕过该权限冲突。

---

## 快速开始

### 1. 一键部署并配置开机自启
在你的 LXC 终端（root 用户）中执行以下命令（替换 `你的TOKEN`）：

```bash
curl -sSL https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/deploy_tm.sh | bash -s -- "你的TOKEN"

```

### 2. 管理服务

部署脚本会自动创建一个名为 `traffmonetizer` 的 systemd 服务。

* **查看运行状态**: `systemctl status traffmonetizer`
* **查看实时日志**: `journalctl -u traffmonetizer -f`
* **停止服务**: `systemctl stop traffmonetizer`
* **重启服务**: `systemctl restart traffmonetizer`

---

## 脚本功能说明 (`deploy_tm.sh`)

1. **自动清理**: 自动检测并停止已有的 `tm_cli` 进程。
2. **环境适配**: 自动从本仓库下载适配后的二进制文件并赋予执行权限。
3. **持久化运行**: 自动生成 `/etc/systemd/system/traffmonetizer.service` 配置文件。
4. **自动恢复**: 配置了 `Restart=always`，程序崩溃或系统重启后会自动拉起进程。

---

## 项目结构

* `tm_cli`: 提取自官方 Docker 镜像的 Linux 64位二进制执行文件。
* `deploy_tm.sh`: 自动化部署与 Systemd 服务配置脚本。

---

## 注意事项

* 本方案仅适用于 **Linux x86_64** 架构。
* 如果遇到 `sudo: unable to resolve host` 报错，请检查 `/etc/hosts` 是否配置了正确的主机名。

```
