

# 🚀 TraffMonetizer Fix (LXC/Docker/ARM64 终极优化版)

本项目专为解决在 LXC 容器或低价 NAT VPS 中运行 TraffMonetizer 时遇到的**底层权限冲突**与**官方 ARM 架构支持失效**问题而生。

> [!IMPORTANT]
> 还没有账号？点击这里注册：
> 👉 [立即注册 TraffMonetizer (带 AFF 推荐链接)](https://traffmonetizer.com/?aff=1012745) 👈

---

### 🔍 为什么需要这个项目？

在各类低价 NAT VPS 或 LXC 容器中挂机 TraffMonetizer 时，你通常会遭遇以下“连环坑”：

1. **x86_64 宿主机报错 (PermissionDenied):** 这是由于 Tokio 异步框架在处理系统信号时，受到了 LXC 和 Docker 的双层权限过滤（AppArmor/Seccomp）限制，导致直接运行 Docker 会触发 Panic。
2. **ARM64 官方镜像彻底摆烂:** 官方的 `cli_v2:latest` 镜像在 ARM 机器上错误打包了 AMD64 的程序，导致出现 `Exec format error` 或伪装成 `disk quota exceeded`（内核会话密钥环限制）的底层报错。同时，历史可用的官方 V1 多架构镜像已被删除。
3. **LXC 封锁 QEMU 自动转译:** 即使你试图在 ARM 机器上安装 `qemu-user-static` 来翻译 x86 程序，也会因为服务商封锁了底层的 `/proc/sys/fs/binfmt_misc` 接口，导致系统无法自动注册和识别。

**🎯 本项目的终极解决思路：**
* **对于 x86_64：** 将二进制文件提取到 LXC 宿主机层原生运行，彻底绕过 Docker 权限限制。
* **对于 ARM64：** 引入专属部署脚本，利用 QEMU 静态翻译器，在 Systemd 中**显式、强行调用**翻译指令包载运行，完美突破官方架构错误与 LXC 的 `binfmt_misc` 封锁！

---

## ⚡ 快速开始 (全架构通用)

无论你的服务器是 x86_64 还是 ARM64，直接在终端（root 用户）中执行以下一行命令即可。脚本会自动识别架构并采用原生或 QEMU 引擎启动：

```bash
curl -sSL https://raw.githubusercontent.com/ypq123456789/traffmonetizer-fix/main/deploy_tm.sh | bash -s -- "你的TOKEN"
```

---

## ⚙️ 管理服务

脚本会自动创建 `systemd` 服务守护进程（x86 环境默认服务名为 `traffmonetizer`，ARM 环境为 `traffmonetizer-qemu`），方便进行全天候后台管理：

* **查看运行状态:** `systemctl status traffmonetizer` *(ARM 节点请加上 `-qemu`)*
* **查看实时日志:** `journalctl -u traffmonetizer -f`
* **停止/重启服务:** `systemctl stop/restart traffmonetizer`

---

## 🛠️ 脚本功能说明

1. **一键环境适配:** 自动判断架构，下载核心二进制文件；如为 ARM 环境则自动补齐 QEMU 依赖。
2. **自动清理防冲突:** 自动检测并清理旧的遗留进程或 Docker 冲突容器。
3. **持久化与自启:** 自动生成规范的 `systemd` 配置文件，支持开机自启。
4. **断线自动恢复:** 配置了 `Restart=always`，即使程序异常退出也会在 5 秒内自动满血复活。

---

## 📦 项目结构

* `tm_cli`: 提取自官方 Docker 镜像的 Linux x86_64 纯净二进制核心执行文件。
* `deploy_tm.sh`: 针对 x86_64 架构的自动化部署与原生服务配置脚本。
* `deploy_arm_qemu.sh`: 针对 ARM64 架构的专属 QEMU 跨架构强制转译部署脚本。

---

## ⚠️ 注意事项

* **性能损耗说明:** 在 ARM 机器上使用 QEMU 转译运行会占用极其微量（几乎可忽略不计）的额外 CPU 资源，对闲置小鸡挂机毫无影响。
* **Host 报错修复:** 若执行过程提示 `sudo: unable to resolve host`，请使用 `nano /etc/hosts` 添加一行 `127.0.1.1 你的主机名` 即可解决。

---
💖 如果你觉得这个开源项目完美解决你的挂机痛点，欢迎使用我的 AFF 链接注册支持：[https://traffmonetizer.com/?aff=1012745](https://traffmonetizer.com/?aff=1012745)
```
