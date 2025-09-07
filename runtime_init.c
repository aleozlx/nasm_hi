#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/mman.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>

// Global state
static int heap_initialized = 0;
static pthread_mutex_t init_mutex = PTHREAD_MUTEX_INITIALIZER;
static void* heap_start = NULL;
static size_t heap_size = 0;
static void* heap_current = NULL;

// Simple heap implementation using mmap
static int initialize_heap() {
    if (heap_initialized) return 0;
    
    heap_size = 64 * 1024 * 1024; // 64MB heap
    heap_start = mmap(NULL, heap_size, 
                     PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    
    if (heap_start == MAP_FAILED) {
        return -1;
    }
    
    heap_current = heap_start;
    heap_initialized = 1;
    return 0;
}

// Export these symbols for your NASM program
void* runtime_malloc(size_t size) {
    pthread_mutex_lock(&init_mutex);
    
    if (!heap_initialized) {
        if (initialize_heap() != 0) {
            pthread_mutex_unlock(&init_mutex);
            return NULL;
        }
    }
    
    // Simple bump allocator (for demonstration)
    // In production, you'd want a proper allocator
    if ((char*)heap_current + size > (char*)heap_start + heap_size) {
        pthread_mutex_unlock(&init_mutex);
        return NULL; // Out of memory
    }
    
    void* result = heap_current;
    heap_current = (char*)heap_current + ((size + 7) & ~7); // 8-byte align
    
    pthread_mutex_unlock(&init_mutex);
    return result;
}

void runtime_free(void* ptr) {
    // Simple allocator doesn't support free
    // In production, implement proper free list
    (void)ptr;
}

void* runtime_memcpy(void* dest, const void* src, size_t n) {
    char* d = (char*)dest;
    const char* s = (const char*)src;
    
    for (size_t i = 0; i < n; i++) {
        d[i] = s[i];
    }
    
    return dest;
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
    // Initialize mutex is already statically initialized
    // Additional initialization can go here
}

// Destructor to cleanup when library unloads
__attribute__((destructor))
void runtime_destructor() {
    if (heap_initialized && heap_start != NULL) {
        munmap(heap_start, heap_size);
    }
}
