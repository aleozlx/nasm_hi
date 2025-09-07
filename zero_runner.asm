section .data
    ; Constants
    sz_int32 equ 4
    sz_int64 equ 8
    fd_stdin equ 0
    fd_stdout equ 1
    fd_stderr equ 2
    bdim_x equ 16
    bdim_y equ 16
    
    ; Syscall numbers
    sys_read equ 0
    sys_write equ 1
    sys_open equ 2
    sys_openat equ 257
    sys_close equ 3
    sys_lseek equ 8
    sys_fstat equ 5
    sys_mmap equ 9
    sys_exit equ 60
    
    usage_msg db 'Usage: zero_runner <width> <height>', 0xA, 0
    usage_len equ $ - usage_msg - 1
    
    hex_chars db '0123456789ABCDEF'
    
    cuda_error_msg db 'CUDA Error: ', 0
    cuda_error_len equ $ - cuda_error_msg - 1
    
    cuda_fallback_msg db '<cuGetErrorString failed>', 0
    cuda_fallback_len equ $ - cuda_fallback_msg - 1
    
    memory_error_msg db 'Memory allocation failed', 0xA, 0
    memory_error_len equ $ - memory_error_msg - 1
    
    ptx_file db 'zero_filter.ptx', 0
    kernel_name db 'zero_filter', 0
    
    ptx_opening_msg db '[D] Opening PTX file: zero_filter.ptx', 0xA, 0
    ptx_opening_len equ $ - ptx_opening_msg - 1
    
    ptx_seeking_msg db '[D] Getting PTX file size', 0xA, 0
    ptx_seeking_len equ $ - ptx_seeking_msg - 1
    
    ptx_mapping_msg db '[D] Mapping PTX file to memory', 0xA, 0
    ptx_mapping_len equ $ - ptx_mapping_msg - 1
    
    os_error_prefix db 'OS Error: ', 0
    os_error_prefix_len equ $ - os_error_prefix - 1
    
    newline db 0xA, 0
    
    ; Debug messages
    debug_start_msg db '[D] Starting zero_runner...', 0xA, 0
    debug_start_len equ $ - debug_start_msg - 1
    
    debug_args_msg db '[D] Arguments parsed successfully', 0xA, 0
    debug_args_len equ $ - debug_args_msg - 1
    
    debug_cuda_msg db '[D] Initializing CUDA...', 0xA, 0
    debug_cuda_len equ $ - debug_cuda_msg - 1
    
    debug_memory_msg db '[D] Allocating memory...', 0xA, 0
    debug_memory_len equ $ - debug_memory_msg - 1
    
    debug_ptx_msg db '[D] Loading PTX module...', 0xA, 0
    debug_ptx_len equ $ - debug_ptx_msg - 1
    
    debug_processing_msg db '[D] Starting frame processing...', 0xA, 0
    debug_processing_len equ $ - debug_processing_msg - 1
    
    debug_read_msg db '[D] Reading frame from stdin...', 0xA, 0
    debug_read_len equ $ - debug_read_msg - 1
    
    debug_read_done_msg db '[D] Frame read completed', 0xA, 0
    debug_read_done_len equ $ - debug_read_done_msg - 1
    
    debug_htod_msg db '[D] Copying frame to device...', 0xA, 0
    debug_htod_len equ $ - debug_htod_msg - 1
    
    debug_kernel_msg db '[D] Launching zero kernel...', 0xA, 0
    debug_kernel_len equ $ - debug_kernel_msg - 1
    
    debug_dtoh_msg db '[D] Copying result from device...', 0xA, 0
    debug_dtoh_len equ $ - debug_dtoh_msg - 1
    
    debug_write_msg db '[D] Writing result to stdout...', 0xA, 0
    debug_write_len equ $ - debug_write_msg - 1
    
    debug_kernel_params_msg db '[D] Kernel params setup', 0xA, 0
    debug_kernel_params_len equ $ - debug_kernel_params_msg - 1
    
    debug_abort_msg db '[D] Abort!', 0xA, 0
    debug_abort_len equ $ - debug_abort_msg - 1
    
    ptx_load_debug_msg db 'cuModuleLoadData_ret', 0
    
    gdim_x_msg db 'gdim.x', 0
    gdim_y_msg db 'gdim.y', 0
    bdim_x_msg db 'bdim.x', 0
    bdim_y_msg db 'bdim.y', 0
    
    hex_buffer db '0x0000000000000000', 0  ; "0x" + 16 hex digits + null terminator
    debug_buffer_safety db 0  ; safety null terminator for debug_buffer

    debug_prefix db '[D] ', 0
    debug_prefix_len equ $ - debug_prefix - 1
    debug_separator db ' = ', 0
    debug_separator_len equ $ - debug_separator - 1
    
    width_txt db 'width', 0
    height_txt db 'height', 0
    frame_size_txt db 'frame_size', 0
    ret_val_txt db '(ret_val)', 0
    debug_device_msg db 'cuda_device', 0
    debug_context_msg db 'cuda_context', 0
    debug_current_ctx_msg db 'current_ctx', 0
    debug_stored_ctx_msg db 'stored_ctx', 0
    debug_d_input_msg db 'd_input', 0
    debug_d_output_msg db 'd_output', 0
    h_input_msg db 'h_input', 0
    h_output_msg db 'h_output', 0

