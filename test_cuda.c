#include <stdio.h>
#include <cuda.h>

int main() {
    CUresult res;
    CUdevice device;
    CUcontext context;
    CUdeviceptr unified_input, unified_output;
    
    // Frame size (same as assembly: 4096 bytes)
    size_t frame_size = 4096;
    
    printf("[D] Initializing CUDA...\n");
    
    // Debug: Print function addresses
    printf("[D] cuCtxCreate function address = 0x%016lX\n", (unsigned long)cuCtxCreate);
    printf("[D] cuMemAlloc function address = 0x%016lX\n", (unsigned long)cuMemAlloc);
    
    // Initialize CUDA driver
    res = cuInit(0);
    printf("[D] cuInit_ret = 0x%08X\n", res);
    if (res != CUDA_SUCCESS) {
        printf("cuInit failed\n");
        return 1;
    }
    
    // Get first device
    res = cuDeviceGet(&device, 0);
    printf("[D] cuDeviceGet_ret = 0x%08X\n", res);
    printf("[D] cuda_device = 0x%08X\n", device);
    if (res != CUDA_SUCCESS) {
        printf("cuDeviceGet failed\n");
        return 1;
    }
    
    // Create context
    res = cuCtxCreate(&context, 0, device);
    printf("[D] cuCtxCreate_ret = 0x%08X\n", res);
    printf("[D] cuda_context = 0x%016lX\n", (unsigned long)context);
    if (res != CUDA_SUCCESS) {
        printf("cuCtxCreate failed\n");
        return 1;
    }
    
    // Set context as current
    res = cuCtxSetCurrent(context);
    printf("[D] cuCtxSetCurrent_ret = 0x%08X\n", res);
    if (res != CUDA_SUCCESS) {
        printf("cuCtxSetCurrent failed\n");
        return 1;
    }
    
    // Get current context to verify
    CUcontext current_ctx;
    res = cuCtxGetCurrent(&current_ctx);
    printf("[D] cuCtxGetCurrent_ret = 0x%08X\n", res);
    printf("[D] current_ctx = 0x%016lX\n", (unsigned long)current_ctx);
    if (res != CUDA_SUCCESS) {
        printf("cuCtxGetCurrent failed\n");
        return 1;
    }
    
    printf("[D] Allocating memory...\n");
    printf("[D] frame_size = 0x%08lX\n", frame_size);
    
    // Try regular device memory allocation first
    res = cuMemAlloc(&unified_input, frame_size);
    printf("[D] cuMemAlloc_ret = 0x%08X\n", res);
    if (res != CUDA_SUCCESS) {
        const char *error_string;
        cuGetErrorString(res, &error_string);
        printf("CUDA Error: %s\n", error_string);
        return 1;
    }
    printf("[D] unified_input = 0x%016lX\n", (unsigned long)unified_input);
    
    // Try unified memory allocation
    res = cuMemAllocManaged(&unified_output, frame_size, CU_MEM_ATTACH_GLOBAL);
    printf("[D] cuMemAllocManaged_ret = 0x%08X\n", res);
    if (res != CUDA_SUCCESS) {
        const char *error_string;
        cuGetErrorString(res, &error_string);
        printf("CUDA Error: %s\n", error_string);
        return 1;
    }
    printf("[D] unified_output = 0x%016lX\n", (unsigned long)unified_output);
    
    printf("[D] Memory allocation successful!\n");
    
    // Cleanup
    cuMemFree(unified_input);
    cuMemFree(unified_output);
    cuCtxDestroy(context);
    
    return 0;
}
