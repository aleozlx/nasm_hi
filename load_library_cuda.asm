%include "common.inc"

section .data
dbg_launch:
    dbg_launch_bdim db "bdim:["
    dbg_launch_bdim_x db "0000 "
    dbg_launch_bdim_y db "0000 "
    dbg_launch_bdim_z db "0000] "
    dbg_launch_gdim db "gdim:["
    dbg_launch_gdim_x db "00000 "
    dbg_launch_gdim_y db "00000 "
    dbg_launch_gdim_z db "00000] "
    dbg_launch_smem db "smem:"
    dbg_launch_smem_value db "0x00000000 "
    dbg_launch_stream db "stream:"
    dbg_launch_stream_value db "0x00000000 "
    dbg_launch_params db "params:"
    dbg_launch_params_value db "0x0000000000000000 ", 0xA, 0

section .rodata
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

    extern hex_chars

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
    global log_kernel_launch
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

; Convert integer to string with fixed width
; Input: rax = value to convert, rbx = output_string, r12w = base:pad_char, r13 = bytes to output
; clobbers: rax, r10, r11
itoa_fixed_width:
    push rdx
    mov r11, r13  ; preserve r13
    add rbx, r13  ; move to end of string

    xor r10, r10
    mov r10w, r12w
    shr r10w, 8

.loop:
    dec rbx
    xor rdx, rdx
    div r10
    or dl, 0x30
    cmp dl, '9'
    jbe .is_digit
    add dl, 'a' - '0' - 0xA
.is_digit:
    mov [rbx], dl
    dec r11
    test r11, r11
    jz .done
    test rax, rax
    jnz .loop

.loop_pad:
    dec rbx
    mov byte [rbx], r12b
    dec r11
    test r11, r11
    jnz .loop_pad

.done:
    pop rdx
    ; note rbx returns to the original position
    ret

; Input: entire C call convention arg0 - arg10
; Clobbers: nothing
log_kernel_launch:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push r12
    push r13

    .blockZ equ 16
    .sharedMem equ 24
    .stream equ 32
    .params equ 40
    .extra equ 48

    ; cuLaunchKernel parameters: 
    ; registers: f, gridX, gridY, gridZ, blockX, blockY, 
    mov r12, (10 << 8) | 0x20  ; base10:pad_space
    mov r13, 5                 ; fixed width

    mov rax, rsi ; gridX
    mov rbx, dbg_launch_gdim_x
    call itoa_fixed_width

    mov rax, rdx ; gridY
    mov rbx, dbg_launch_gdim_y
    call itoa_fixed_width

    mov rax, rcx ; gridZ
    mov rbx, dbg_launch_gdim_z
    call itoa_fixed_width

    mov r13, 4  ; fixed width
    mov rax, r8 ; blockX
    mov rbx, dbg_launch_bdim_x
    call itoa_fixed_width

    mov rax, r9 ; blockY
    mov rbx, dbg_launch_bdim_y
    call itoa_fixed_width

    ; stack: blockZ, sharedMem, stream, params, extra
    ; movdqa xmm0, [rbp + .blockZ]
    ; movdqa xmm1, [rbp + .stream]
    ; movdqa xmm2, [rbp + .extra]
    mov rax, [rbp + .blockZ] ; blockZ
    mov rbx, dbg_launch_bdim_z
    call itoa_fixed_width

    mov r12, (16 << 8) | '0'  ; base16:pad_0
    mov r13, 8                 ; fixed width
    mov rax, [rbp + .sharedMem]  ; sharedMem
    lea rbx, [dbg_launch_smem_value + 2]
    call itoa_fixed_width

    mov rax, [rbp + .stream] ; stream
    lea rbx, [dbg_launch_stream_value + 2]
    call itoa_fixed_width

    mov r13, 16  ; fixed width
    mov rax, [rbp + .params] ; params
    lea rbx, [dbg_launch_params_value + 2]
    call itoa_fixed_width
   
    push rsi
    mov rsi, dbg_launch
    call log_message
    pop rsi

.done:
    pop r13
    pop r12
    pop rbx
    pop rax
    mov rsp, rbp
    pop rbp
    ret