section .bss
    width resd 1
    height resd 1
    frame_size resd 1
    
    d_input resq 1
    d_output resq 1
    h_input resq 1
    h_output resq 1
    
    cuda_context resq 2
    cuda_device resd 1
    cuda_module resq 1
    cuda_function resq 1
    
    temp_buffer resb 8  ; Buffer to store current context pointer
    debug_buffer resb 64  ; buffer for formatted debug output
    cuda_error_string_ptr resq 1  ; pointer to error string from cuGetErrorString

section .text
    global _start
    extern cuInit
    extern cuDeviceGet
    extern cuCtxCreate
    extern cuModuleLoadData
    extern cuModuleGetFunction
    extern cuMemAlloc
    extern cuMemAllocManaged
    extern cuMemcpyHtoD
    extern cuMemcpyDtoH
    extern cuLaunchKernel
    extern cuCtxDestroy
    extern cuCtxSetCurrent
    extern cuCtxSynchronize
    extern cuGetErrorString
    extern malloc
    extern free
    extern atoi
    extern open
    extern close
    extern read
    extern mmap
    extern munmap
    extern strerror
    extern __errno_location
    extern cuCtxPushCurrent
    extern cuCtxPopCurrent
    extern cuCtxGetCurrent

; Macro definitions
%macro chk_cuda 0
    test rax, rax
    jnz abort_cuda
%endmacro

%macro abort_now 1
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_abort_msg
    mov rdx, debug_abort_len
    syscall
    
    mov rax, sys_exit
    mov rdi, %1 ; exit code
    syscall
%endmacro

_start:
    mov rbp, rsp
    
    ; Initialize debug_buffer with "[D] " prefix once
    mov rsi, debug_prefix
    mov rdi, debug_buffer
    mov rcx, debug_prefix_len
    rep movsb
    
    ; Debug: Starting
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_start_msg
    mov rdx, debug_start_len
    syscall

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

    mov edi, [width]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, width_txt
    call log_debug

    mov edi, [height]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, height_txt
    call log_debug

    mov edi, [frame_size]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, frame_size_txt
    call log_debug
    
    ; Debug: Args parsed
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_args_msg
    mov rdx, debug_args_len
    syscall
    
    call init_cuda
    call allocate_memory
    call load_ptx_module
    ; Debug: Processing
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_processing_msg
    mov rdx, debug_processing_len
    syscall
    
    call process_single_frame
    test eax, eax
    jnz exit_error
    
    call cleanup
    
    mov rax, sys_exit
    mov rdi, 0
    syscall

usage_error:
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, usage_msg
    mov rdx, usage_len
    syscall
    
    mov rax, sys_exit
    mov rdi, 1
    syscall

exit_error:
    call cleanup
    mov rax, sys_exit
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

print_cuda_error:
    ; Input: rax = CUDA error code
    ; Prints "CUDA Error: <readable_message>" to stderr
    push rbp
    mov rbp, rsp
    push rdi
    mov rdi, rax  ; Prepare to log the cuda error code
    push rsi
    push rdx
    push rax

    ; Always log the error code using log_debug
    mov rcx, sz_int32  ; 4 bytes for 32-bit error code
    call convert_rdi_hex
    mov rsi, ret_val_txt
    call log_debug
    
    ; Print "CUDA Error: " prefix
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, cuda_error_msg
    mov rdx, cuda_error_len
    syscall
    
    ; Get error string from CUDA
    pop rax  ; restore error code
    push rax ; save it again
    mov rdi, rax  ; error code as first parameter
    mov rsi, cuda_error_string_ptr  ; pointer to pointer for output string
    call cuGetErrorString
    ; rax now contains the result code, cuda_error_string_ptr contains the string pointer
    
    ; Check if cuGetErrorString succeeded and string pointer is valid
    test rax, rax
    jnz .print_fallback_error  ; if cuGetErrorString failed
    mov rax, [cuda_error_string_ptr]  ; load the actual string pointer
    test rax, rax
    jnz .print_cuda_error_string   ; if string pointer is valid, use it
    
