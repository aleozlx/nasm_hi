%include "syscall.inc"
%include "common.inc"
%include "load_library_cuda.inc"

section .data
    ; PTX and kernel files
    txt_zero_filter_ptx db 'zero_filter.ptx', 0
    txt_zero_filter db 'zero_filter', 0
    
    ; CUDA kernel constants
    bdim_x equ 16
    bdim_y equ 16
    
    ; Usage and error messages
    msg_usage db 'Usage: zero_runner <width> <height>', 0xA, 0
    msg_cuda_load_error db 'Error: Failed to load CUDA library', 0xA, 0
    msg_memory_error db 'Memory allocation failed', 0xA, 0
    msg_runtime_load_error db 'Failed to load runtime library', 0xA, 0
    msg_ptx_opening db '[D] Opening PTX file: zero_filter.ptx', 0xA, 0
    msg_ptx_seeking db '[D] Getting PTX file size', 0xA, 0
    msg_ptx_mapping db '[D] Mapping PTX file to memory', 0xA, 0
        
    ; Debug messages
    msg_start db '[D] Starting zero_runner...', 0xA, 0
    msg_args db '[D] Arguments parsed successfully', 0xA, 0
    msg_cuda db '[D] Initializing CUDA...', 0xA, 0
    msg_cuda_loaded db '[D] CUDA library loaded successfully', 0xA, 0
    msg_memory db '[D] Allocating memory...', 0xA, 0
    msg_ptx db '[D] Loading PTX module...', 0xA, 0
    msg_processing db '[D] Starting frame processing...', 0xA, 0
    msg_read db '[D] Reading frame from stdin...', 0xA, 0
    msg_read_done db '[D] Frame read completed', 0xA, 0
    msg_htod db '[D] Copying frame to device...', 0xA, 0
    msg_kernel db '[D] Launching zero kernel...', 0xA, 0
    msg_dtoh db '[D] Copying result from device...', 0xA, 0
    msg_write db '[D] Writing result to stdout...', 0xA, 0
    msg_zero_check_ok db '[D] ✓ Kernel correctly zeroed all output bytes', 0xA, 0
    msg_zero_check_fail db '[D] ✗ ERROR: Output contains non-zero bytes!', 0xA, 0
    msg_kernel_params db '[D] Kernel params setup', 0xA, 0
    extern msg_abort
    extern msg_abort_len
    
    ; Debug variable names
    txt_width db 'width', 0
    txt_height db 'height', 0
    txt_frame_size db 'frame_size', 0
    txt_ret_val db '(ret_val)', 0
    txt_cuda_device db 'cuda_device', 0
    txt_cuda_context db 'cuda_context', 0
    txt_current_ctx db 'current_ctx', 0
    txt_stored_ctx db 'stored_ctx', 0
    txt_d_input db 'd_input', 0
    txt_d_output db 'd_output', 0
    txt_h_input db 'h_input', 0
    txt_h_output db 'h_output', 0
    txt_gdim_x db 'gdim.x', 0
    txt_gdim_y db 'gdim.y', 0
    txt_bdim_x db 'bdim.x', 0
    txt_bdim_y db 'bdim.y', 0
    txt_ptx_load_debug db 'cuModuleLoadData_ret', 0
    txt_rsp db '$rsp', 0

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
    

section .text
    global main
    
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
    

; Parse command line arguments
; Input: rdi = argc, rsi = argv
; Output: sets width and height variables
parse_args:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    
    mov r12, rdi    ; argc
    mov r13, rsi    ; argv
    
    ; Check if we have exactly 3 arguments (program name + width + height)
    cmp r12, 3
    jne .usage_error
    
    ; Parse width (argv[1])
    mov rsi, [r13 + 8]      ; argv[1] - string pointer goes in rsi
    call parse_int
    test rax, rax
    js .parse_error
    mov [width], eax
    
    ; Parse height (argv[2])
    mov rsi, [r13 + 16]     ; argv[2] - string pointer goes in rsi
    call parse_int
    test rax, rax
    js .parse_error
    mov [height], eax
    
    ; Calculate frame_size = width * height
    mov eax, [width]
    mul dword [height]
    mov [frame_size], eax
    
    ; Debug: Starting message
    mov rsi, msg_start
    call log_message

    mov edi, [width]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_width
    call log_debug

    mov edi, [height]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_height
    call log_debug

    mov edi, [frame_size]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_frame_size
    call log_debug

    ; Success
    xor rax, rax
    jmp .done
    
