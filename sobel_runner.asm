section .data
    usage_msg db 'Usage: sobel_runner <width> <height>', 0xA, 0
    usage_len equ $ - usage_msg - 1
    
    cuda_error_msg db 'CUDA Error: ', 0
    cuda_error_len equ $ - cuda_error_msg - 1
    
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
    
    call process_frames
    
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
    jnz init_cuda_done
    
    mov rdi, cuda_device
    mov rsi, 0
    call cuDeviceGet
    test eax, eax
    jnz init_cuda_done
    
    mov rdi, cuda_context
    mov rsi, 0
    mov edx, [cuda_device]
    call cuCtxCreate
    
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
    js ptx_error
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
    jnz ptx_error
    
    mov rdi, cuda_function
    mov rsi, [cuda_module]
    mov rdx, kernel_name
    call cuModuleGetFunction
    test eax, eax
    jnz ptx_error
    
    xor eax, eax
    jmp ptx_done
    
ptx_error:
    mov eax, 1
    
ptx_done:
    mov rax, 3
    mov rdi, [rbp-8]
    syscall
    
    mov rsp, rbp
    pop rbp
    ret

process_frames:
    push rbp
    mov rbp, rsp
    
frame_loop:
    mov rax, 0
    mov rdi, 0
    mov rsi, [input_buffer]
    mov edx, [frame_size]
    syscall
    
    cmp rax, 0
    je frames_done
    
    cmp eax, [frame_size]
    jne frames_done
    
    mov rdi, [d_input]
    mov rsi, [input_buffer]
    mov edx, [frame_size]
    call cuMemcpyHtoD
    test eax, eax
    jnz frames_done
    
    call launch_sobel_kernel
    test eax, eax
    jnz frames_done
    
    mov rdi, [output_buffer]
    mov rsi, [d_output]
    mov edx, [frame_size]
    call cuMemcpyDtoH
    test eax, eax
    jnz frames_done
    
    mov rax, 1
    mov rdi, 1
    mov rsi, [output_buffer]
    mov edx, [frame_size]
    syscall
    
    jmp frame_loop
    
frames_done:
    mov rsp, rbp
    pop rbp
    ret

launch_sobel_kernel:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    
    mov rax, [d_input]
    mov [rbp-8], rax
    
    mov rax, [d_output]
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
    
    mov rdi, [cuda_function]
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