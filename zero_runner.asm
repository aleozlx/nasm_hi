%include "common.inc"

section .data
    ; CUDA library path and function names for dlopen
    cuda_lib_path db 'libcuda.so.1', 0
    cuInit_name db 'cuInit', 0
    cuDeviceGet_name db 'cuDeviceGet', 0
    cuCtxCreate_name db 'cuCtxCreate', 0
    cuCtxSetCurrent_name db 'cuCtxSetCurrent', 0
    cuCtxGetCurrent_name db 'cuCtxGetCurrent', 0
    cuMemAlloc_name db 'cuMemAlloc', 0
    cuMemAllocManaged_name db 'cuMemAllocManaged', 0
    cuMemFree_name db 'cuMemFree', 0
    cuMemcpyHtoD_name db 'cuMemcpyHtoD', 0
    cuMemcpyDtoH_name db 'cuMemcpyDtoH', 0
    cuModuleLoadData_name db 'cuModuleLoadData', 0
    cuModuleGetFunction_name db 'cuModuleGetFunction', 0
    cuLaunchKernel_name db 'cuLaunchKernel', 0
    cuCtxSynchronize_name db 'cuCtxSynchronize', 0
    cuGetErrorString_name db 'cuGetErrorString', 0
    ; CUDA kernel specific constants
    bdim_x equ 16
    bdim_y equ 16
    
    usage_msg db 'Usage: zero_runner <width> <height>', 0xA, 0
    usage_len equ $ - usage_msg - 1
    
    cuda_load_error_msg db 'Error: Failed to load CUDA library', 0xA, 0
    cuda_load_error_len equ $ - cuda_load_error_msg - 1
    
    memory_error_msg db 'Memory allocation failed', 0xA, 0
    memory_error_len equ $ - memory_error_msg - 1
    
    runtime_load_error_msg db 'Failed to load runtime library', 0xA, 0
    runtime_load_error_len equ $ - runtime_load_error_msg - 1
    
    ptx_file db 'zero_filter.ptx', 0
    kernel_name db 'zero_filter', 0
    
    ; Runtime library name (defined in runtime_init.inc)
    
    ptx_opening_msg db '[D] Opening PTX file: zero_filter.ptx', 0xA, 0
    ptx_opening_len equ $ - ptx_opening_msg - 1
    
    ptx_seeking_msg db '[D] Getting PTX file size', 0xA, 0
    ptx_seeking_len equ $ - ptx_seeking_msg - 1
    
    ptx_mapping_msg db '[D] Mapping PTX file to memory', 0xA, 0
    ptx_mapping_len equ $ - ptx_mapping_msg - 1
    
    
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
    
    zero_check_ok_msg db '[D] ✓ Kernel correctly zeroed all output bytes', 0xA, 0
    zero_check_ok_len equ $ - zero_check_ok_msg - 1
    
    zero_check_fail_msg db '[D] ✗ ERROR: Output contains non-zero bytes!', 0xA, 0
    zero_check_fail_len equ $ - zero_check_fail_msg - 1
    
    debug_kernel_params_msg db '[D] Kernel params setup', 0xA, 0
    debug_kernel_params_len equ $ - debug_kernel_params_msg - 1
    
    ptx_load_debug_msg db 'cuModuleLoadData_ret', 0
    
    gdim_x_msg db 'gdim.x', 0
    gdim_y_msg db 'gdim.y', 0
    bdim_x_msg db 'bdim.x', 0
    bdim_y_msg db 'bdim.y', 0
    
    debug_abort_msg db '[D] Abort!', 0xA, 0
    debug_abort_len equ $ - debug_abort_msg - 1
    
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

    ; Tensor pointers (replacing individual host/device pointers)
    input_tensor resq 1
    output_tensor resq 1

    cuda_context resq 2
    cuda_device resd 1
    cuda_module resq 1
    cuda_function resq 1
    
    temp_buffer resb 8  ; Buffer to store current context pointer
    current_context resq 1  ; Buffer to store current context from cuCtxGetCurrent
    
    ; CUDA library handle and function pointers (dlopen approach)
    cuda_lib_handle resq 1
    cuInit_fptr resq 1
    cuDeviceGet_fptr resq 1
    cuCtxCreate_fptr resq 1
    cuCtxSetCurrent_fptr resq 1
    cuCtxGetCurrent_fptr resq 1
    cuMemAlloc_fptr resq 1
    cuMemAllocManaged_fptr resq 1
    cuMemFree_fptr resq 1
    cuMemcpyHtoD_fptr resq 1
    cuMemcpyDtoH_fptr resq 1
    cuModuleLoadData_fptr resq 1
    cuModuleGetFunction_fptr resq 1
    cuLaunchKernel_fptr resq 1
    cuCtxSynchronize_fptr resq 1
    cuGetErrorString_fptr resq 1

