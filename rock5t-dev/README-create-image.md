# 制作 ROCK 5T 自定义烧录镜像 (官方布局兼容)

本文档介绍如何使用本地编译的 U-Boot、Kernel 和 RootFS 制作一个与官方镜像结构完全一致的烧录镜像（`.img`）。

## 1. 结构说明 (关键)

为了解决之前“无法自动启动”的问题，新版脚本**完全复刻了官方镜像的分区布局**：

- **p1 (16MB)**: 预留对齐区。
- **p2 (300MB, FAT32)**: EFI/Overlays 分区。
- **p3 (剩余空间, ext4)**: **RootFS 根文件系统**。
    - **重要**：与之前的尝试不同，所有的启动文件（内核、设备树、extlinux 配置）现在都存放在 **RootFS 分区的 `/boot` 目录下**。

这种布局确保了 U-Boot 能够正确扫描到 `/boot/extlinux/extlinux.conf` 并引导系统。

## 2. 创建镜像

运行以下脚本：

```bash
cd ~/Workspaces/rk3588-play/rock5t-dev
sudo ./scripts/create-image.sh
```

### 脚本执行流程
1.  创建 **8GB** 镜像文件（更接近标准 SD 卡容量）。
2.  划分上述三个分区。
3.  烧录 Bootloader (`idbloader.img` 和 `u-boot.itb`)。
4.  格式化 p2 (vfat) 和 p3 (ext4)。
5.  解压 RootFS 到 p3。
6.  **将内核和设备树放入 p3 的 `/boot` 目录**。
7.  生成启动配置，默认开启了 `earlycon` 以便调试。

## 3. 镜像结构详情

制作完成的镜像结构：

```text
rock-5t-custom.img (8GB)
├── [Sector 64]      idbloader.img
├── [Sector 16384]   u-boot.itb
├── Partition 1 (16MB)  Reserved
├── Partition 2 (300MB) EFI (FAT32)
└── Partition 3 (~7.7GB) RootFS (ext4)
    ├── /bin, /etc, /usr...
    └── /boot/
        ├── Image                     <-- 自定义内核
        ├── rk3588-rock-5t.dtb        <-- 自定义设备树
        └── extlinux/
            └── extlinux.conf         <-- 启动配置 (含 earlycon)
```

## 4. 烧录与调试

### 烧录
同之前一样，使用 `dd` 或 `rkdeveloptool` 烧录。

### 串口调试
如果启动遇到问题，由于我们在 `extlinux.conf` 中默认加入了 **`earlycon`**，你应该能在串口看到内核最早期的输出信息：

```text
Starting kernel ...
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x412fd050]
...
```

如果卡住了，请拍照发给我，`earlycon` 会告诉我们具体停在哪一步。