.usage_error:
.parse_error:
    ; Print usage message
    mov rsi, msg_usage
    call log_message
    
    mov rax, 1  ; error code
    
.done:
    pop r13
    pop r12
    pop rbp
    ret

; Main entry point
main:
    push rbp
    mov rbp, rsp
    
    ; Parse command line arguments FIRST before any syscalls
    ; Note: rdi and rsi already contain argc and argv from C runtime
    call parse_args
    test rax, rax
    jnz exit_failure
    
    ; Debug: Arguments parsed
    mov rsi, msg_args
    call log_message

    ; Test C runtime initialization with a small malloc
    ; mov rdi, 64
    ; call malloc
    ; test rax, rax
    ; jz malloc_error
    ; mov rdi, rax
    ; call free
    
    ; Load CUDA library and function pointers
    call load_cuda_library
    test rax, rax
    jz cuda_load_error
    
    ; Debug: CUDA library loaded successfully
    mov rsi, msg_cuda_loaded
    call log_message

    ; Debug: Initializing CUDA
    mov rsi, msg_cuda
    call log_message
    
    ; Initialize CUDA
    xor rdi, rdi
    call [fptr_cuInit]
    chk_cuda
    
    ; cuDeviceGet(&cuda_device, 0)
    mov rdi, cuda_device    ; pointer to store device ID
    xor rsi, rsi            ; device index = 0
    call [fptr_cuDeviceGet]
    chk_cuda
    
    ; Create context
    mov rdi, cuda_context   ; pointer to store context
    xor rsi, rsi            ; flags = 0
    xor rdx, rdx            ; clear rdx completely
    mov edx, [cuda_device]  ; device ID (zero-extended to 64-bit)
    call [fptr_cuCtxCreate]
    chk_cuda
    
    ; Set context as current
    mov rdi, [cuda_context]
    call [fptr_cuCtxSetCurrent]
    chk_cuda
    
    ; Debug variable values after CUDA init
    mov edi, [cuda_device]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_cuda_device
    call log_debug

    mov rdi, [cuda_context]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_cuda_context
    call log_debug

    mov rdi, current_context  ; pointer to store current context
    call [fptr_cuCtxGetCurrent]
    chk_cuda
    
    mov rdi, [current_context]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_current_ctx
    call log_debug
    
    ; Allocate memory
    call allocate_memory_direct
    test rax, rax
    jnz exit_failure
    
    ; Load PTX module
    call load_ptx_module
    test rax, rax
    jnz exit_failure
    
    ; Process frame
    call process_single_frame
    test rax, rax
    jnz exit_failure
    
    ; Exit
    xor rax, rax
    jmp exit_program

allocate_memory_direct:
    push rbp
    mov rbp, rsp
    
    ; Debug: Memory allocation
    mov rsi, msg_memory
    call log_message

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
    
    ; Initialize h_output to all 1s for verification
    mov rdi, [h_output]
    mov rsi, 0xFF
    mov rdx, [frame_size]
    call memset

    ; Allocate device memory for input buffer
    mov rdi, d_input          ; pointer to the pointer
    mov rsi, [frame_size]     ; size in bytes
    call [fptr_cuMemAlloc]
    chk_cuda
    
    ; Allocate device memory for output buffer
    mov rdi, d_output         ; pointer to the pointer
    mov rsi, [frame_size]     ; size in bytes
    call [fptr_cuMemAlloc]
    chk_cuda

    ; Debug: Print allocated host and device pointers
    mov rdi, [h_input]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_h_input
    call log_debug
    
    mov rdi, [h_output]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_h_output
    call log_debug
    
    mov rdi, [d_input]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_d_input
    call log_debug
    
    mov rdi, [d_output]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_d_output
    call log_debug
    
    xor eax, eax
    mov rsp, rbp
    pop rbp
    ret