section .text
    global main
    ; global _start  ; commented out - back to main with gcc linking
    
    ; CUDA Driver API functions - will use dlopen
    ; extern cuInit
    ; extern cuDeviceGet
    ; extern cuCtxCreate
    ; extern cuCtxSetCurrent
    ; extern cuModuleLoadData
    ; extern cuModuleGetFunction
    ; extern cuMemAlloc
    ; extern cuMemcpyHtoD
    ; extern cuMemcpyDtoH
    ; extern cuLaunchKernel
    ; extern cuCtxSynchronize
    ; extern cuCtxGetCurrent
    ; extern cuGetErrorString
    
    ; System functions  
    extern malloc
    extern free
    extern memset
    extern open
    extern close
    extern read
    extern mmap
    extern munmap
    extern strerror
    extern __errno_location
    extern dlopen
    extern dlsym
    extern dlclose
    
    ; Common utility functions
    extern parse_int
    extern convert_rdi_hex
    extern strlen0
    extern log_debug
    extern print_cuda_error
    extern print_system_error
    extern abort_cuda

main:
    push rbp
    mov rbp, rsp
    
    ; C runtime entry point - argc in rdi, argv in rsi
    
    ; Load CUDA library with dlopen
    call load_cuda_library
    test rax, rax
    jz cuda_load_error
    
    ; Note: debug_buffer initialization is now handled in common.asm
    
    ; Debug: Starting
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, debug_start_msg
    mov rdx, debug_start_len
    syscall

    ; TEMPORARY: Hard-code arguments to focus on CUDA kernel
    ; TODO: Fix argument parsing later
    mov dword [width], 3
    mov dword [height], 3
    
    ; Test C runtime initialization with a small malloc
    mov rdi, 16         ; allocate 16 bytes
    call malloc
    test rax, rax
    jz malloc_test_failed
    
    ; Debug: print malloc test result
    push rax
    mov rdi, rax
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, debug_device_msg    ; reuse existing string
    call log_debug
    pop rax
    
    ; Free the test allocation
    mov rdi, rax
    call free
    jmp malloc_test_ok
    
malloc_test_failed:
    ; C runtime malloc failed!
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, memory_error_msg
    mov rdx, memory_error_len
    syscall
    mov rax, 1
    pop rbp
    ret
    
malloc_test_ok:
    
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
    
    ; Direct CUDA initialization
    call init_cuda
    
    ; Debug: Check current context after cuda_init
    mov rdi, current_context  ; pointer to store current context
    call [cuCtxGetCurrent_fptr]
    chk_cuda
    
    ; Debug: Print current context
    mov rdi, [current_context]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, debug_current_ctx_msg
    call log_debug
    
    call allocate_memory_direct
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
    
    ; Return 0 from main()
    mov rax, 0
    pop rbp
    ret

usage_error:
    ; This shouldn't be reached with hard-coded args
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, usage_msg
    mov rdx, usage_len
    syscall
    
    ; Return 1 from main()
    mov rax, 1
    pop rbp
    ret

function_null_error:
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, memory_error_msg  ; reuse error message
    mov rdx, memory_error_len
    syscall
    mov rax, 1
    pop rbp
    ret

exit_error:
    call cleanup
    ; Return 1 from main()
    mov rax, 1
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
    call [cuInit_fptr]
    chk_cuda
    
    ; rax = cuDeviceGet(&cuda_device, 0)
    mov rdi, cuda_device
    mov rsi, 0
    call [cuDeviceGet_fptr]
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
    call [cuCtxCreate_fptr]
    chk_cuda
    
    ; Debug: Print context pointer
    mov rdi, [cuda_context]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, debug_context_msg
    call log_debug
    
    ; Set the context as current for this thread
    mov rdi, [cuda_context]
    call [cuCtxSetCurrent_fptr]
    chk_cuda
    
    mov rsp, rbp
    pop rbp
    ret