.print_fallback_error:
    ; Use fallback message if cuGetErrorString failed or returned NULL
    mov qword [cuda_error_string_ptr], cuda_fallback_msg
    
.print_cuda_error_string:
    ; Print the error string (either from CUDA or fallback)
    mov rsi, [cuda_error_string_ptr]  ; error string pointer
    call strlen0  ; get length in rcx
    mov rdx, rcx  ; length for write syscall
    mov rax, sys_write
    mov rdi, fd_stderr
    syscall
    
    ; Print newline
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, newline
    mov rdx, 1
    syscall
    
    pop rax  ; restore error code to return it
    pop rdx
    pop rsi
    pop rdi
    mov rsp, rbp
    pop rbp
    ret

print_system_error:
    ; Prints "OS Error: <system_error_message>" to stderr
    ; Uses errno to get the actual system error
    push rbp
    mov rbp, rsp
    push rdi
    push rsi
    push rdx
    
    ; Print "OS Error: " prefix
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, os_error_prefix
    mov rdx, os_error_prefix_len
    syscall
    
    ; Get errno location and dereference it
    call __errno_location
    mov edi, [rax]  ; dereference errno pointer to get errno value
    call strerror
    ; rax now contains pointer to error string
    
    ; Print the error string
    mov rsi, rax  ; error string pointer
    call strlen0  ; get length in rcx
    mov rdx, rcx  ; length for write syscall
    mov rax, sys_write
    mov rdi, fd_stderr
    syscall
    
    ; Print newline
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, newline
    mov rdx, 1
    syscall
    
    pop rdx
    pop rsi
    pop rdi
    mov rsp, rbp
    pop rbp
    ret

init_cuda:
    push rbp
    mov rbp, rsp

    ; Debug: CUDA init
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_cuda_msg
    mov rdx, debug_cuda_len
    syscall
    
    ; rax = cuInit(0)
    mov rdi, 0
    call cuInit
    chk_cuda
    
    ; rax = cuDeviceGet(&cuda_device, 0)
    mov rdi, cuda_device
    mov rsi, 0
    call cuDeviceGet
    chk_cuda
    
    ; Debug: Print device ID
    mov edi, [cuda_device]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, debug_device_msg
    call log_debug

    mov rdi, cuda_context
    mov rsi, 0
    xor rdx, rdx
    mov edx, [cuda_device]
    call cuCtxCreate
    chk_cuda
    
    ; Debug: Print context pointer
    mov rdi, [cuda_context]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, debug_context_msg
    call log_debug
    
    ; Set the context as current for this thread
    mov rdi, [cuda_context]
    call cuCtxSetCurrent
    chk_cuda
    
    mov rsp, rbp
    pop rbp
    ret

allocate_memory:
    push rbp
    mov rbp, rsp
    
    ; Debug: Memory allocation
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_memory_msg
    mov rdx, debug_memory_len
    syscall

    ; Allocate host memory for input buffer
    mov rdi, [frame_size]
    call malloc
    test rax, rax
    jz malloc_error
    mov [h_input], rax
    
    ; Allocate host memory for output buffer
    mov rdi, [frame_size]
    call malloc
    test rax, rax
    jz malloc_error
    mov [h_output], rax

    ; Allocate device memory for input buffer
    mov rdi, d_input          ; pointer to the pointer
    mov rsi, [frame_size]     ; size in bytes
    call cuMemAlloc
    chk_cuda
    
    ; Allocate device memory for output buffer
    mov rdi, d_output         ; pointer to the pointer
    mov rsi, [frame_size]     ; size in bytes
    call cuMemAlloc
    chk_cuda


    ; Debug: Print allocated host and device pointers

    ; Host input pointer
    mov rdi, [h_input]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, h_input_msg
    call log_debug

    ; Host output pointer
    mov rdi, [h_output]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, h_output_msg
    call log_debug

    ; Device input pointer
    mov rdi, [d_input]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, debug_d_input_msg
    call log_debug

    ; Device output pointer
    mov rdi, [d_output]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, debug_d_output_msg
    call log_debug
    
    xor eax, eax
    mov rsp, rbp
    pop rbp
    ret

malloc_error:
    ; Print memory allocation error message
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, memory_error_msg
    mov rdx, memory_error_len
    syscall
    
    ; Exit immediately - OS will clean up CUDA resources
    mov rax, sys_exit
    mov rdi, 1
    syscall

