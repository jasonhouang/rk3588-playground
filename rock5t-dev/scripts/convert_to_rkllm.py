#!/usr/bin/env python3
"""
Convert HuggingFace LLM to RKLLM format for RK3588 deployment.

Usage:
    python convert_to_rkllm.py <huggingface_model_path> <output.rkllm>

Example:
    python convert_to_rkllm.py /tmp/qwen2.5-1.5b-instruct ~/qwen2.5-1.5b-instruct-rk3588.rkllm

Requires: rkllm conda environment with rkllm-toolkit installed.
    conda activate rkllm
    pip install rkllm-toolkit (or install from BSP wheel)
"""
import os
import sys

if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} <model_path> <output.rkllm>")
    print(f"  model_path: Path to HuggingFace model directory")
    print(f"  output.rkllm: Output RKLLM model file path")
    sys.exit(1)

MODEL_PATH = sys.argv[1]
OUTPUT_PATH = sys.argv[2]

if not os.path.isdir(MODEL_PATH):
    print(f"ERROR: Model directory not found: {MODEL_PATH}")
    sys.exit(1)

from rkllm.api import RKLLM

print(f"Loading model from: {MODEL_PATH}")
print(f"Output: {OUTPUT_PATH}")

rkllm = RKLLM()

# Load model from local HuggingFace directory
rkllm.load_huggingface(
    model=MODEL_PATH,
    dtype="float32"  # CPU only supports float32
)

# Build and quantize for RK3588 NPU
rkllm.build(
    do_quantization=True,
    quantized_dtype="w8a8",       # 8-bit weights and activations
    quantized_algorithm="normal", # Standard quantization (or "awq" for better accuracy)
    target_platform="rk3588",
    num_npu_core=3,               # Use all 3 NPU cores
    max_context=4096,             # Maximum context length
    optimization_level=1          # 0=debug, 1=balanced, 2=aggressive
)

# Export to .rkllm format
rkllm.export_rkllm(OUTPUT_PATH)
print(f"\u2705 Model exported to {OUTPUT_PATH}")
print(f"   Size: {os.path.getsize(OUTPUT_PATH) / (1024**3):.1f} GB")
