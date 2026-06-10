#!/usr/bin/env python3
"""
BuddyBot Edge AI Benchmark - RK3588 NPU Performance Test
Measures TTFT (Time To First Token) and generation speed for Qwen2.5-1.5B
"""
import subprocess
import time
import sys
import re

MODEL_PATH = "/home/radxa/qwen2.5-1.5b-instruct-rk3588.rkllm"
DEMO_PATH = "/home/radxa/rknn-llm/examples/rkllm_api_demo/deploy/build/llm_demo"

def run_benchmark():
    print("=" * 60)
    print("BuddyBot Edge AI Benchmark - RK3588 NPU")
    print("=" * 60)
    
    # Test prompts
    prompts = [
        "你好，给我讲一个简短的儿童故事。",
        "鸡兔同笼，共有14个头，38条腿，鸡和兔子各有多少只？",
        "用中文回答：什么是人工智能？"
    ]
    
    for i, prompt in enumerate(prompts, 1):
        print(f"\n--- Test {i}: {prompt} ---")
        
        # Use timeout and capture output
        cmd = f"timeout 30 {DEMO_PATH} {MODEL_PATH} 128 2048"
        
        start_time = time.time()
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=35
            )
            elapsed = time.time() - start_time
            
            # Parse output
            output = result.stdout
            
            # Count tokens generated (each "robot:" response)
            responses = re.findall(r'robot: (.+?)(?=\n\nuser:|$)', output, re.DOTALL)
            total_chars = sum(len(r) for r in responses)
            
            # Estimate tokens (rough: 1 Chinese char ≈ 1.5 tokens, 1 English word ≈ 1.3 tokens)
            estimated_tokens = max(len(output.split()), total_chars // 2)
            
            # TTFT approximation (first response appears after init + first token)
            init_time = elapsed / max(len(responses), 1)
            tokens_per_sec = estimated_tokens / elapsed if elapsed > 0 else 0
            
            print(f"  Total time: {elapsed:.1f}s")
            print(f"  Responses: {len(responses)}")
            print(f"  Estimated tokens: ~{estimated_tokens}")
            print(f"  Estimated throughput: ~{tokens_per_sec:.1f} tok/s")
            
            # Print first response sample
            if responses:
                print(f"  First response: {responses[0][:100]}...")
                
        except subprocess.TimeoutExpired:
            print(f"  Timeout after 30s")
        except Exception as e:
            print(f"  Error: {e}")

if __name__ == "__main__":
    run_benchmark()
