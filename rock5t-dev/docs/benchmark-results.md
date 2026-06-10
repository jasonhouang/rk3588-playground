# RK3588 Edge AI 基准测试结果

> **测试日期**: 2026-06-10
> **硬件**: Radxa ROCK 5T (RK3588, 16GB RAM)
> **内核**: 6.1.84-8-rk2410 (官方内核, DRM_GEM 模式)
> **模型**: Qwen2.5-1.5B-Instruct (W8A8 量化, rkllm-toolkit 1.2.3)
> **NPU**: 3 核心 @ 1.0GHz
> **CPU**: 大核 @ performance governor

## 测试数据

### 测试 1：故事生成
- **Prompt**: "你好，给我讲一个简短的儿童故事"
- **TTFT**: 273 ms
- **生成 Tokens**: 233
- **生成速度**: 15.5 tok/s
- **总耗时**: 15.1 s
- **模型加载**: 2.9 s

### 测试 2：数学推理
- **Prompt**: "鸡兔同笼，共有14个头38条腿，鸡和兔子各有多少只？请给出计算过程。"
- **TTFT**: 275 ms
- **生成 Tokens**: 251
- **生成速度**: 15.2 tok/s
- **总耗时**: 16.5 s
- **模型加载**: 2.7 s

### 测试 3：知识问答
- **Prompt**: "用中文简单解释：什么是人工智能？"
- **TTFT**: 162 ms
- **生成 Tokens**: 120
- **生成速度**: 18.6 tok/s
- **总耗时**: 6.5 s
- **模型加载**: 2.8 s

## 平均值

| 指标 | 均值 |
|------|------|
| TTFT (首字延迟) | **~237 ms** |
| 生成速度 | **~16.4 tok/s** |
| 模型加载 | **~2.8 s** |
| 内存占用 | **~1.6 GB** |

## 与官方 Benchmark 对比

| 指标 | 官方数据 | 实测数据 | 差异 |
|------|---------|---------|------|
| TTFT | 412 ms | ~237 ms | ✅ 快 43% |
| Tokens/s | 16.32 | ~16.4 | ✅ 基本一致 |
| Memory | 1659 MB | ~1600 MB | ✅ 基本一致 |

## 完整语音管线延迟估算

基于实测数据推算 BuddyBot 语音交互延迟：

| 阶段 | 延迟 | 说明 |
|------|------|------|
| KWS (关键词检测) | ~200ms | 本地轻量级模型 (Porcupine/Snowboy) |
| ASR (语音识别) | ~300ms | SenseVoice / Whisper (本地) |
| LLM TTFT (首字) | ~240ms | 实测均值 |
| LLM 生成 (50字) | ~3.1s | 16 tok/s × ~50 tokens |
| TTS (语音合成) | ~200ms | Edge TTS / CosyVoice |
| **端到端首响应** | **~740ms** | KWS + ASR + LLM TTFT |
| **完整交互** | **~3.8s** | 端到端首响应 + 生成 + TTS |

## 结论

1. ✅ **TTFT 优于预期**：实测 237ms，低于目标 400ms
2. ✅ **生成速度达标**：16.4 tok/s，满足儿童对话场景需求
3. ✅ **内存可控**：1.6GB，16GB RAM 的 ROCK 5T 有足够余量
4. ✅ **端到端延迟 < 1s**：740ms，儿童交互体验流畅
5. ✅ **官方内核兼容**：不需要自定义内核，DRM_GEM 模式正常工作

## 测试工具

基准测试脚本：`rock5t-dev/scripts/bench_rkllm.c`
编译命令：
```bash
g++ -o bench bench.c -lrkllmrt
./bench /path/to/model.rkllm "测试 prompt"
```

## 注意事项

- 测试时 CPU governor 设为 `performance`，NPU 频率锁定 1.0GHz
- 实际产品中 KWS/ASR/TTS 可能与 LLM 并行运行，端到端延迟可进一步优化
- W8A8 量化在 RK3588 NPU 上性能最佳，W4A16 会慢约 2x
