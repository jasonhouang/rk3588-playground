# RK3588 Edge AI Benchmark Results

> **Date**: 2026-06-10
> **Hardware**: Radxa ROCK 5T (RK3588, 16GB RAM)
> **Kernel**: 6.1.84-8-rk2410 (stock, DRM_GEM mode)
> **Model**: Qwen2.5-1.5B-Instruct (W8A8, rkllm-toolkit 1.2.3)
> **NPU**: 3 cores @ 1.0GHz
> **CPU**: big cores @ performance governor

## Test Results

### Test 1: Story Generation
- **Prompt**: "你好，给我讲一个简短的儿童故事"
- **TTFT**: 273 ms
- **Tokens**: 233
- **Speed**: 15.5 tok/s
- **Duration**: 15.1 s
- **Model Load**: 2.9 s

### Test 2: Math Reasoning
- **Prompt**: "鸡兔同笼，共有14个头38条腿，鸡和兔子各有多少只？请给出计算过程。"
- **TTFT**: 275 ms
- **Tokens**: 251
- **Speed**: 15.2 tok/s
- **Duration**: 16.5 s
- **Model Load**: 2.7 s

### Test 3: Knowledge QA
- **Prompt**: "用中文简单解释：什么是人工智能？"
- **TTFT**: 162 ms
- **Tokens**: 120
- **Speed**: 18.6 tok/s
- **Duration**: 6.5 s
- **Model Load**: 2.8 s

## Summary

| Metric | Average |
|--------|---------|
| TTFT | **~237 ms** |
| Throughput | **~16.4 tok/s** |
| Model Load | **~2.8 s** |
| Memory | **~1.6 GB** |

## vs Official Benchmark

| Metric | Official | Measured | Delta |
|--------|----------|----------|-------|
| TTFT | 412 ms | ~237 ms | ✅ 43% faster |
| Tokens/s | 16.32 | ~16.4 | ✅ Matches |
| Memory | 1659 MB | ~1600 MB | ✅ Matches |

## Test Tool

Benchmark source: `rock5t-dev/scripts/bench_rkllm.c`

```bash
g++ -o bench bench.c -lrkllmrt
./bench /path/to/model.rkllm "test prompt"
```

## Notes

- CPU governor set to `performance`, NPU locked at 1.0GHz
- W8A8 quantization performs best on RK3588 NPU; W4A16 is ~2x slower
- Stock kernel DRM_GEM mode is fully compatible with RKLLM — no driver patches needed
