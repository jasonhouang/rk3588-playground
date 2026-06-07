# ROCK 5T 内核编译：WiFi 驱动问题与完整编译指南

## 问题背景

自定义编译的内核 (`6.1.84-1-rk2410`) 安装后无法使用 WiFi，而原厂内核 (`6.1.84-8-rk2410`) 正常工作。

## 根本原因分析

### 1. Rock 5T 的 WiFi 芯片是 Realtek，不是 Broadcom

| 芯片 | 接口 | 驱动 | 内核支持 |
|------|------|------|----------|
| RTL8852BE | PCIe | `rtw89_8852be` | **上游内核未包含 8852BE** |
| BCM43752 | SDIO | `brcmfmac` | 内核内置支持 |

Rock 5T 使用 **Realtek RTL8852BE**（PCIe 接口）。

### 2. DKMS 是 WiFi 工作的关键

原厂通过 `rtw89-dkms` 包编译外部驱动：
- DKMS 源码位于 `/usr/src/rtw89-*/`
- 包含 `rtw_8852be` 等上游内核未包含的芯片驱动
- **DKMS 编译依赖 `linux-headers` 包**

如果内核没有安装对应的 headers，DKMS 无法为该内核编译驱动。

### 3. BCMDHD 驱动冲突

`CONFIG_BCMDHD=y`（旧款 Broadcom 驱动）会编译为内置驱动，可能抢占 SDIO 总线资源。

## Patch 管理机制

### 原则

**不直接修改 BSP 源文件**，在 `patches/kernel/` 目录下维护补丁，编译脚本自动应用和恢复。

### 目录结构

```
rock5t-dev/
├── patches/
│   └── kernel/
│       └── 0001-disable-bcmdhd.patch   # 禁用冲突的 Broadcom 驱动
├── scripts/
│   ├── build-kernel.sh                 # 自动应用 patch → 编译 → 恢复
│   └── build-rootfs.sh
└── README-kernel-build.md              # 本文档
```

### 如何添加新 Patch

在 `patches/kernel/` 下创建标准 diff 格式文件，命名规则 `NNNN-description.patch`：

```bash
# 示例：启用 WiFi 调试
cat > patches/kernel/0002-rtw89-debug.patch << 'EOF'
--- a/linux/rk2410/kconfig.conf
+++ b/linux/rk2410/kconfig.conf
@@ -23,3 +23,6 @@
 # CONFIG_BCMDHD is not set
 # CONFIG_BCMDHD_SDIO is not set
 # CONFIG_BCMDHD_PCIE is not set
+
+## Enable WiFi debug
+# CONFIG_RTW89_DEBUGFS is not set
+CONFIG_RTW89_DEBUGMSG=y
EOF
```

下次编译时会自动按文件名顺序应用所有 patch。

---

## 完整编译流程

### 第 1 步：编译内核

```bash
cd /your/path/to/rk3588-play/rock5t-dev
./scripts/build-kernel.sh --clean
```

脚本会自动：
1. 应用 `patches/kernel/` 下的所有 patch
2. 调用 `./bsp linux rk2410` 编译
3. 编译完成后恢复 BSP 源文件（保持仓库干净）

生成文件：
- `linux-image-6.1.84-1-rk2410_6.1.84-1_arm64.deb`
- `linux-headers-6.1.84-1-rk2410_6.1.84-1_arm64.deb`

### 第 2 步：安装到板子

```bash
# 设置板子 IP（请根据实际网络环境修改）
BOARD_IP="192.168.8.170"

# 上传 image + headers（必须同时安装）
sshpass -p 'radxa' scp \
    ~/Workspaces/rk3588-play/bsp/linux-image-6.1.84-1-rk2410_6.1.84-1_arm64.deb \
    ~/Workspaces/rk3588-play/bsp/linux-headers-6.1.84-1-rk2410_6.1.84-1_arm64.deb \
    radxa@${BOARD_IP}:/tmp/

# 安装并触发 DKMS
sshpass -p 'radxa' ssh radxa@${BOARD_IP} << 'EOF'
sudo dpkg -i /tmp/linux-image-6.1.84-1-rk2410_6.1.84-1_arm64.deb \
               /tmp/linux-headers-6.1.84-1-rk2410_6.1.84-1_arm64.deb

# DKMS 自动为 headers 编译 WiFi 驱动
sudo dkms autoinstall -k 6.1.84-1-rk2410

# 切换默认启动项
sudo sed -i "s/default l0/default l1/" /boot/extlinux/extlinux.conf

echo "✅ 安装完成，重启中..."
sudo reboot
EOF
```

### 第 3 步：验证

重启后等待 30 秒：

```bash
sshpass -p 'radxa' ssh radxa@${BOARD_IP} << 'EOF'
echo "=== 内核 ==="
uname -r

echo "=== WiFi ==="
ip a | grep wl
lsmod | grep rtw

echo "=== DKMS ==="
dkms status

echo "=== 固件 ==="
dmesg | grep "rtw89.*firmware" | tail -3
EOF
```

预期输出：
```
6.1.84-1-rk2410
wlP2p33s0: <BROADCAST,MULTICAST,UP,LOWER_UP>
rtw_8852be    16384  0
rtw89pci      49152  1 rtw_8852be
rtw89core    425984  2 rtw89pci,rtw_8852be
rtw89/1.0.2+git20231023.207f9eb-1, 6.1.84-1-rk2410, aarch64: installed
rtw89_8852be: loaded firmware rtw89/rtw8852b_fw-1.bin
```

---

## 常见问题排查

### WiFi 不工作

```bash
# 1. 检查 DKMS
dkms status
find /lib/modules/$(uname -r)/updates/ -name "*rtw*"

# 2. 检查 headers
dpkg -l | grep linux-headers-$(uname -r)

# 3. 手动触发 DKMS 编译
sudo dkms install rtw89/1.0.2+git20231023.207f9eb-1 -k $(uname -r)

# 4. 检查 PCI 设备
lspci | grep -i wireless
dmesg | grep rtw89
```

### Patch 应用失败

```bash
# 检查 patch 状态
cd /your/path/to/rk3588-play/bsp
patch -p1 --dry-run < ../rock5t-dev/patches/kernel/0001-disable-bcmdhd.patch

# 手动恢复
patch -R -p1 < ../rock5t-dev/patches/kernel/0001-disable-bcmdhd.patch
```

---

## 关键教训

1. **Rock 5T WiFi 是 Realtek PCIe 芯片**（RTL8852BE），不是 Broadcom SDIO
2. **必须同时安装 image + headers**，否则 DKMS 无法编译驱动
3. **使用 patch 管理自定义配置**，不要直接修改 BSP 源文件
4. **编译后自动恢复 BSP**，保持仓库干净
5. **DKMS 是标准做法**，外部驱动通过 DKMS 安装，不要编译进内核
