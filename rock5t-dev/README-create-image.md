# 制作 ROCK 5T 自定义烧录镜像

本文档介绍如何使用本地编译的 U-Boot、Kernel 和 RootFS 制作一个可烧录的完整磁盘镜像（`.img`）。

## 1. 前置条件

在运行脚本之前，请确保你已经通过 `build-*.sh` 完成了编译，并且 `radxa-bsp` 仓库中已检出相关源码。

所需的源文件包括：
- **U-Boot**: `radxa-bsp/.src/u-boot/idbloader.img`, `u-boot.itb`
- **Kernel**: `radxa-bsp/.src/linux/arch/arm64/boot/Image`, `rk3588-rock-5t.dtb`
- **RootFS**: `rock5t-dev/output/debian-bookworm-arm64-rootfs.tar.gz`

## 2. 创建镜像

运行以下脚本：

```bash
cd ~/Workspaces/rk3588-play/rock5t-dev
sudo ./scripts/create-image.sh
```

### 脚本执行流程
脚本会自动完成以下步骤（无需手动干预）：

1.  **创建空白镜像**：生成 6GB 的 `.img` 文件。
2.  **分区**：使用 `parted` 划分三个分区：
    -   `p1` (15MB): 预留对齐区。
    -   `p2` (286MB): **Boot 分区**，存放内核和设备树。
    -   `p3` (5.7GB): **RootFS 分区**，存放根文件系统。
3.  **烧录 Bootloader**：将 U-Boot 写入镜像开头的特定扇区：
    -   `idbloader.img` → 扇区 64 (32KB)
    -   `u-boot.itb` → 扇区 16384 (8MB)
4.  **格式化与挂载**：格式化 Boot 和 RootFS 分区并挂载。
5.  **填充内容**：
    -   解压 RootFS 到 `p3`。
    -   复制 `Image` 和 `rk3588-rock-5t.dtb` 到 `p2`。
    -   生成 `extlinux/extlinux.conf` 启动配置。
6.  **自动清理**：卸载分区并释放 loop 设备。

**产物位置**：`output/rock-5t-custom.img`

## 3. 镜像结构

制作完成的镜像包含以下结构：

```text
rock-5t-custom.img (6GB)
├── [Sector 64]      idbloader.img (DDR Init + SPL)
├── [Sector 16384]   u-boot.itb (Main U-Boot + ATF)
├── Partition 1 (15MB)  Reserved
├── Partition 2 (286MB) Boot (ext4)
│   ├── Image
│   ├── rk3588-rock-5t.dtb
│   └── extlinux/
│       └── extlinux.conf
└── Partition 3 (5.7GB) RootFS (ext4)
    ├── /bin, /etc, /usr...
    └── /etc/fstab (自动配置了 /boot 挂载点)
```

## 4. 烧录方法

### 方法 A：SD 卡烧录 (dd)

将 SD 卡插入电脑，确认设备名（如 `/dev/sdX`），然后运行：

```bash
# ⚠️ 警告：此操作将清空 SD 卡上的所有数据！
# 请将 /dev/sdX 替换为实际的设备路径
sudo dd if=output/rock-5t-custom.img of=/dev/sdX bs=1M status=progress oflag=direct
```

### 方法 B：eMMC 烧录 (rkdeveloptool)

如果板子处于 **Maskrom 模式**（按住 Recovery 键通电），可以使用 `rkdeveloptool`：

```bash
# 1. 初始化 loader
sudo rkdeveloptool db /path/to/rk2410_loader.bin

# 2. 写入镜像
sudo rkdeveloptool wl 0 output/rock-5t-custom.img

# 3. 重启
sudo rkdeveloptool rd
```

## 5. 常见问题

- **空间不足？**
  默认镜像大小为 6GB。如果需要更多空间，可以修改 `create-image.sh` 中的 `truncate -s 6G` 参数（例如改为 `10G`），或者在烧录后使用 `resize2fs` 扩展分区。
  
- **启动失败？**
  请检查 `p2` 分区中的 `/extlinux/extlinux.conf` 内容，确保 `root=/dev/mmcblk1p3` 参数正确指向了你的 RootFS 分区（SD 卡通常是 `mmcblk1`，eMMC 可能是 `mmcblk0`）。