allocate_memory_direct:
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

    ; Initialize output buffer to all 1s (0xFF) to verify kernel zeroing
    mov rdi, [h_output]       ; destination
    mov rsi, 0xFF             ; fill with 0xFF (all 1s)
    mov rdx, [frame_size]     ; size
    call memset

    ; Allocate device memory for input buffer
    mov rdi, d_input          ; pointer to the pointer
    mov rsi, [frame_size]     ; size in bytes
    call [cuMemAlloc_fptr]
    chk_cuda
    
    ; Allocate device memory for output buffer
    mov rdi, d_output         ; pointer to the pointer
    mov rsi, [frame_size]     ; size in bytes
    call [cuMemAlloc_fptr]
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

; COMMENTED OUT - old allocate_memory function (using allocate_memory_direct instead)

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
    call [cuModuleLoadData_fptr]
    chk_cuda
    
    mov rdi, cuda_function
    mov rsi, [cuda_module]
    mov rdx, kernel_name
    call [cuModuleGetFunction_fptr]
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
    
    ; Debug: Check current context before cuMemcpyHtoD
    mov rdi, current_context  ; pointer to store current context
    call [cuCtxGetCurrent_fptr]
    chk_cuda
    
    ; Debug: Print current context before memory copy
    mov rdi, [current_context]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, debug_current_ctx_msg
    call log_debug
    
    ; Copy input data from host to device
    mov rdi, [d_input]        ; destination (device)
    mov rsi, [h_input]        ; source (host)
    mov rdx, [frame_size]     ; size
    call [cuMemcpyHtoD_fptr]
    chk_cuda
    
    ; Copy output data (initialized to 0xFF) from host to device
    mov rdi, [d_output]       ; destination (device)
    mov rsi, [h_output]       ; source (host, filled with 0xFF)
    mov rdx, [frame_size]     ; size
    call [cuMemcpyHtoD_fptr]
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
    call [cuMemcpyDtoH_fptr]
    chk_cuda
    
    ; Verify that the kernel correctly zeroed the output
    mov rsi, [h_output]       ; buffer to check
    mov rcx, [frame_size]     ; size to check
    xor rax, rax              ; looking for zero bytes
check_zero_loop:
    test rcx, rcx
    jz all_zeros_found
    cmp byte [rsi], 0         ; check if byte is zero
    jne non_zero_found
    inc rsi
    dec rcx
    jmp check_zero_loop
    
non_zero_found:
    ; Print error message if non-zero byte found
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, zero_check_fail_msg
    mov rdx, zero_check_fail_len
    syscall
    jmp zero_check_done
    
all_zeros_found:
    ; Print success message if all bytes are zero
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, zero_check_ok_msg
    mov rdx, zero_check_ok_len
    syscall
    
zero_check_done:
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
    
    ; Set up kernel parameter array: pointers to actual values
    ; The kernel expects: [&d_input_value, &d_output_value, &width_value, &height_value]
    ; But we need to point to the VALUES, not the storage locations
    lea rax, [rbp-8]     ; &d_input (points to where d_input value is stored)
    mov [rbp-56], rax    ; params[0] = &d_input
    lea rax, [rbp-16]    ; &d_output (points to where d_output value is stored)
    mov [rbp-48], rax    ; params[1] = &d_output  
    lea rax, [rbp-20]    ; &width (points to where width value is stored)
    mov [rbp-40], rax    ; params[2] = &width
    lea rax, [rbp-24]    ; &height (points to where height value is stored)
    mov [rbp-32], rax    ; params[3] = &height
    
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
    
    ; Debug: Print parameter values before launch
    push r8
    push r9
    mov rdi, [d_input]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, debug_d_input_msg
    call log_debug
    
    mov rdi, [d_output]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, debug_d_output_msg
    call log_debug
    
    mov rdi, [width]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, width_txt
    call log_debug
    
    mov rdi, [height]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, height_txt
    call log_debug
    pop r9
    pop r8
    
    ; Debug: Check if cuda_function is valid
    mov rax, [cuda_function]
    test rax, rax
    jz function_null_error
    
    ; cuLaunchKernel parameters: f, gridX, gridY, gridZ, blockX, blockY, blockZ, sharedMem, stream, params, extra
    mov rdi, [cuda_function]  ; f
    mov rsi, r8              ; gridDimX  
    mov rdx, r9              ; gridDimY
    mov rcx, 1               ; gridDimZ
    mov r8d, bdim_x          ; blockDimX
    mov r9d, bdim_y          ; blockDimY
    
    ; Ensure 16-byte stack alignment before call
    ; We're pushing 5 qwords (40 bytes), so add 8 bytes padding
    push 0                   ; padding for alignment, otherwise causing SSE segfault, eg. movaps
    push 0                   ; extra (NULL)
    lea rax, [rbp-56]        ; kernelParams array (start from the last parameter)
    push rax                 
    push 0                   ; hStream (NULL)
    push 0                   ; sharedMemBytes
    push 1                   ; blockDimZ
    
    ; Call cuLaunchKernel (parameters already set up)
    call [cuLaunchKernel_fptr]
    add rsp, 48              ; 6 qwords = 48 bytes
    chk_cuda
    
    ; Synchronize to wait for kernel completion and check for kernel errors
    call [cuCtxSynchronize_fptr]
    chk_cuda
    
    mov rsp, rbp
    pop rbp
    ret

