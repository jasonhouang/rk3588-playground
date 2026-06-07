#!/bin/bash
# build-uboot.sh - 编译 ROCK 5T 的 U-Boot
# Usage: ./scripts/build-uboot.sh [--clean]

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
BSP_DIR="$PROJECT_DIR/../bsp"

# 检查 BSP 目录是否存在
if [ ! -d "$BSP_DIR" ]; then
    echo "❌ 错误: 找不到 BSP 目录 ($BSP_DIR)。请确保已克隆 bsp 仓库。"
    exit 1
fi

echo "🚀 开始编译 ROCK 5T U-Boot..."
cd "$BSP_DIR"

if [[ "$1" == "--clean" ]]; then
    echo "🧹 正在清理 U-Boot 旧构建..."
    ./bsp u-boot rk2410 rock-5t --clean
fi

# 执行编译 (使用 podman 容器)
./bsp u-boot rk2410 rock-5t

echo "✅ U-Boot 编译完成!"
echo "💾 你可以在 $BSP_DIR/.src/u-boot/ 目录下查看生成的文件。"
