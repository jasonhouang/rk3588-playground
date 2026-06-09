#!/bin/bash
# create-image.sh - Build a custom bootable disk image for ROCK 5T (Official Structure Compatible)
set -e

echo "🚀 开始制作 ROCK 5T 自定义镜像 (对齐官方布局)..."

# === 1. 路径配置 ===
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BSP_DIR="$BASE_DIR/../radxa-bsp"
OUTPUT_DIR="$BASE_DIR/output"
IMG_FILE="$OUTPUT_DIR/rock-5t-custom.img"

# 源文件路径
KERNEL_IMAGE="$BSP_DIR/.src/linux/arch/arm64/boot/Image"
DTB_FILE="$BSP_DIR/.src/linux/arch/arm64/boot/dts/rockchip/rk3588-rock-5t.dtb"
IDBLOADER="$BSP_DIR/.src/u-boot/idbloader.img"
UBOOT_ITB="$BSP_DIR/.src/u-boot/u-boot.itb"
ROOTFS_TAR="$OUTPUT_DIR/debian-bookworm-arm64-rootfs.tar.gz"

# 检查文件
for f in "$KERNEL_IMAGE" "$DTB_FILE" "$IDBLOADER" "$UBOOT_ITB" "$ROOTFS_TAR"; do
    if [ ! -f "$f" ]; then echo "❌ 找不到文件 $f"; exit 1; fi
done

# === 2. 创建镜像 (8GB，更接近标准 SD 卡容量) ===
echo "📦 创建 8GB 镜像文件..."
truncate -s 8G "$IMG_FILE"

# === 3. 分区 (完全对齐官方结构) ===
echo "📐 划分分区..."
parted -s "$IMG_FILE" mklabel gpt
# p1: 16MB (Reserved/Alignment) - 4MB to 20MB
parted -s "$IMG_FILE" mkpart primary 4MiB 20MiB
# p2: 300MB (EFI/Overlays) - 20MB to 320MB
parted -s "$IMG_FILE" mkpart primary 20MiB 320MiB
# p3: 剩余全部 (RootFS)
parted -s "$IMG_FILE" mkpart primary 320MiB 100%

# === 4. 挂载 Loop 设备 ===
echo "🔗 挂载 Loop 设备..."
LOOP_DEV=$(sudo losetup --find --show --partscan "$IMG_FILE")
sleep 1

# === 5. 写入 Bootloader ===
echo "🔥 写入 U-Boot..."
sudo dd if="$IDBLOADER" of="$LOOP_DEV" seek=64 conv=notrunc status=none
sudo dd if="$UBOOT_ITB" of="$LOOP_DEV" seek=16384 conv=notrunc status=none

# === 6. 格式化 ===
echo "💾 格式化分区..."
# p2: vfat, label efi (官方标准)
sudo mkfs.vfat -n "efi" "${LOOP_DEV}p2"
# p3: ext4, label rootfs
sudo mkfs.ext4 -F -L "rootfs" "${LOOP_DEV}p3"

# === 7. 填充 RootFS ===
echo "📂 解压 RootFS 到 p3..."
MNT_ROOTFS=$(mktemp -d)
sudo mount "${LOOP_DEV}p3" "$MNT_ROOTFS"

# 解压基础系统
sudo tar -xzf "$ROOTFS_TAR" -C "$MNT_ROOTFS"

# === 8. 配置 Boot 目录 (在 RootFS 内部) ===
echo "🌟 配置启动文件 (Official Layout)..."
# 官方结构：所有启动文件都在 RootFS 分区的 /boot 下
sudo mkdir -p "$MNT_ROOTFS/boot/extlinux"

# 复制内核到 /boot/Image
sudo cp "$KERNEL_IMAGE" "$MNT_ROOTFS/boot/Image"
# 复制设备树到 /boot/rk3588-rock-5t.dtb
sudo cp "$DTB_FILE" "$MNT_ROOTFS/boot/rk3588-rock-5t.dtb"

# 创建启动配置 (添加了 earlycon 以便调试)
cat << EOF | sudo tee "$MNT_ROOTFS/boot/extlinux/extlinux.conf" > /dev/null
label rock5t-custom
    menu label ROCK 5T Custom Build
    kernel /boot/Image
    devicetree /boot/rk3588-rock-5t.dtb
    append root=LABEL=rootfs rw rootwait console=ttyFIQ0,1500000n8 earlycon rootfstype=ext4
EOF

# === 9. 清理 ===
echo "🧹 卸载并清理..."
sudo umount "$MNT_ROOTFS"
sudo losetup -d "$LOOP_DEV"

echo "✅ 镜像制作完成!"
echo "📄 文件: $IMG_FILE"
