section .data
    usage_msg db 'Usage: sobel_runner0 <width> <height>', 0xA, 0
    usage_len equ $ - usage_msg - 1
    
    cuda_error_msg db 'CUDA Error: ', 0
    cuda_error_len equ $ - cuda_error_msg - 1
    
    cuda_init_error_msg db 'CUDA Init Error', 0xA, 0
    cuda_init_error_len equ $ - cuda_init_error_msg - 1
    
    cuda_alloc_error_msg db 'CUDA Memory Allocation Error', 0xA, 0
    cuda_alloc_error_len equ $ - cuda_alloc_error_msg - 1
    
    cuda_module_error_msg db 'CUDA Module Loading Error', 0xA, 0
    cuda_module_error_len equ $ - cuda_module_error_msg - 1
    
    file_error_msg db 'PTX File Error', 0xA, 0
    file_error_len equ $ - file_error_msg - 1
    
    memory_error_msg db 'Memory allocation failed', 0xA, 0
    memory_error_len equ $ - memory_error_msg - 1
    
    ptx_file db 'sobel_filter.ptx', 0
    kernel_name db 'sobel_filter', 0
    
    newline db 0xA, 0

section .bss
    width resd 1
    height resd 1
    frame_size resd 1
    
    input_buffer resq 1
    output_buffer resq 1
    d_input resq 1
    d_output resq 1
    
    cuda_context resq 1
    cuda_device resd 1
    cuda_module resq 1
    cuda_function resq 1
    
    temp_buffer resb 32

section .text
    global _start
    extern cuInit
    extern cuDeviceGet
    extern cuCtxCreate
    extern cuModuleLoadData
    extern cuModuleGetFunction
    extern cuMemAlloc
    extern cuMemcpyHtoD
    extern cuMemcpyDtoH
    extern cuLaunchKernel
    extern cuCtxDestroy
    extern cuGetErrorString
    extern malloc
    extern free
    extern atoi
    extern open
    extern close
    extern read
    extern mmap
    extern munmap

_start:
    mov rbp, rsp
    
    cmp qword [rbp], 3
    jne usage_error
    
    mov rsi, [rbp + 16]
    call parse_int
    mov [width], eax
    
    mov rsi, [rbp + 24]
    call parse_int  
    mov [height], eax
    
    mov eax, [width]
    imul eax, [height]
    mov [frame_size], eax
    
    call init_cuda
    test eax, eax
    jnz exit_error
    
    call allocate_memory
    test eax, eax
    jnz exit_error
    
    call load_ptx_module
    test eax, eax
    jnz exit_error
    
    call process_single_frame
    test eax, eax
    jnz exit_error
    
    call cleanup
    
    mov rax, 60
    mov rdi, 0
    syscall

usage_error:
    mov rax, 1
    mov rdi, 2
    mov rsi, usage_msg
    mov rdx, usage_len
    syscall
    
    mov rax, 60
    mov rdi, 1
    syscall

exit_error:
    call cleanup
    mov rax, 60
    mov rdi, 1
    syscall

parse_int:
    push rbx
    push rcx
    push rdx
    
    xor rax, rax
    xor rbx, rbx
    
parse_loop:
    mov bl, [rsi]
    test bl, bl
    jz parse_done
    
    cmp bl, '0'
    jb parse_done
    cmp bl, '9'
    ja parse_done
    
    sub bl, '0'
    imul rax, 10
    add rax, rbx
    inc rsi
    jmp parse_loop
    
parse_done:
    pop rdx
    pop rcx
    pop rbx
    ret

init_cuda:
    push rbp
    mov rbp, rsp
    
    mov rdi, 0
    call cuInit
    test eax, eax
    jz init_cuda_device
    
    ; Print CUDA init error
    push rax
    mov rax, 1
    mov rdi, 2
    mov rsi, cuda_init_error_msg
    mov rdx, cuda_init_error_len
    syscall
    pop rax
    jmp init_cuda_error
    
