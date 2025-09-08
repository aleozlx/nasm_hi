#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdint.h>
#include <limits.h>

// CUDA Driver API headers
#include <cuda.h>


// Wrapper function for logging variables (pure C implementation)
void log_debug_var(const char* name, int64_t value) {
    // Use appropriate format based on value size
    if (value >= 0 && value <= INT32_MAX) {
        fprintf(stderr, "[D] %s = 0x%08x\n", name, (uint32_t)value);
    } else {
        fprintf(stderr, "[D] %s = 0x%016llx\n", name, (unsigned long long)value);
    }
}

/*
// Original assembly implementation (commented out):
void log_debug_var(const char* name, int64_t value) {
    // Determine byte count from value range
    int bytes = (value >= 0 && value <= INT32_MAX) ? 4 : 8;

    // Convert value to hex and log debug message using assembly functions
    __asm__ volatile (
        "mov rdi, %0\n"
        "mov rcx, %1\n"
        "call convert_rdi_hex\n"
        "mov rsi, %2\n"
        "call log_debug"
        :
        : "r"((unsigned long long)value), "r"((unsigned long long)bytes), "r"(name)
        : "rdi", "rcx", "rax", "rbx", "rsi", "rdx"
    );
}
*/




// Syscall constants for direct logging
#define sys_write 1
#define fd_stderr 2
#define debug_cuda_len (sizeof("[D] Initializing CUDA...\n") - 1)

// CUDA error checking macro (pure C implementation)
// Usage: CUresult result = cuda_function(...);
//        chk_cuda(result);  // checks result and exits on error
#define chk_cuda(result) \
    do { \
        CUresult res = (result); \
        if (res != CUDA_SUCCESS) { \
            fprintf(stderr, "CUDA Error: %d\n", res); \
            exit(1); \
        } \
    } while (0)

/*
// Original assembly implementation (commented out):
#define chk_cuda(result) \
    do { \
        __asm__ volatile( \
            "mov rax, %0\n" \
            "test rax, rax\n" \
            "jnz abort_cuda" \
            : \
            : "r"((unsigned long long)(result)) \
            : "rax", "rdi" \
        ); \
    } while (0)
*/

// Global CUDA state
static CUcontext cuda_context = NULL;
static CUdevice cuda_device = 0;
static int cuda_initialized = 0;

// Tensor allocation modes
#define TENSOR_MODE_HOST_DEVICE 0
#define TENSOR_MODE_UNIFIED     1

// Tensor structure for host+device mode
typedef struct {
    void* host_ptr;
    CUdeviceptr device_ptr;
    size_t size;
} tensor_pair_t;

// Utility function to set up CUDA context
// Returns 0 on success, non-zero on failure
int cuda_init(void) {
    if (cuda_initialized) return 0;

    CUresult result;

    // Initialize CUDA Driver API
    result = cuInit(0);
    chk_cuda(result);

    // cuDeviceGet(&cuda_device, 0)
    result = cuDeviceGet(&cuda_device, 0);
    chk_cuda(result);

    // Debug: Print device ID
    log_debug_var("cuda_device", cuda_device);

    // Create CUDA context
    result = cuCtxCreate(&cuda_context, 0, cuda_device);
    chk_cuda(result);

    // Debug: Print context pointer
    log_debug_var("cuda_context", (int64_t)cuda_context);

    // Set the context as current for this thread
    result = cuCtxSetCurrent(cuda_context);
    chk_cuda(result);

    cuda_initialized = 1;
    return 0;
}

// Utility function to allocate tensors with 256-byte alignment for TMA access
// mode: 0 = host+device, 1 = unified memory
// Returns pointer to allocated memory, or NULL on failure
void* tensor_alloc(size_t size, int mode) {
    if (!cuda_initialized) {
        if (cuda_init() != 0) {
            return NULL;
        }
    }

    // Ensure 256-byte alignment for TMA access
    size_t aligned_size = (size + 255) & ~255;

    if (mode == TENSOR_MODE_HOST_DEVICE) {
        // Allocate host and device memory separately
        tensor_pair_t* tensor = (tensor_pair_t*)malloc(sizeof(tensor_pair_t));
        if (!tensor) {
            return NULL;
        }

        // Allocate host memory with alignment
        tensor->host_ptr = aligned_alloc(256, aligned_size);
        if (!tensor->host_ptr) {
            free(tensor);
            return NULL;
        }

        // Allocate device memory
        CUresult result = cuMemAlloc(&tensor->device_ptr, aligned_size);
        chk_cuda(result);

        tensor->size = aligned_size;
        return (void*)tensor;

    } else if (mode == TENSOR_MODE_UNIFIED) {
        // Allocate unified memory
        CUdeviceptr ptr;
        CUresult result = cuMemAllocManaged(&ptr, aligned_size, CU_MEM_ATTACH_GLOBAL);
        chk_cuda(result);
        return (void*)ptr;
    }

    return NULL;
}