load_ptx_module:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    ; Debug: PTX loading
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_ptx_msg
    mov rdx, debug_ptx_len
    syscall
    
    ; Log: Opening PTX file
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, ptx_opening_msg
    mov rdx, ptx_opening_len
    syscall
    
    mov rax, sys_openat
    mov rdi, -100     ; AT_FDCWD (current working directory)
    mov rsi, ptx_file
    mov rdx, 0        ; O_RDONLY
    syscall
    
    ; Debug: Print openat return value
    push rax
    mov rdi, rax
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, ret_val_txt
    call log_debug
    pop rax
    
    cmp rax, 0
    jl fs_error
    mov [rbp-4], eax    ; Store as 32-bit file descriptor
    
    ; Log: Getting file size
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, ptx_seeking_msg
    mov rdx, ptx_seeking_len
    syscall
    
    ; Debug: Print file descriptor being passed to lseek
    mov edi, [rbp-4]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, ret_val_txt
    call log_debug
    
    mov rax, sys_lseek
    xor rdi, rdi        ; Clear rdi first
    mov edi, [rbp-4]    ; Load 32-bit file descriptor
    xor rsi, rsi
    mov rdx, 2
    syscall
    
    ; Debug: Print lseek return value
    push rax
    mov rdi, rax
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, ret_val_txt
    call log_debug
    pop rax
    
    cmp rax, 0
    jl fs_error
    mov [rbp-16], rax  ; ptx file size
    
    ; Log: Mapping to memory
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, ptx_mapping_msg
    mov rdx, ptx_mapping_len
    syscall
    
    mov rax, sys_mmap
    xor rdi, rdi
    mov rsi, [rbp-16]
    mov rdx, 1
    mov r10, 2
    mov r8d, [rbp-4]    ; Load 32-bit file descriptor
    xor r9, r9
    syscall
    cmp rax, -1
    je fs_error
    
    mov rdi, cuda_module
    mov rsi, rax
    call cuModuleLoadData
    chk_cuda
    
    mov rdi, cuda_function
    mov rsi, [cuda_module]
    mov rdx, kernel_name
    call cuModuleGetFunction
    chk_cuda
    
    xor eax, eax
    jmp ptx_done
    
fs_error:
    call print_system_error
    mov eax, 1
    
ptx_done:
    ; Only close file descriptor if it was successfully opened
    cmp dword [rbp-4], 0
    jle ptx_cleanup_done
    mov rax, sys_close
    mov edi, [rbp-4]    ; Load 32-bit file descriptor
    syscall
    
ptx_cleanup_done:
    mov rsp, rbp
    pop rbp
    ret

process_single_frame:
    push rbp
    mov rbp, rsp
    
    ; Debug: Reading frame
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_read_msg
    mov rdx, debug_read_len
    syscall
    
    mov rax, sys_read
    mov rdi, 0
    mov rsi, [h_input]        ; Read into host buffer
    mov edx, [frame_size]
    syscall
    
    ; Debug: Read completed
    push rax
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_read_done_msg
    mov rdx, debug_read_done_len
    syscall
    pop rax
    
    cmp eax, [frame_size]
    jne process_error
    
    ; Debug: Host to device transfer
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_htod_msg
    mov rdx, debug_htod_len
    syscall
    
    ; Copy data from host to device
    mov rdi, [d_input]        ; destination (device)
    mov rsi, [h_input]        ; source (host)
    mov rdx, [frame_size]     ; size
    call cuMemcpyHtoD
    chk_cuda
    
    ; Debug: Kernel launch
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_kernel_msg
    mov rdx, debug_kernel_len
    syscall
    
    call launch_zero_kernel
    chk_cuda
    
    ; Debug: Device to host transfer
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_dtoh_msg
    mov rdx, debug_dtoh_len
    syscall
    
    ; Copy result from device to host
    mov rdi, [h_output]       ; destination (host)
    mov rsi, [d_output]       ; source (device)
    mov rdx, [frame_size]     ; size
    call cuMemcpyDtoH
    chk_cuda
    
    ; Debug: Writing result
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_write_msg
    mov rdx, debug_write_len
    syscall
    
    mov rax, sys_write
    mov rdi, 1
    mov rsi, [h_output]       ; Write from host buffer
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

