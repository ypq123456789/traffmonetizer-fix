
# 🚀 TraffMonetizer Fix (LXC/Docker Optimization)

本项目专为解决在 **LXC 容器** 中运行 TraffMonetizer 时遇到的权限冲突问题而生。

> [!IMPORTANT]
> **还没有账号？点击这里注册：**
> 👉 **[立即注册 TraffMonetizer (带 AFF 推荐链接)](https://traffmonetizer.com/?aff=1012745)** 👈

---

### 🔍 为什么需要这个项目？

在 LXC 容器内运行 Docker 版 TraffMonetizer 时，经常会遇到以下 Panic 报错：

> `failed to create UnixStream: Os { code: 13, kind: PermissionDenied }`

**原因分析**：这是由于 Tokio 异步框架在处理系统信号时，受到了 LXC 和 Docker 的双层权限过滤（AppArmor/Seccomp）限制。本项目通过将二进制文件提取到 LXC 宿主机层运行，彻底绕过该权限限制。

---

## ⚡ 快速开始

### 1. 一键部署并配置开机自启

在你的 LXC 终端（root 用户）中执行以下命令（记得将其中的 `你的TOKEN` 替换为后台获取的 Token）：

```bash
curl -sSL https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/deploy_tm.sh | bash -s -- "你的TOKEN"

```

### 2. 管理服务

脚本会自动创建一个名为 `traffmonetizer` 的 `systemd` 服务，方便管理：

* **查看运行状态**: `systemctl status traffmonetizer`
* **查看实时日志**: `journalctl -u traffmonetizer -f`
* **停止/重启服务**: `systemctl stop/restart traffmonetizer`

---

## 🛠️ 脚本功能说明 (`deploy_tm.sh`)

1. **自动清理**: 自动检测并停止旧的 `tm_cli` 进程或 Docker 冲突。
2. **一键环境适配**: 自动下载适配后的二进制文件并赋予执行权限。
3. **持久化运行**: 自动生成 `systemd` 配置文件，支持开机自启。
4. **自动恢复**: 配置了 `Restart=always`，程序异常退出后 5 秒内自动重启。

---

## 📦 项目结构

* `tm_cli`: 提取自官方 Docker 镜像的 Linux x86_64 二进制执行文件。
* `deploy_tm.sh`: 自动化部署与 Systemd 服务配置脚本。

---

## ⚠️ 注意事项

* **架构限制**: 本方案目前仅验证支持 **Linux x86_64**。
* **Host 报错**: 若提示 `sudo: unable to resolve host`，请使用 `nano /etc/hosts` 添加 `127.0.1.1 你的主机名`。

---
如果你觉得这个项目帮到了你，欢迎使用我的 AFF 链接注册支持：[https://traffmonetizer.com/?aff=1012745](https://traffmonetizer.com/?aff=1012745) 
