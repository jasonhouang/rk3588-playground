#!/bin/bash
# build-rootfs.sh - 为 ROCK 5T 构建 ARM64 Debian RootFS
# 逻辑顺序：下载 -> chroot安装 -> **先卸载挂载点** -> 最后打包

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

ARCH="arm64"
SUITE="bookworm"
MIRROR="http://deb.debian.org/debian/"
ROOTFS_DIR="$PROJECT_DIR/output/rootfs"
IMAGE_FILE="$PROJECT_DIR/output/debian-$SUITE-arm64-rootfs.tar.gz"

# 安全退出机制：防止意外中断导致挂载点残留
cleanup() {
    sudo umount -l "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
    sudo umount -l "$ROOTFS_DIR/dev" 2>/dev/null || true
    sudo umount -l "$ROOTFS_DIR/proc" 2>/dev/null || true
    sudo umount -l "$ROOTFS_DIR/sys" 2>/dev/null || true
}
trap cleanup EXIT

# 检查依赖
for cmd in debootstrap qemu-aarch64-static; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ 错误: 未找到 '$cmd'。请先安装 (sudo apt install debootstrap qemu-user-static)"
        exit 1
    fi
done

echo "🚀 开始构建 Debian $SUITE RootFS..."

# 1. 清理旧目录
if [ -d "$ROOTFS_DIR" ]; then
    echo "🧹 清理旧目录..."
    sudo rm -rf "$ROOTFS_DIR"
fi
mkdir -p "$ROOTFS_DIR"

# 2. 下载基础系统
echo "📦 正在下载基础系统包..."
sudo qemu-debootstrap --arch=$ARCH --include=systemd,sudo,locales,wget,curl,vim,isc-dhcp-client,net-tools,iproute2,dbus $SUITE "$ROOTFS_DIR" "$MIRROR"

# 3. 配置 RootFS
echo "⚙️ 配置 RootFS..."
sudo mount -t proc /proc "$ROOTFS_DIR/proc"
sudo mount -t sysfs /sys "$ROOTFS_DIR/sys"
sudo mount -o bind /dev "$ROOTFS_DIR/dev"
sudo mount -o bind /dev/pts "$ROOTFS_DIR/dev/pts"

echo "🔐 修复 Locale 配置..."
sudo chroot "$ROOTFS_DIR" /bin/bash -c "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen"

echo "📥 更新 apt 并安装..."
sudo chroot "$ROOTFS_DIR" /bin/bash -c "apt-get update && apt-get install -y ssh network-manager u-boot-tools parted dosfstools exfat-fuse"

echo "🔐 设置 root 密码和主机名..."
sudo chroot "$ROOTFS_DIR" /bin/bash -c "echo 'root:rock5t' | chpasswd"
sudo chroot "$ROOTFS_DIR" /bin/bash -c "echo 'rock-5t' > /etc/hostname"

# 4. ⬇️ 关键步骤：打包前先卸载所有挂载点 ⬇️
echo "🧹 准备打包，正在卸载虚拟文件系统..."
sudo rm -f "$ROOTFS_DIR/etc/resolv.conf"
sudo umount -l "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
sudo umount -l "$ROOTFS_DIR/dev" 2>/dev/null || true
sudo umount -l "$ROOTFS_DIR/proc" 2>/dev/null || true
sudo umount -l "$ROOTFS_DIR/sys" 2>/dev/null || true

echo "📦 打包 RootFS 到 $IMAGE_FILE..."
sudo tar --one-file-system -czf "$IMAGE_FILE" -C "$ROOTFS_DIR" .

echo "✅ RootFS 构建完成!"