load_ptx_module:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Debug: Opening PTX file
    mov rsi, msg_ptx_opening
    call log_message

    ; Open PTX file
    mov rdi, txt_zero_filter_ptx
    mov rsi, 0          ; O_RDONLY
    call open
    test rax, rax
    js file_error
    mov [rbp-8], rax    ; Store file descriptor

    mov rdi, rax
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_ret_val
    call log_debug

    ; Get file size using lseek
    mov rax, sys_lseek
    mov rdi, [rbp-8]    ; file descriptor
    mov rsi, 0          ; offset
    mov rdx, 2          ; SEEK_END
    syscall
    test rax, rax
    js file_error
    mov [rbp-16], rax   ; Store file size

    mov rdi, rax
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_ret_val
    call log_debug

    mov rdi, rax
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_ret_val
    call log_debug

    ; Debug: Mapping PTX file to memory
    mov rsi, msg_ptx_mapping
    call log_message

    ; mmap the file
    mov rax, sys_mmap
    xor rdi, rdi        ; addr = NULL
    mov rsi, [rbp-16]   ; length = file size
    mov rdx, 1          ; PROT_READ
    mov r10, 2          ; MAP_PRIVATE
    mov r8, [rbp-8]     ; file descriptor
    xor r9, r9          ; offset = 0
    syscall
    cmp rax, -1
    je mmap_error
    mov [rbp-24], rax   ; Store mmap address

    ; Close file descriptor (no longer needed after mmap)
    mov rax, sys_close
    mov rdi, [rbp-8]
    syscall

    ; Load PTX module
    mov rdi, cuda_module        ; pointer to store module
    mov rsi, [rbp-24]          ; PTX data
    call [fptr_cuModuleLoadData]
    chk_cuda
    
    mov rdi, rax
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_ptx_load_debug
    call log_debug
    
    ; Get function from module
    mov rdi, cuda_function      ; pointer to store function
    mov rsi, [cuda_module]      ; module
    mov rdx, txt_zero_filter    ; function name
    call [fptr_cuModuleGetFunction]
    chk_cuda

    ; Unmap the file
    mov rax, 11  ; sys_munmap
    mov rdi, [rbp-24]   ; address
    mov rsi, [rbp-16]   ; length
    syscall

    xor rax, rax
    add rsp, 32
    pop rbp
    ret

