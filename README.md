# RK3588 开发工作区

基于 Radxa ROCK 5T 的 RK3588 开发环境，包含 U-Boot、Linux Kernel、RootFS 的完整编译工具和文档。

## 项目结构

```
rk3588-play/
├── bsp/                  [submodule] Radxa BSP 工具链 (radxa-repo/bsp)
├── rk3588-reference/     [submodule] RK3588 技术文档 (Datasheet, TRM, PMIC)
├── rock5t-dev/           构建脚本、内核 Patch、开发文档
│   ├── scripts/          U-Boot/Kernel/RootFS 编译脚本
│   ├── patches/kernel/   自定义内核配置补丁
│   └── README*.md        各组件详细文档
├── hardware-design/      ROCK 5T 硬件设计文件 (2D/3D)
└── .gitmodules           Submodule 配置
```

## Submodules

| 路径 | 远程仓库 | 说明 |
|------|----------|------|
| `bsp` | https://github.com/radxa-repo/bsp.git | Radxa BSP 工具链，用于编译 U-Boot 和 Kernel |
| `rk3588-reference` | git@github.com:jasonhouang/rk3588-reference.git | RK3588 技术参考文档（已迁移到 Git LFS） |

## 快速开始

### 1. 克隆仓库（含 submodule）

```bash
git clone --recurse-submodules <repo-url> rk3588-play
cd rk3588-play
```

如果已经克隆但忘记初始化 submodule：

```bash
git submodule update --init --recursive
```

### 2. 安装依赖

```bash
# 系统依赖
sudo apt-get install -y git make python3 podman debootstrap qemu-user-static

# 或使用项目脚本
./rock5t-dev/scripts/install-deps.sh
```

### 3. 编译 U-Boot

```bash
cd rock5t-dev
./scripts/build-uboot.sh
```

产物位于 `bsp/.src/u-boot/`。

### 4. 编译 Linux Kernel

```bash
cd rock5t-dev
./scripts/build-kernel.sh --clean
```

自动应用 `patches/kernel/` 下的自定义补丁，编译完成后恢复 BSP 源文件。

生成的 deb 包位于 `bsp/` 目录。

### 5. 构建 RootFS

```bash
cd rock5t-dev
sudo ./scripts/build-rootfs.sh
```

### 6. 安装到板子

```bash
# 上传内核包
sshpass -p 'radxa' scp \
    bsp/linux-image-6.1.84-1-rk2410_*.deb \
    bsp/linux-headers-6.1.84-1-rk2410_*.deb \
    radxa@192.168.8.170:/tmp/

# 安装并触发 DKMS（编译 WiFi 驱动）
sshpass -p 'radxa' ssh radxa@192.168.8.170 << 'EOF'
sudo dpkg -i /tmp/linux-image-6.1.84-1-rk2410_*.deb /tmp/linux-headers-6.1.84-1-rk2410_*.deb
sudo dkms autoinstall -k 6.1.84-1-rk2410
sudo reboot
EOF
```

## Submodule 常用操作

```bash
# 更新 submodule 到最新
git submodule update --remote bsp
git submodule update --remote rk3588-reference

# 进入 submodule 查看状态
cd bsp && git status

# 提交 submodule 更新
cd .. && git add bsp rk3588-reference && git commit -m "Update submodules"
```

## 文档索引

- [U-Boot & Kernel & RootFS 编译指南](rock5t-dev/README.md)
- [内核编译与 WiFi 驱动问题](rock5t-dev/README-kernel-build.md)
- RK3588 技术文档：`rk3588-reference/` 目录

## 板子信息

| 项目 | 值 |
|------|----|
| 开发板 | Radxa ROCK 5T |
| SoC | RK3588 (8 核: 4xA76 + 4xA55) |
| RAM | 4/8 GB LPDDR5 |
| WiFi | Realtek RTL8852BE (PCIe) |
| 板子 IP | 192.168.8.170 |
| 默认用户 | radxa / radxa |
| SSH 端口 | 22 |

## 开发环境

- 宿主机：AMD Ryzen 3950X, RTX 3080 10GB
- Debian 12 Bookworm / Podman 容器
- BSP Profile: `rk2410`
- 内核版本：6.1.84-1-rk2410

## 已知问题

- **WiFi 驱动**：Rock 5T 使用 Realtek RTL8852BE（PCIe），上游内核未包含 8852BE 驱动，需要通过 DKMS 编译外部驱动。必须同时安装 `linux-image` 和 `linux-headers` 包。
- **BCMDHD 冲突**：内核默认启用 `CONFIG_BCMDHD=y`，已通过 `patches/kernel/0001-disable-bcmdhd.patch` 禁用。
