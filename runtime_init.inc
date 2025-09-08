; runtime_init.inc - NASM include file for runtime library functions
; Contains constants and data for assembly programs
;
; This file provides:
; - Function name strings for dlopen/dlsym operations
; - Tensor allocation mode constants
;
; Usage in assembly programs:
;   Include this file within a data section:
;   section .data
;     %include "runtime_init.inc"
;
;   Then use the constants:
;   mov rsi, cuda_init_name    ; Use function name constant
;   call dlsym                 ; Get function pointer

; Tensor allocation modes
TENSOR_MODE_HOST_DEVICE equ 0
TENSOR_MODE_UNIFIED     equ 1

; Useful constants
NULL equ 0

; Runtime library function name constants (for dlopen/dlsym)
cuda_init_name db 'cuda_init', 0
tensor_alloc_name db 'tensor_alloc', 0
tensor_free_name db 'tensor_free', 0
tensor_get_host_name db 'tensor_get_host', 0
tensor_get_device_name db 'tensor_get_device', 0
tensor_get_size_name db 'tensor_get_size', 0
runtime_memcpy_name db 'runtime_memcpy', 0

; Pthread function name constants
runtime_pthread_mutex_lock_name db 'runtime_pthread_mutex_lock', 0
runtime_pthread_mutex_unlock_name db 'runtime_pthread_mutex_unlock', 0
runtime_pthread_mutex_init_name db 'runtime_pthread_mutex_init', 0
runtime_pthread_mutex_destroy_name db 'runtime_pthread_mutex_destroy', 0
runtime_pthread_once_name db 'runtime_pthread_once', 0
runtime_pthread_key_create_name db 'runtime_pthread_key_create', 0
runtime_pthread_getspecific_name db 'runtime_pthread_getspecific', 0
runtime_pthread_setspecific_name db 'runtime_pthread_setspecific', 0

; Error handling function name constants
runtime___errno_location_name db 'runtime___errno_location', 0
runtime_strerror_name db 'runtime_strerror', 0

; Runtime library name constant
runtime_lib_name db './build/libruntime_init.so', 0
