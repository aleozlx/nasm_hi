%include "common.inc"

section .data
    ; CUDA library path and function names for dlopen
    txt_libcuda_so_1 db 'libcuda.so.1', 0
    txt_cuInit db 'cuInit', 0
    txt_cuDeviceGet db 'cuDeviceGet', 0
    txt_cuCtxCreate db 'cuCtxCreate', 0
    txt_cuCtxSetCurrent db 'cuCtxSetCurrent', 0
    txt_cuCtxGetCurrent db 'cuCtxGetCurrent', 0
    txt_cuMemAlloc db 'cuMemAlloc', 0
    txt_cuMemAllocManaged db 'cuMemAllocManaged', 0
    txt_cuMemFree db 'cuMemFree', 0
    txt_cuMemcpyHtoD db 'cuMemcpyHtoD', 0
    txt_cuMemcpyDtoH db 'cuMemcpyDtoH', 0
    txt_cuModuleLoadData db 'cuModuleLoadData', 0
    txt_cuModuleGetFunction db 'cuModuleGetFunction', 0
    txt_cuLaunchKernel db 'cuLaunchKernel', 0
    txt_cuCtxSynchronize db 'cuCtxSynchronize', 0
    txt_cuGetErrorString db 'cuGetErrorString', 0

section .bss
    cuda_lib_handle resq 1
    
    ; CUDA function pointer storage (owned by this module)
    fptr_cuInit resq 1
    fptr_cuDeviceGet resq 1
    fptr_cuCtxCreate resq 1
    fptr_cuCtxSetCurrent resq 1
    fptr_cuCtxGetCurrent resq 1
    fptr_cuMemAlloc resq 1
    fptr_cuMemAllocManaged resq 1
    fptr_cuMemFree resq 1
    fptr_cuMemcpyHtoD resq 1
    fptr_cuMemcpyDtoH resq 1
    fptr_cuModuleLoadData resq 1
    fptr_cuModuleGetFunction resq 1
    fptr_cuLaunchKernel resq 1
    fptr_cuCtxSynchronize resq 1
    fptr_cuGetErrorString resq 1

section .text
    global load_cuda_library
    extern dlopen, dlsym, dlclose
    
    ; Make CUDA string constants global for external use
    global txt_libcuda_so_1
    global txt_cuInit
    global txt_cuDeviceGet
    global txt_cuCtxCreate
    global txt_cuCtxSetCurrent
    global txt_cuCtxGetCurrent
    global txt_cuMemAlloc
    global txt_cuMemAllocManaged
    global txt_cuMemFree
    global txt_cuMemcpyHtoD
    global txt_cuMemcpyDtoH
    global txt_cuModuleLoadData
    global txt_cuModuleGetFunction
    global txt_cuLaunchKernel
    global txt_cuCtxSynchronize
    global txt_cuGetErrorString
    
    ; Make CUDA function pointers global for external use
    global fptr_cuInit
    global fptr_cuDeviceGet
    global fptr_cuCtxCreate
    global fptr_cuCtxSetCurrent
    global fptr_cuCtxGetCurrent
    global fptr_cuMemAlloc
    global fptr_cuMemAllocManaged
    global fptr_cuMemFree
    global fptr_cuMemcpyHtoD
    global fptr_cuMemcpyDtoH
    global fptr_cuModuleLoadData
    global fptr_cuModuleGetFunction
    global fptr_cuLaunchKernel
    global fptr_cuCtxSynchronize
    global fptr_cuGetErrorString

; Load CUDA library and resolve all function pointers
; No parameters needed - populates global fptr_* variables directly
; Returns: rax = 1 on success, 0 on failure
load_cuda_library:
    push rbp
    mov rbp, rsp
    
    ; Load the CUDA library
    mov rdi, txt_libcuda_so_1
    mov rsi, 1                  ; RTLD_LAZY
    call dlopen
    test rax, rax
    jz .load_failed
    mov [cuda_lib_handle], rax
    
    ; Get cuInit function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuInit
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuInit], rax
    
    ; Get cuDeviceGet function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuDeviceGet
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuDeviceGet], rax
    
    ; Get cuCtxCreate function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuCtxCreate
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuCtxCreate], rax
    
    ; Get cuCtxSetCurrent function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuCtxSetCurrent
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuCtxSetCurrent], rax
    
    ; Get cuCtxGetCurrent function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuCtxGetCurrent
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuCtxGetCurrent], rax
    
    ; Get cuMemAlloc function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuMemAlloc
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuMemAlloc], rax
    
    ; Get cuMemAllocManaged function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuMemAllocManaged
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuMemAllocManaged], rax
    
    ; Get cuMemFree function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuMemFree
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuMemFree], rax
    
    ; Get cuMemcpyHtoD function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuMemcpyHtoD
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuMemcpyHtoD], rax
    
    ; Get cuMemcpyDtoH function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuMemcpyDtoH
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuMemcpyDtoH], rax
    
    ; Get cuModuleLoadData function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuModuleLoadData
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuModuleLoadData], rax
    
    ; Get cuModuleGetFunction function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuModuleGetFunction
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuModuleGetFunction], rax
    
    ; Get cuLaunchKernel function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuLaunchKernel
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuLaunchKernel], rax
    
    ; Get cuCtxSynchronize function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuCtxSynchronize
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuCtxSynchronize], rax
    
    ; Get cuGetErrorString function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, txt_cuGetErrorString
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [fptr_cuGetErrorString], rax
    
    ; Success
    mov rax, 1
    jmp .done
    
.symbol_failed:
    ; Close library on symbol resolution failure
    mov rdi, [cuda_lib_handle]
    call dlclose
    
.load_failed:
    mov rax, 0
    
.done:
    pop rbp
    ret
