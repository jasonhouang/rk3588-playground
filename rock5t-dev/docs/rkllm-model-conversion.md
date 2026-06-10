# RK3588 RKLLM 模型转换与基准测试

## 环境准备

```bash
# 1. 安装 rkllm conda 环境
conda create -n rkllm python=3.10
conda activate rkllm
pip install torch transformers

# 2. 安装 rkllm-toolkit（从板子上获取 wheel）
# 从板子复制：
# scp radxa@<BOARD_IP>:/home/radxa/rknn-llm/rkllm-toolkit/packages/rkllm_toolkit-1.2.3-cp310-cp310-linux_x86_64.whl /tmp/
pip install /tmp/rkllm_toolkit-1.2.3-cp310-cp310-linux_x86_64.whl
```

## 模型转换流程

### Step 1: 下载 HuggingFace 模型

```bash
conda activate rkllm
python -c "
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id='Qwen/Qwen2.5-1.5B-Instruct',
    local_dir='/tmp/qwen2.5-1.5b-instruct'
)
"
```

### Step 2: 转换为 RKLLM 格式

```bash
python scripts/convert_to_rkllm.py \
    /tmp/qwen2.5-1.5b-instruct \
    ~/qwen2.5-1.5b-instruct-rk3588.rkllm
```

转换参数说明：
- `quantized_dtype`: `w8a8`（8-bit 权和激活，RK3588 NPU 最佳性能）
- `quantized_algorithm`: `normal`（标准量化）或 `awq`（更高质量）
- `num_npu_core`: 3（RK3588 有 3 个 NPU 核心）
- `max_context`: 4096（最大上下文长度）
- `optimization_level`: 1（平衡模式，0=调试，2=激进优化）

### Step 3: 上传到板子

```bash
scp ~/qwen2.5-1.5b-instruct-rk3588.rkllm radxa@<BOARD_IP>:/home/radxa/
```

## 板子上运行基准测试

```bash
ssh radxa@<BOARD_IP>

# 设置 CPU 频率为最高
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# 设置 NPU 频率为最高
sudo sh -c 'echo 1000000000 > /sys/class/devfreq/fdab0000.npu/max_freq'
sudo sh -c 'echo 1000000000 > /sys/class/devfreq/fdab0000.npu/min_freq'

# 运行 RKLLM demo
cd /home/radxa/rknn-llm/examples/rkllm_api_demo
timeout 60 ./deploy/build/llm_demo \
    /home/radxa/qwen2.5-1.5b-instruct-rk3588.rkllm \
    256 2048
```

## 预期性能指标（RK3588）

根据官方 benchmark 数据：

| 模型 | 量化 | TTFT(ms) | Tokens/s | 内存(MB) |
|------|------|----------|----------|----------|
| Qwen2.5 1.5B | w8a8 | 412 | 16.32 | 1659 |
| Qwen2.5 0.5B | w8a8 | 144 | 42.58 | 654 |

## 完整语音管线延迟估算

基于 benchmark 数据：

| 阶段 | 延迟 | 说明 |
|------|------|------|
| KWS (关键词检测) | ~200ms | 本地轻量级模型 |
| ASR (语音识别) | ~300ms | SenseVoice / Whisper |
| LLM (推理首字) | ~400ms | TTFT |
| LLM (生成 50 字) | ~3s | 16 tok/s × 50 tokens |
| TTS (语音合成) | ~200ms | Edge TTS / CosyVoice |
| **端到端首响应** | **~1.1s** | KWS + ASR + LLM TTFT |

## 注意事项

1. **RKLLM 在官方内核上正常工作**，不需要自定义内核驱动修改
2. 官方内核 `6.1.84-8-rk2410` 使用 DRM_GEM 模式，RKLLM 兼容
3. `/dev/rknpu` 字符设备不是必须的
4. 模型转换必须在 x86_64 主机上进行（RKLLM toolkit 不支持 ARM）
5. 转换过程需要 ~8GB 内存和 ~10 分钟