cleanup:
    push rbp
    mov rbp, rsp
    
    ; COMMENTED OUT - tensor operations (using direct memory management)
    ; Free input tensor (handles both host and device memory)
    ; cmp qword [input_tensor], 0
    ; je skip_input_tensor_free
    ; mov rdi, [input_tensor]    ; tensor pointer
    ; mov rsi, 0                 ; TENSOR_MODE_HOST_DEVICE
    ; call [tensor_free_fptr]
    ; skip_input_tensor_free:

    ; Free output tensor (handles both host and device memory)
    ; cmp qword [output_tensor], 0
    ; je skip_output_tensor_free
    ; mov rdi, [output_tensor]   ; tensor pointer
    ; mov rsi, 0                 ; TENSOR_MODE_HOST_DEVICE
    ; call [tensor_free_fptr]
    ; skip_output_tensor_free:

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

    ; Free device memory
    cmp qword [d_input], 0
    je skip_d_input_free
    mov rdi, [d_input]
    call [cuMemFree_fptr]
    ; Note: chk_cuda omitted in cleanup to avoid infinite recursion
skip_d_input_free:
    
    cmp qword [d_output], 0
    je skip_d_output_free
    mov rdi, [d_output]
    call [cuMemFree_fptr]
    ; Note: chk_cuda omitted in cleanup to avoid infinite recursion
skip_d_output_free:

cleanup_done:
    mov rsp, rbp
    pop rbp
    ret


; Load CUDA library and resolve function pointers
; Returns: rax = 1 on success, 0 on failure
load_cuda_library:
    push rbp
    mov rbp, rsp
    
    ; Load the CUDA library
    mov rdi, cuda_lib_path
    mov rsi, 1                  ; RTLD_LAZY
    call dlopen
    test rax, rax
    jz .load_failed
    mov [cuda_lib_handle], rax
    
    ; Get cuInit function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuInit_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuInit_fptr], rax

    ; Get cuDeviceGet function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuDeviceGet_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuDeviceGet_fptr], rax

    ; Get cuCtxCreate function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuCtxCreate_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuCtxCreate_fptr], rax

    ; Get cuCtxSetCurrent function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuCtxSetCurrent_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuCtxSetCurrent_fptr], rax
    
    ; Get cuCtxGetCurrent function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuCtxGetCurrent_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuCtxGetCurrent_fptr], rax

    ; Get cuMemAlloc function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuMemAlloc_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuMemAlloc_fptr], rax

    ; Get cuMemAllocManaged function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuMemAllocManaged_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuMemAllocManaged_fptr], rax

    ; Get cuMemFree function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuMemFree_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuMemFree_fptr], rax

    ; Get cuMemcpyHtoD function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuMemcpyHtoD_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuMemcpyHtoD_fptr], rax

    ; Get cuMemcpyDtoH function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuMemcpyDtoH_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuMemcpyDtoH_fptr], rax

    ; Get cuModuleLoadData function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuModuleLoadData_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuModuleLoadData_fptr], rax

    ; Get cuModuleGetFunction function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuModuleGetFunction_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuModuleGetFunction_fptr], rax

    ; Get cuLaunchKernel function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuLaunchKernel_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuLaunchKernel_fptr], rax

    ; Get cuCtxSynchronize function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuCtxSynchronize_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuCtxSynchronize_fptr], rax

    ; Get cuGetErrorString function pointer
    mov rdi, [cuda_lib_handle]
    mov rsi, cuGetErrorString_name
    call dlsym
    test rax, rax
    jz .symbol_failed
    mov [cuGetErrorString_fptr], rax
    
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

cuda_load_error:
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, cuda_load_error_msg
    mov rdx, cuda_load_error_len
    syscall
    abort_now 1
