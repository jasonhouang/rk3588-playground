# Radxa ROCK 5T 开发指南 (U-Boot & Kernel & RootFS)

本项目提供用于编译 **Radxa ROCK 5T** (RK3588) 底层固件的脚本和文档。

## 🛠️ 环境准备

1.  **系统要求**: 推荐使用 x86_64 Ubuntu 20.04/22.04 或 Debian 11/12。
2.  **容器运行时**: 必须安装 **Docker** 或 **Podman**（脚本会自动检测，推荐 Podman）。
    ```bash
    sudo apt-get install podman
    ```
3.  **依赖工具**:
    ```bash
    sudo apt-get install git make python3
    ```
4.  **BSP 工具**: 本脚本依赖于上级目录的 `bsp` 仓库。
    *   确保 `/your/path/to/rk3588-playground/radxa-bsp` 存在。
    *   如果不存在，请运行:
        ```bash
        cd /your/path/to/rk3588-playground
        git clone https://github.com/jasonhouang/radxa-bsp.git
        ```

## 📦 编译指南

所有编译操作均在容器中进行，不会污染宿主机环境。

### 1. 编译 U-Boot
U-Boot 负责引导系统和加载内核。

```bash
# 快速编译
./scripts/build-uboot.sh

# 如果你修改了源码，想重新全量编译
./scripts/build-uboot.sh --clean
```
*   **产物位置**: 编译成功后，生成的 `idbloader.img`, `u-boot.itb`, `u-boot-rockchip.bin` 等文件通常位于 `radxa-bsp/.src/u-boot/` 目录下。

### 2. 编译 Linux Kernel
Kernel 包含驱动程序和文件系统支持。

```bash
# 快速编译
./scripts/build-kernel.sh

# 清理并重新编译
./scripts/build-kernel.sh --clean
```
*   **产物位置**: 编译生成的文件已自动汇总到 `output/` 目录：
    *   `output/boot/`: 原始内核镜像 (`Image-rk3588`) 和设备树 (`rk3588-rock-5t.dtb`)。
    *   `output/uboot/`: 原始 U-Boot 镜像 (`idbloader.img`, `u-boot.itb`)。
    *   `output/debs/`: 可用于在板卡上安装的 Debian 包 (`linux-image-...deb`)。
    
    *注：原始文件仍保留在 `../radxa-bsp/.src/` 目录下。

### 3. 构建 Debian RootFS
构建纯净的 Debian ARM64 根文件系统（默认 Debian 12 Bookworm）。
*   **前置依赖**: `sudo apt-get install debootstrap qemu-user-static`

```bash
# 需要 sudo 权限
sudo ./scripts/build-rootfs.sh
```
*   **版本切换**: 编辑脚本修改 `SUITE="trixie"` 可构建 Debian 13 (Testing)。
*   **产物位置**: 生成的 `debian-...-rootfs.tar.gz` 位于 `output/` 目录。

## 💡 常见命令速查 (手动执行)

如果你想直接操作 `radxa-bsp` 中的 bsp 工具，可以参考以下命令：

```bash
cd ../radxa-bsp

# 查看帮助
./bsp --help

# 编译 U-Boot (指定 profile: rk2410, 产品: rock-5t)
./bsp u-boot rk2410 rock-5t

# 编译 Kernel (指定 profile: rk2410)
./bsp linux rk2410

# 将编译好的镜像安装到 SD 卡 (例如 /dev/sdb)
# ./bsp install <target_block_device>
```

## 📚 参考文档
关于 RK3588 的硬件寄存器定义和引脚配置，请参考本项目下的 `rk3588-reference` 目录。
