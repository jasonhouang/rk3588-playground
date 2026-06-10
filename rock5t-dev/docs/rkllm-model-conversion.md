# RKLLM Model Conversion Guide

## Environment Setup

```bash
conda create -n rkllm python=3.10
conda activate rkllm
pip install torch transformers
# Install rkllm-toolkit from BSP wheel
pip install rkllm_toolkit-1.2.3-cp310-cp310-linux_x86_64.whl
```

## Conversion Workflow

### Step 1: Download Model

```bash
python -c "
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id='Qwen/Qwen2.5-1.5B-Instruct',
    local_dir='/tmp/qwen2.5-1.5b-instruct'
)
"
```

### Step 2: Convert to RKLLM

```bash
python scripts/convert_to_rkllm.py \
    /tmp/qwen2.5-1.5b-instruct \
    ~/qwen2.5-1.5b-instruct-rk3588.rkllm
```

### Step 3: Upload to Board

```bash
scp ~/qwen2.5-1.5b-instruct-rk3588.rkllm radxa@<IP>:/home/radxa/
```

## Board Benchmark

```bash
# Set max frequencies
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
sudo sh -c 'echo 1000000000 > /sys/class/devfreq/fdab0000.npu/max_freq'

# Run benchmark
g++ -o bench bench.c -lrkllmrt
./bench /home/radxa/model.rkllm "test prompt"
```

## Notes

1. RKLLM works on stock kernel (DRM_GEM mode) — no driver patches needed
2. Model conversion must run on x86_64 host (toolkit doesn't support ARM)
3. Conversion requires ~8GB RAM and ~10 minutes
4. W8A8 quantization recommended for RK3588 NPU
