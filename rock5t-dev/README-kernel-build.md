# ROCK 5T 内核编译与 RKLLM

## RKLLM 部署

RKLLM 在官方内核 `6.1.84-8-rk2410` 上即可正常工作，**不需要编译自定义内核**。

- RKLLM 使用 DRM_GEM 模式，不需要 `/dev/rknpu` 字符设备
- 不需要修改任何内核驱动

### 验证 RKLLM

```bash
ssh radxa@<BOARD_IP>
cd /home/radxa/rknn-llm/examples/rkllm_api_demo
./deploy/build/llm_demo /home/radxa/qwen2.5-0.5b.rkllm 128 512
```

## 自定义内核编译（按需）

如需自定义内核编译，使用以下脚本：

```bash
cd /your/path/to/rk3588-playground/rock5t-dev
./scripts/build-kernel.sh --clean
```

脚本会自动调用 `radxa-bsp` 的 bsp 工具编译内核，生成 `.deb` 包。

### 注意事项

1. **固定版本号**：脚本使用 `-r 9`，编译版本为 `6.1.84-9`，每次编译覆盖
2. **WiFi 驱动**：ROCK 5T 使用 Realtek RTL8852BE（PCIe），驱动通过 `rtw89-dkms` 外部模块提供
3. **DKMS 依赖**：自定义内核安装后需同时安装 headers，DKMS 才能为该内核编译 WiFi 驱动
4. **板子 IP 动态**：通过 `ping` 扫描或路由器 DHCP 列表查找，不要硬编码