init_cuda_device:
    
    mov rdi, cuda_device
    mov rsi, 0
    call cuDeviceGet
    test eax, eax
    jz init_cuda_context
    
    ; Print CUDA device error
    push rax
    mov rax, 1
    mov rdi, 2
    mov rsi, cuda_init_error_msg
    mov rdx, cuda_init_error_len
    syscall
    pop rax
    jmp init_cuda_error
    
init_cuda_context:
    mov rdi, cuda_context
    mov rsi, 0
    mov edx, [cuda_device]
    call cuCtxCreate
    test eax, eax
    jz init_cuda_success
    
    ; Print CUDA context error
    push rax
    mov rax, 1
    mov rdi, 2
    mov rsi, cuda_init_error_msg
    mov rdx, cuda_init_error_len
    syscall
    pop rax
    jmp init_cuda_error
    
init_cuda_success:
    
    xor eax, eax
    jmp init_cuda_done
    
init_cuda_error:
    mov eax, 1
    
init_cuda_done:
    mov rsp, rbp
    pop rbp
    ret

allocate_memory:
    push rbp
    mov rbp, rsp
    
    mov edi, [frame_size]
    call malloc
    test rax, rax
    jz alloc_error
    mov [input_buffer], rax
    
    mov edi, [frame_size]  
    call malloc
    test rax, rax
    jz alloc_error
    mov [output_buffer], rax
    
    mov rdi, d_input
    mov esi, [frame_size]
    call cuMemAlloc
    test eax, eax
    jnz alloc_error
    
    mov rdi, d_output
    mov esi, [frame_size]
    call cuMemAlloc
    test eax, eax
    jnz alloc_error
    
    xor eax, eax
    jmp alloc_done
    
alloc_error:
    mov eax, 1
    
alloc_done:
    mov rsp, rbp
    pop rbp
    ret

load_ptx_module:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    
    mov rax, 2
    mov rdi, ptx_file
    mov rsi, 0
    syscall
    test rax, rax
    js ptx_file_error
    mov [rbp-8], rax
    
    mov rax, 5
    mov rdi, [rbp-8]
    xor rsi, rsi
    mov rdx, 2
    syscall
    mov [rbp-16], rax
    
    mov rax, 9
    xor rdi, rdi
    mov rsi, [rbp-16]
    mov rdx, 1
    mov r10, 2
    mov r8, [rbp-8]
    xor r9, r9
    syscall
    test rax, rax
    js ptx_error
    
    mov rdi, cuda_module
    mov rsi, rax
    call cuModuleLoadData
    test eax, eax
    jz ptx_get_function
    
    ; Print specific module load error
    push rax
    mov rax, 1
    mov rdi, 2
    mov rsi, cuda_alloc_error_msg  ; Different message for cuModuleLoadData
    mov rdx, cuda_alloc_error_len
    syscall
    pop rax
    jmp ptx_error
    
ptx_get_function:
    mov rdi, cuda_function
    mov rsi, [cuda_module]
    mov rdx, kernel_name
    call cuModuleGetFunction
    test eax, eax
    jz ptx_success
    
    ; Print specific function get error  
    push rax
    mov rax, 1
    mov rdi, 2
    mov rsi, cuda_init_error_msg  ; Different message for cuModuleGetFunction
    mov rdx, cuda_init_error_len
    syscall
    pop rax
    jmp ptx_error
    
ptx_success:
    
    xor eax, eax
    jmp ptx_done
    
ptx_file_error:
    ; Print file access error
    mov rax, 1
    mov rdi, 2
    mov rsi, file_error_msg
    mov rdx, file_error_len
    syscall
    jmp ptx_error

ptx_error:
    mov eax, 1
    
ptx_done:
    mov rax, 3
    mov rdi, [rbp-8]
    syscall
    
    mov rsp, rbp
    pop rbp
    ret