process_single_frame:
    push rbp
    mov rbp, rsp
    ; sub rsp, 80        ; Space for kernel parameters
    
    ; Debug: Starting frame processing
    mov rsi, msg_processing
    call log_message

    ; Debug: Reading frame from stdin
    mov rsi, msg_read
    call log_message

    ; Read frame data from stdin
    mov rax, sys_read
    mov rdi, 0                 ; stdin
    mov rsi, [h_input]         ; buffer
    mov edx, [frame_size]      ; count
    syscall
    test rax, rax
    js read_error

    ; Debug: Frame read completed
    mov rsi, msg_read_done
    call log_message

    ; Debug: Copying frame to device
    mov rsi, msg_htod
    call log_message
    
    ; Debug: Check current context before cuMemcpyHtoD
    mov rdi, current_context  ; pointer to store current context
    call [fptr_cuCtxGetCurrent]
    chk_cuda
    
    mov rdi, [current_context]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_current_ctx
    call log_debug

    ; Copy input data from host to device
    mov rdi, [d_input]        ; destination (device)
    mov rsi, [h_input]        ; source (host)
    mov rdx, [frame_size]     ; size
    call [fptr_cuMemcpyHtoD]
    chk_cuda
    
    ; Copy output data (initialized to 0xFF) from host to device
    mov rdi, [d_output]       ; destination (device)
    mov rsi, [h_output]       ; source (host, filled with 0xFF)
    mov rdx, [frame_size]     ; size
    call [fptr_cuMemcpyHtoD]
    chk_cuda
    
    ; Debug: Kernel launch
    mov rsi, msg_kernel
    call log_message

    call launch_zero_kernel

    ; Debug: Copying result from device
    mov rsi, msg_dtoh
    call log_message

    ; Copy result back to host
    mov rdi, [h_output]       ; destination (host)
    mov rsi, [d_output]       ; source (device)
    mov rdx, [frame_size]     ; size
    call [fptr_cuMemcpyDtoH]
    chk_cuda
    
    ; Debug: Writing result
    mov rsi, msg_write
    call log_message
    
    mov rax, sys_write
    mov rdi, fd_stdout
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
    mov rsi, txt_gdim_x
    call log_debug
    
    mov rdi, r9
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_gdim_y
    call log_debug
    
    mov rdi, bdim_x
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_bdim_x
    call log_debug
    
    mov rdi, bdim_y
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_bdim_y
    call log_debug
    
    pop r9
    pop r8
    
    ; Debug: Print parameter values before launch
    push r8
    push r9
    mov rdi, [d_input]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_d_input
    call log_debug
    
    mov rdi, [d_output]
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_d_output
    call log_debug
    
    mov rdi, [width]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_width
    call log_debug
    
    mov rdi, [height]
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_height
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
    call [fptr_cuLaunchKernel]
    ; add rsp, 48              ; 6 qwords = 48 bytes
    chk_cuda
    
    ; Synchronize to wait for kernel completion and check for kernel errors
    call [fptr_cuCtxSynchronize]
    chk_cuda

    mov rdi, rsp
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_rsp
    call log_debug
    
    mov rsp, rbp
    pop rbp
    ret

function_null_error:
    mov rsi, msg_memory_error  ; reuse error message
    call log_message
    mov rax, 1
    pop rbp
    ret

cleanup:
    push rbp
    mov rbp, rsp
    align_stack_16B
    
    ; Free host memory
    mov rdi, [h_input]
    test rdi, rdi
    jz .skip_h_input
    call free
    mov qword [h_input], 0
.skip_h_input:
    
    mov rdi, [h_output]
    test rdi, rdi
    jz .skip_h_output
    call free
    mov qword [h_output], 0
.skip_h_output:
    
    ; Free device memory
    mov rdi, [d_input]
    test rdi, rdi
    jz .skip_d_input
    call [fptr_cuMemFree]
    mov qword [d_input], 0
    ; Note: Not using chk_cuda here to avoid infinite recursion on exit
.skip_d_input:
    
    mov rdi, [d_output]
    test rdi, rdi
    jz .skip_d_output
    call [fptr_cuMemFree]
    mov qword [d_output], 0
    ; Note: Not using chk_cuda here to avoid infinite recursion on exit
.skip_d_output:
    
    mov rsp, rbp
    pop rbp
    ret

; Error handlers
malloc_error:
    mov rsi, msg_memory_error
    call log_message
    mov rax, 1
    jmp exit_program

cuda_load_error:
    mov rsi, msg_cuda_load_error
    call log_message
    mov rax, 1
    jmp exit_program

file_error:
mmap_error:
read_error:
    call __errno_location
    mov rdi, [rax]
    call strerror
    mov rsi, rax
    call log_message
    mov rax, 1  ; exit code
    jmp exit_program

exit_failure:
    mov rax, 1  ; exit code

; Load CUDA library and resolve all function pointers (inline version)
; Returns: rax = 1 on success, 0 on failure
exit_program:
    push rax
    call cleanup
    pop rax
    
    ; Exit with status code
    mov rdi, rax
    mov rax, sys_exit_group
    syscall
