#!/bin/bash
# create-image.sh - Build a custom bootable disk image for ROCK 5T
set -e

echo "🚀 开始制作 ROCK 5T 自定义镜像..."

# === 1. 路径配置 ===
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BSP_DIR="$BASE_DIR/../radxa-bsp"
OUTPUT_DIR="$BASE_DIR/output"
IMG_FILE="$OUTPUT_DIR/rock-5t-custom.img"

# 源文件路径 (根据之前的查找结果)
KERNEL_IMAGE="$BSP_DIR/.src/linux/arch/arm64/boot/Image"
DTB_FILE="$BSP_DIR/.src/linux/arch/arm64/boot/dts/rockchip/rk3588-rock-5t.dtb"
IDBLOADER="$BSP_DIR/.src/u-boot/idbloader.img"
UBOOT_ITB="$BSP_DIR/.src/u-boot/u-boot.itb"
ROOTFS_TAR="$OUTPUT_DIR/debian-bookworm-arm64-rootfs.tar.gz"

# 检查文件是否存在
for f in "$KERNEL_IMAGE" "$DTB_FILE" "$IDBLOADER" "$UBOOT_ITB" "$ROOTFS_TAR"; do
    if [ ! -f "$f" ]; then
        echo "❌ 错误: 找不到文件 $f"
        exit 1
    fi
done

# === 2. 创建镜像文件 (6GB) ===
echo "📦 创建 6GB 镜像文件..."
truncate -s 6G "$IMG_FILE"

# === 3. 分区 ===
echo "📐 划分分区..."
parted -s "$IMG_FILE" mklabel gpt
# 分区 1: Reserved (16MB) - 用于对齐/ATF
parted -s "$IMG_FILE" mkpart primary 4MB 20MB
# 分区 2: Boot (300MB) - ext4, 存放内核和设备树
parted -s "$IMG_FILE" mkpart primary 20MB 320MB
# 分区 3: RootFS (剩余空间) - ext4, 存放根文件系统
parted -s "$IMG_FILE" mkpart primary 320MB 100%

# === 4. 挂载 Loop 设备 ===
echo "🔗 挂载 Loop 设备..."
LOOP_DEV=$(sudo losetup --find --show --partscan "$IMG_FILE")
echo "   挂载到: $LOOP_DEV"

# 等待设备就绪
sleep 1

# === 5. 写入 Bootloader ===
echo "🔥 写入 U-Boot..."
# idbloader 位于扇区 64 (32KB)
sudo dd if="$IDBLOADER" of="$LOOP_DEV" seek=64 conv=notrunc status=none
# u-boot.itb 位于扇区 16384 (8MB)
sudo dd if="$UBOOT_ITB" of="$LOOP_DEV" seek=16384 conv=notrunc status=none
echo "   ✅ U-Boot 写入完成"

# === 6. 格式化并挂载分区 ===
echo "💾 格式化分区..."
sudo mkfs.ext4 -F -L boot "${LOOP_DEV}p2"
sudo mkfs.ext4 -F -L rootfs "${LOOP_DEV}p3"

MNT_BOOT=$(mktemp -d)
MNT_ROOTFS=$(mktemp -d)

echo "   挂载 Boot 分区..."
sudo mount "${LOOP_DEV}p2" "$MNT_BOOT"
echo "   挂载 RootFS 分区..."
sudo mount "${LOOP_DEV}p3" "$MNT_ROOTFS"

# === 7. 填充 RootFS ===
echo "📂 解压 RootFS..."
sudo tar -xzf "$ROOTFS_TAR" -C "$MNT_ROOTFS"

# 更新 fstab (让系统启动时挂载 Boot 分区到 /boot)
echo "/dev/mmcblk1p2  /boot  ext4  defaults  0  2" | sudo tee -a "$MNT_ROOTFS/etc/fstab" > /dev/null

# === 8. 填充 Boot 分区 ===
echo "🌟 填充 Boot 分区..."
# 复制内核和设备树
sudo cp "$KERNEL_IMAGE" "$MNT_BOOT/Image"
sudo cp "$DTB_FILE" "$MNT_BOOT/rk3588-rock-5t.dtb"

# 创建 extlinux 目录和配置文件
sudo mkdir -p "$MNT_BOOT/extlinux"
cat << EOF | sudo tee "$MNT_BOOT/extlinux/extlinux.conf" > /dev/null
label rock5t-custom
    menu label ROCK 5T Custom Build
    kernel /Image
    devicetree /rk3588-rock-5t.dtb
    append root=/dev/mmcblk1p3 rw rootfstype=ext4 console=ttyFIQ0,1500000n8 console=tty1 coherent_pool=2M irqchip.gicv3_pseudo_nmi=0
EOF

echo "   ✅ 镜像制作完成!"
echo "   📄 文件位于: $IMG_FILE"

# === 9. 清理 ===
echo "🧹 卸载并清理..."
sudo umount "$MNT_ROOTFS"
sudo umount "$MNT_BOOT"
rmdir "$MNT_ROOTFS" "$MNT_BOOT"
sudo losetup -d "$LOOP_DEV"