process_single_frame:
    push rbp
    mov rbp, rsp
    
    mov rax, 0
    mov rdi, 0
    mov rsi, [input_buffer]
    mov edx, [frame_size]
    syscall
    
    cmp eax, [frame_size]
    jne process_error
    
    mov rdi, [d_input]
    mov rsi, [input_buffer]
    mov edx, [frame_size]
    call cuMemcpyHtoD
    test eax, eax
    jnz process_error
    
    call launch_sobel_kernel
    test eax, eax
    jnz process_error
    
    mov rdi, [output_buffer]
    mov rsi, [d_output]
    mov edx, [frame_size]
    call cuMemcpyDtoH
    test eax, eax
    jnz process_error
    
    mov rax, 1
    mov rdi, 1
    mov rsi, [output_buffer]
    mov edx, [frame_size]
    syscall
    
    xor eax, eax
    jmp process_done
    
process_error:
    mov eax, 1
    
process_done:
    mov rsp, rbp
    pop rbp
    ret

launch_sobel_kernel:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    
    ; Check if device memory is valid
    mov rax, [d_input]
    test rax, rax
    jz kernel_function_invalid
    mov [rbp-8], rax
    
    mov rax, [d_output]
    test rax, rax
    jz kernel_function_invalid
    mov [rbp-16], rax
    
    mov eax, [width]
    mov [rbp-20], eax
    
    mov eax, [height]  
    mov [rbp-24], eax
    
    lea rax, [rbp-8]
    mov [rbp-32], rax
    lea rax, [rbp-16]
    mov [rbp-40], rax
    lea rax, [rbp-20]
    mov [rbp-48], rax
    lea rax, [rbp-24]
    mov [rbp-56], rax
    
    mov eax, [width]
    add eax, 15
    shr eax, 4
    mov r8d, eax
    
    mov eax, [height]
    add eax, 15
    shr eax, 4
    mov r9d, eax
    
    ; Check if cuda_function is valid (non-NULL)
    mov rdi, [cuda_function]
    test rdi, rdi
    jz kernel_function_invalid
    
    mov rsi, r8
    mov rdx, r9
    mov rcx, 1
    push 1
    push 1
    push 16
    push 16
    push 1
    push 0
    push 0
    lea r8, [rbp-32]
    push 0
    call cuLaunchKernel
    add rsp, 72
    test eax, eax
    jz kernel_launch_success
    
    ; Print kernel launch error
    push rax
    mov rax, 1
    mov rdi, 2
    mov rsi, cuda_module_error_msg
    mov rdx, cuda_module_error_len
    syscall
    pop rax
    
kernel_function_invalid:
    ; Print function invalid error
    push rax
    mov rax, 1
    mov rdi, 2
    mov rsi, cuda_module_error_msg
    mov rdx, cuda_module_error_len
    syscall
    pop rax
    mov eax, 1  ; Return error

kernel_launch_success:
    mov rsp, rbp
    pop rbp
    ret

cleanup:
    push rbp
    mov rbp, rsp
    
    cmp qword [input_buffer], 0
    je cleanup_output
    mov rdi, [input_buffer]
    call free
    
cleanup_output:
    cmp qword [output_buffer], 0
    je cleanup_context
    mov rdi, [output_buffer]
    call free
    
cleanup_context:
    cmp qword [cuda_context], 0
    je cleanup_done
    mov rdi, [cuda_context]
    call cuCtxDestroy
    
cleanup_done:
    mov rsp, rbp
    pop rbp
    ret

print_cuda_error:
    push rbp
    mov rbp, rsp
    push rdi
    push rsi
    push rdx
    
    ; Print basic error message first
    mov rax, 1
    mov rdi, 2
    mov rsi, cuda_error_msg
    mov rdx, cuda_error_len
    syscall
    
    ; Get error string from CUDA error code (passed in as parameter)
    mov rdi, [rbp+16]  ; CUDA error code from caller
    call cuGetErrorString
    
    ; Print the error string (returned in rax)
    mov rdi, 2
    mov rsi, rax
    mov rdx, 50       ; Approximate max length
    mov rax, 1
    syscall
    
    ; Print newline
    mov rax, 1
    mov rdi, 2
    mov rsi, newline
    mov rdx, 1
    syscall
    
    pop rdx
    pop rsi
    pop rdi
    mov rsp, rbp
    pop rbp
    ret