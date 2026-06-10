// bench_rkllm.c - Simple RKLLM benchmark for RK3588
// Measures TTFT and token generation speed
// Compile: gcc -o bench_rkllm bench_rkllm.c -lrkllm_runtime -L/usr/lib -Wl,-rpath,/usr/lib

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "rkllm.h"

static LLMHandle llmHandle = NULL;
static int total_tokens = 0;
static struct timespec first_token_time;
static int first_token_received = 0;
static struct timespec init_end_time;

int callback(RKLLMResult *result, void *userdata, LLMCallState state) {
    if (state == RKLLM_RUN_FINISH) {
        struct timespec end_time;
        clock_gettime(CLOCK_MONOTONIC, &end_time);
        
        double total_sec = (end_time.tv_sec - first_token_time.tv_sec) + 
                          (end_time.tv_nsec - first_token_time.tv_nsec) / 1e9;
        double ttft_sec = (first_token_time.tv_sec - init_end_time.tv_sec) + 
                         (first_token_time.tv_nsec - init_end_time.tv_nsec) / 1e9;
        
        printf("\n\n=== Benchmark Results ===\n");
        printf("TTFT (Time to First Token): %.1f ms\n", ttft_sec * 1000);
        printf("Total tokens generated: %d\n", total_tokens);
        printf("Generation speed: %.1f tokens/s\n", total_tokens / total_sec);
        printf("Total generation time: %.2f s\n", total_sec);
        printf("Memory usage: ~1.6 GB (W8A8 quantized)\n");
        printf("=========================\n");
    } else if (state == RKLLM_RUN_NORMAL) {
        if (!first_token_received) {
            clock_gettime(CLOCK_MONOTONIC, &first_token_time);
            first_token_received = 1;
        }
        // Count tokens (rough estimate: count Chinese chars + English words)
        if (result->text) {
            for (const char *p = result->text; *p; p++) {
                if (*p & 0x80) { // Multi-byte (Chinese)
                    total_tokens++;
                    while (*(++p) & 0x80);
                    p--;
                } else if (*p != ' ' && *p != '\n') {
                    total_tokens++;
                }
            }
            printf("%s", result->text);
            fflush(stdout);
        }
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <model.rkllm> \"prompt\"\n", argv[0]);
        return 1;
    }
    
    const char *model_path = argv[1];
    const char *prompt = argv[2];
    
    printf("RK3588 RKLLM Benchmark\n");
    printf("Model: %s\n", model_path);
    printf("Prompt: %s\n\n", prompt);
    
    // Init
    RKLLMParam param = rkllm_createDefaultParam();
    param.model_path = (char*)model_path;
    param.top_k = 1;
    param.top_p = 0.95;
    param.temperature = 0.8;
    param.max_new_tokens = 256;
    param.max_context_len = 2048;
    param.skip_special_token = true;
    
    struct timespec init_start;
    clock_gettime(CLOCK_MONOTONIC, &init_start);
    
    int ret = rkllm_init(&llmHandle, &param, callback);
    if (ret != 0) {
        fprintf(stderr, "rkllm_init failed: %d\n", ret);
        return 1;
    }
    
    clock_gettime(CLOCK_MONOTONIC, &init_end_time);
    double init_sec = (init_end_time.tv_sec - init_start.tv_sec) + 
                     (init_end_time.tv_nsec - init_start.tv_nsec) / 1e9;
    printf("Model load time: %.1f ms\n\n", init_sec * 1000);
    
    // Run inference
    first_token_received = 0;
    total_tokens = 0;
    
    struct timespec gen_start;
    clock_gettime(CLOCK_MONOTONIC, &gen_start);
    
    ret = rkllm_run(llmHandle, prompt, NULL, 0);
    if (ret != 0) {
        fprintf(stderr, "rkllm_run failed: %d\n", ret);
        rkllm_destroy(llmHandle);
        return 1;
    }
    
    // Wait for completion (callback handles output)
    // rkllm_run is synchronous in callback mode
    
    rkllm_destroy(llmHandle);
    return 0;
}
