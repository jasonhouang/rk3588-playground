#!/bin/bash
# build-kernel.sh - 编译 ROCK 5T 的 Linux Kernel
# 自动应用自定义 patch，不修改 BSP 源文件
# Usage: ./scripts/build-kernel.sh [--clean]

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
BSP_DIR="$PROJECT_DIR/../radxa-bsp"
PATCH_DIR="$PROJECT_DIR/patches/kernel"

# 检查 BSP 目录
if [ ! -d "$BSP_DIR" ]; then
    echo "❌ 错误: 找不到 BSP 目录 ($BSP_DIR)"
    exit 1
fi

echo "🐧 开始编译 ROCK 5T Kernel (rk2410 profile)..."
cd "$BSP_DIR"

# 清理旧构建
if [[ "$1" == "--clean" ]]; then
    echo "🧹 正在清理 Kernel 旧构建..."
   ./bsp linux rk2410 --clean
fi

# 应用自定义 patch
if [ -d "$PATCH_DIR" ] && ls "$PATCH_DIR"/*.patch &>/dev/null; then
    echo "🩹 应用自定义内核 patch..."
    for p in "$PATCH_DIR"/*.patch; do
        echo "   → $(basename "$p")"
        # 尝试应用 patch，如果失败则跳过（可能已经应用过）
        if ! patch -p1 --dry-run < "$p" &>/dev/null; then
            echo "   ⚠️  已应用，跳过"
        else
            patch -p1 < "$p"
            echo "   ✅ 已应用"
        fi
    done
fi

# 执行编译
echo "🔨 开始编译..."
./bsp linux rk2410

# 编译完成后恢复 BSP 源文件（保持仓库干净）
echo "🔄 恢复 BSP 源文件..."
if [ -d "$PATCH_DIR" ] && ls "$PATCH_DIR"/*.patch &>/dev/null; then
    for p in "$PATCH_DIR"/*.patch; do
        # 反向应用 patch 来恢复原始文件
        patch -R -p1 < "$p" 2>/dev/null || true
    done
    echo "   ✅ BSP 已恢复干净"
fi

# 显示生成的文件
echo ""
echo "✅ Kernel 编译完成!"
echo "💾 生成的 deb 包："
ls -lh "$BSP_DIR"/linux-image-*.deb "$BSP_DIR"/linux-headers-*.deb "$BSP_DIR"/linux-libc-dev-*.deb 2>/dev/null || echo "   （未找到 deb 包，请检查编译日志）"
echo ""
echo "📋 安装到板子的命令："
echo "   sshpass -p 'radxa' scp \\"
echo "       $BSP_DIR/linux-image-6.1.84-1-rk2410_*.deb \\"
echo "       $BSP_DIR/linux-headers-6.1.84-1-rk2410_*.deb \\"
echo "       radxa@192.168.8.170:/tmp/"