// Free tensor allocated with tensor_alloc
void tensor_free(void* ptr, int mode) {
    if (!ptr) return;

    if (mode == TENSOR_MODE_HOST_DEVICE) {
        tensor_pair_t* tensor = (tensor_pair_t*)ptr;
        if (tensor->host_ptr) {
            free(tensor->host_ptr);
        }
        if (tensor->device_ptr) {
            cuMemFree(tensor->device_ptr);
        }
        free(tensor);
    } else if (mode == TENSOR_MODE_UNIFIED) {
        cuMemFree((CUdeviceptr)ptr);
    }
}

// Get host pointer from tensor (only for host+device mode)
void* tensor_get_host(void* tensor_ptr) {
    if (!tensor_ptr) return NULL;
    return ((tensor_pair_t*)tensor_ptr)->host_ptr;
}

// Get device pointer from tensor (only for host+device mode)
CUdeviceptr tensor_get_device(void* tensor_ptr) {
    if (!tensor_ptr) return 0;
    return ((tensor_pair_t*)tensor_ptr)->device_ptr;
}

// Get size of tensor
size_t tensor_get_size(void* tensor_ptr, int mode) {
    if (!tensor_ptr) return 0;

    if (mode == TENSOR_MODE_HOST_DEVICE) {
        return ((tensor_pair_t*)tensor_ptr)->size;
    } else if (mode == TENSOR_MODE_UNIFIED) {
        // For unified memory, we can't easily track size, return 0
        // User should track size separately
        return 0;
    }
    return 0;
}

// Memory management functions (wrapping standard C library)
void* runtime_malloc(size_t size) {
    return malloc(size);
}

void runtime_free(void* ptr) {
    free(ptr);
}

void* runtime_memcpy(void* dest, const void* src, size_t n) {
    return memcpy(dest, src, n);
}

// Pthread implementations that CUDA needs
int runtime_pthread_mutex_lock(pthread_mutex_t* mutex) {
    return pthread_mutex_lock(mutex);
}

int runtime_pthread_mutex_unlock(pthread_mutex_t* mutex) {
    return pthread_mutex_unlock(mutex);
}

int runtime_pthread_mutex_init(pthread_mutex_t* mutex, const pthread_mutexattr_t* attr) {
    return pthread_mutex_init(mutex, attr);
}

int runtime_pthread_mutex_destroy(pthread_mutex_t* mutex) {
    return pthread_mutex_destroy(mutex);
}

int runtime_pthread_once(pthread_once_t* once_control, void (*init_routine)(void)) {
    return pthread_once(once_control, init_routine);
}

int runtime_pthread_key_create(pthread_key_t* key, void (*destructor)(void*)) {
    return pthread_key_create(key, destructor);
}

void* runtime_pthread_getspecific(pthread_key_t key) {
    return pthread_getspecific(key);
}

int runtime_pthread_setspecific(pthread_key_t key, const void* value) {
    return pthread_setspecific(key, value);
}

// Error handling
int* runtime___errno_location(void) {
    return __errno_location();
}

char* runtime_strerror(int errnum) {
    return strerror(errnum);
}

// Constructor to initialize when library loads
__attribute__((constructor))
void runtime_constructor() {
    // CUDA initialization will be done on-demand in cuda_init()
    // No additional initialization needed here
}

// Destructor to cleanup when library unloads
__attribute__((destructor))
void runtime_destructor() {
    // Cleanup CUDA resources
    if (cuda_context != NULL) {
        cuCtxDestroy(cuda_context);
        cuda_context = NULL;
    }
    cuda_initialized = 0;
}