launch_zero_kernel:
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
    
    ; Set up kernel parameter array (input, output, width, height)
    lea rax, [rbp-8]     ; d_input pointer
    mov [rbp-32], rax
    lea rax, [rbp-16]    ; d_output pointer  
    mov [rbp-40], rax
    lea rax, [rbp-20]    ; width pointer
    mov [rbp-48], rax
    lea rax, [rbp-24]    ; height pointer
    mov [rbp-56], rax
    ; Null terminate the parameter array
    mov qword [rbp-64], 0
    
    mov eax, [width]
    add eax, 15
    shr eax, 4
    mov r8d, eax
    
    mov eax, [height]
    add eax, 15
    shr eax, 4
    mov r9d, eax
    
    ; Print grid dimensions
    push r8
    push r9
    
    mov rdi, r8
    mov rcx, sz_int32  ; 4 bytes for 32-bit value
    call convert_rdi_hex
    mov rsi, gdim_x_msg
    call log_debug
    
    mov rdi, r9
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, gdim_y_msg
    call log_debug
    
    mov rdi, bdim_x
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, bdim_x_msg
    call log_debug
    
    mov rdi, bdim_y
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, bdim_y_msg
    call log_debug
    
    pop r9
    pop r8
    
    ; cuLaunchKernel parameters: f, gridX, gridY, gridZ, blockX, blockY, blockZ, sharedMem, stream, params, extra
    mov rdi, [cuda_function]  ; f
    mov rsi, r8              ; gridDimX  
    mov rdx, r9              ; gridDimY
    mov rcx, 1               ; gridDimZ
    mov r8d, [bdim_x]        ; blockDimX
    mov r9d, [bdim_y]        ; blockDimY
    push 0                   ; extra (NULL)
    lea rax, [rbp-32]        ; kernelParams array
    push rax                 
    push 0                   ; hStream (NULL)
    push 0                   ; sharedMemBytes
    push 1                   ; blockDimZ
    call cuLaunchKernel
    add rsp, 40
    chk_cuda
    
    ; Synchronize to wait for kernel completion and check for kernel errors
    call cuCtxSynchronize
    chk_cuda
    
    mov rsp, rbp
    pop rbp
    ret

cleanup:
    push rbp
    mov rbp, rsp
    
    ; Free host memory
    cmp qword [h_input], 0
    je skip_h_input_free
    mov rdi, [h_input]
    call free
skip_h_input_free:
    
    cmp qword [h_output], 0
    je skip_h_output_free
    mov rdi, [h_output]
    call free
skip_h_output_free:
    
    ; Free device memory (will be freed when context is destroyed)
    ; CUDA context cleanup
    cmp qword [cuda_context], 0
    je cleanup_done
    mov rdi, [cuda_context]
    call cuCtxDestroy
    
cleanup_done:
    mov rsp, rbp
    pop rbp
    ret

convert_rdi_hex:
    ; rdi = value to convert, rcx = bytes to output
    push rax
    push rbx
    
    mov rbx, hex_buffer + 1
    add rbx, rcx
    add rbx, rcx  ; hex_buffer + 1 + (rcx * 2) = end of hex digits
    
    ; Null terminate: "0x" (2) + hex digits (rcx*2) + null (1)
    mov byte [rbx + 1], 0
    
    mov rax, rdi  ; use rax for shifting
    
.loop:
    mov rdi, rax
    and rdi, 0xF
    mov dil, [hex_chars + rdi]
    mov [rbx], dil
    dec rbx
    shr rax, 4
    cmp rbx, hex_buffer + 1  ; stop when we reach "0x" + 1
    jg .loop
    
    pop rbx
    pop rax
    ret

strlen0:
    ; rsi = null-terminated string, returns length in rcx
    push rdi      ; save caller's rdi since repne scasb modifies it
    
    mov rcx, -1
    xor al, al
    mov rdi, rsi  ; repne scasb uses rdi
    repne scasb   ; scan for null, rcx will be -(length+1)
    neg rcx
    dec rcx       ; rcx now has string length
    
    pop rdi       ; restore caller's rdi
    ret

log_debug:
    ; rsi = variable name string (null terminated)
    push rax
    push rcx
    push rdx
    push rdi
    push rsi
    
    mov rdi, debug_buffer + 4  ; destination, skip "[D] " prefix
    
    ; Copy variable name using rep movsb
    call strlen0   ; returns length in rcx
    rep movsb
    
    ; Add " = " using rep movsb
    mov rsi, debug_separator
    mov rcx, debug_separator_len
    rep movsb
    
    ; Copy hex string using rep movsb
    mov rsi, hex_buffer
    call strlen0   ; returns length in rcx
    rep movsb
    
    ; Add newline
    mov byte [rdi], 0xA
    inc rdi
    
    ; Calculate total length and print
    mov rdx, rdi
    sub rdx, debug_buffer
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_buffer
    syscall
    
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rax
    ret

abort_cuda:
    call print_cuda_error
    abort_now 1
