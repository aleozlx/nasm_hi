%include "syscall.inc"
%include "common.inc"
%include "load_library_cuda.inc"

section .rodata
    txt_ptx_fd db 'ptx_fd', 0
    txt_ptx_size db 'ptx_size', 0
    
    extern msg_abort
    extern msg_abort_len
    msg_usage db 'Usage: zero_runner <kernel.ptx> <width> <height>', 0xA, 0
    msg_load_library_cuda db 'Error: Failed to load CUDA library', 0xA, 0
    msg_memory_error db 'Memory allocation failed', 0xA, 0
    msg_ptx_opening db '[D] Opening PTX file: ', 0
    msg_ptx_mapping db '[D] Mapping PTX file to memory', 0xA, 0
    msg_start db '[D] Starting zero_runner...', 0xA, 0
    msg_args db '[D] Arguments parsed successfully', 0xA, 0
    msg_cuda db '[D] Initializing CUDA...', 0xA, 0
    msg_cuda_loaded db '[D] CUDA library loaded successfully', 0xA, 0
    msg_memory db '[D] Allocating memory...', 0xA, 0
    msg_load_ptx_module db '[D] Loading PTX module...', 0xA, 0
    msg_processing db '[D] Starting frame processing...', 0xA, 0
    msg_read db '[D] Reading frame from stdin...', 0xA, 0
    msg_htod db '[D] Copying frame to device...', 0xA, 0
    msg_kernel db '[D] Launching zero kernel...', 0xA, 0
    msg_dtoh db '[D] Copying result from device...', 0xA, 0
    msg_write db '[D] Writing result to stdout...', 0xA, 0
    msg_kernel_params db '[D] Setting up kernel & launch params...', 0xA, 0
    msg_exit db 0xA, '[D] Cleaning up and exiting...', 0xA, 0

    ; Debug variable names
    txt_width db 'width', 0
    txt_height db 'height', 0
    txt_frame_size db 'frame_size', 0
    txt_ret_val db '(ret_val)', 0
    txt_cuda_device db 'cuda_device', 0
    txt_cuda_context db 'cuda_context', 0
    txt_cuda_function db 'cuda_function', 0
    txt_current_ctx db 'current_ctx', 0
    txt_stored_ctx db 'stored_ctx', 0
    txt_d_input db 'd_input', 0
    txt_d_output db 'd_output', 0
    txt_h_input db 'h_input', 0
    txt_h_output db 'h_output', 0
    txt_rsp db '$rsp', 0
    txt_exit_code db 'exit_code', 0

section .bss
    arg_ptx_path resq 1          ; Pointer to PTX file path (from argv[1])
    arg_kernel_name resb 64      ; Kernel name (filename without .ptx extension)
    arg_width resd 1
    arg_height resd 1
    arg_frame_size resd 1
    
    d_input resq 1
    d_output resq 1
    h_input resq 1
    h_output resq 1

    cuda_context resq 2
    cuda_device resd 1
    cuda_module resq 1
    cuda_function resq 1

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
    extern atoi

; Parse command line arguments
; Input: rdi = argc, rsi = argv
; Output: sets PTX path, kernel name, width and height variables
; Returns: rax = 0 if successful, 1 if error
; Clobbers: rdi, rsi, rcx
parse_args:

    ; Debug: Starting message
    mov rsi, msg_start
    call log_message
    
    ; Check if we have exactly 4 arguments (program name + kernel.ptx + width + height)
    cmp rcx, 4
    jne .usage_error
    
    ; Store PTX path pointer (argv[1])
    mov rax, [rbx + 8]      ; argv[1] - PTX file path
    mov [arg_ptx_path], rax ; store pointer directly
    
    ; Extract kernel name (filename without .ptx extension)
    mov rsi, rax            ; PTX path (source)
    mov rdi, arg_kernel_name ; destination buffer
    call extract_kernel_name

    ; mov rsi, arg_kernel_name
    ; call log_message
    
    ; Parse width (argv[2])
    mov rdi, [rbx + 16]
    call atoi  ; clobbers rsi
    mov [arg_width], eax

    mov edi, eax
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_width
    call log_debug
    
    ; Parse height (argv[3])
    mov rdi, [rbx + 24]
    call atoi  ; clobbers rsi
    mov [arg_height], eax

    mov edi, eax
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_height
    call log_debug
    
    ; Calculate frame_size = width * height
    mov eax, [arg_width]
    mul dword [arg_height]
    mov [arg_frame_size], eax
    
    mov edi, eax
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_frame_size
    call log_debug

    xor rax, rax
    jmp .done
    
.usage_error:
    mov rsi, msg_usage
    call log_message
    jmp exit_failure
    
.done:
    mov rsi, msg_args
    call log_message
    ret

; Main entry point
main:
    push rbp
    mov rbp, rsp
    mov rbx, rsi  ; argv
    mov rcx, rdi  ; argc

.global_init:
    push rcx
    call common_init
    pop rcx

    call parse_args
    
    ; Load CUDA library and function pointers
    call load_cuda_library
    test rax, rax
    jz fail_load_library_cuda
    
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
    
    call allocate_memory
    call load_ptx_module
    call process_single_frame
    
    ; Exit
    xor rax, rax
    jmp exit_program

allocate_memory:
    push rbp
    mov rbp, rsp
    
    ; Debug: Memory allocation
    mov rsi, msg_memory
    call log_message

    ; Allocate host memory for input buffer
    mov rdi, [arg_frame_size]
    call malloc
    test rax, rax
    jz fail_malloc_error
    mov [h_input], rax
    
    ; Allocate host memory for output buffer
    mov rdi, [arg_frame_size]
    call malloc
    test rax, rax
    jz fail_malloc_error
    mov [h_output], rax
    
    ; Initialize h_output to all 1s for verification
    mov rdi, [h_output]
    mov rsi, 0xFF
    mov rdx, [arg_frame_size]
    call memset

    ; Allocate device memory for input buffer
    mov rdi, d_input          ; pointer to the pointer
    mov rsi, [arg_frame_size]     ; size in bytes
    call [fptr_cuMemAlloc]
    chk_cuda
    
    ; Allocate device memory for output buffer
    mov rdi, d_output         ; pointer to the pointer
    mov rsi, [arg_frame_size]     ; size in bytes
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
    
.done:
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
    mov rsi, [arg_ptx_path]
    call log_message

    ; Open PTX file
    mov rdi, [arg_ptx_path]
    mov rsi, 0          ; O_RDONLY
    call open
    test rax, rax
    js fail_os_error
    mov [rbp-8], rax    ; Store file descriptor

    mov rdi, rax
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_ptx_fd
    call log_debug

    ; Get file size using lseek
    mov rax, sys_lseek
    mov rdi, [rbp-8]    ; file descriptor
    mov rsi, 0          ; offset
    mov rdx, 2          ; SEEK_END
    syscall
    test rax, rax
    js fail_os_error
    mov [rbp-16], rax   ; Store file size

    mov rdi, rax
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_ptx_size
    call log_debug

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
    je fail_os_error
    mov [rbp-24], rax   ; Store mmap address

    ; Close file descriptor (no longer needed after mmap)
    mov rax, sys_close
    mov rdi, [rbp-8]
    syscall

    ; Load PTX module
    mov rsi, msg_load_ptx_module
    call log_message

    mov rdi, cuda_module        ; pointer to store module
    mov rsi, [rbp-24]          ; PTX data
    call [fptr_cuModuleLoadData]
    chk_cuda
    
    ; Get function from module
    mov rdi, cuda_function      ; pointer to store function
    mov rsi, [cuda_module]      ; module
    mov rdx, arg_kernel_name    ; function name
    call [fptr_cuModuleGetFunction]
    chk_cuda

    mov rax, [cuda_function]
    mov rdi, rax
    mov rcx, sz_int64
    call convert_rdi_hex
    mov rsi, txt_cuda_function
    call log_debug

    ; Unmap the file
    mov rax, 11  ; sys_munmap
    mov rdi, [rbp-24]   ; address
    mov rsi, [rbp-16]   ; length
    syscall

.done:
    add rsp, 32
    pop rbp
    ret

process_single_frame:
    push rbp
    mov rbp, rsp
    
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
    mov edx, [arg_frame_size]      ; count
    syscall
    test rax, rax
    js fail_os_error

    mov rdi, rax
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_ret_val
    call log_debug

    ; Debug: Copying frame to device
    mov rsi, msg_htod
    call log_message

    ; Copy input data from host to device
    mov rdi, [d_input]        ; destination (device)
    mov rsi, [h_input]        ; source (host)
    mov rdx, [arg_frame_size]     ; size
    call [fptr_cuMemcpyHtoD]
    chk_cuda
    
    ; Copy output data (initialized to 0xFF) from host to device
    mov rdi, [d_output]       ; destination (device)
    mov rsi, [h_output]       ; source (host, filled with 0xFF)
    mov rdx, [arg_frame_size]     ; size
    call [fptr_cuMemcpyHtoD]
    chk_cuda
    
    call launch_zero_kernel

    ; Debug: Copying result from device
    mov rsi, msg_dtoh
    call log_message

    ; Copy result back to host
    mov rdi, [h_output]       ; destination (host)
    mov rsi, [d_output]       ; source (device)
    mov rdx, [arg_frame_size]     ; size
    call [fptr_cuMemcpyDtoH]
    chk_cuda
    
    ; Debug: Writing result
    mov rsi, msg_write
    call log_message
    
    mov rax, sys_write
    mov rdi, fd_stdout
    mov rsi, [h_output]       ; Write from host buffer
    mov edx, [arg_frame_size]
    syscall
    test rax, rax
    js fail_os_error

    mov rdi, rax
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_ret_val
    call log_debug
    
.done:
    mov rsp, rbp
    pop rbp
    ret

launch_zero_kernel:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov rsi, msg_kernel_params
    call log_message
    
    ; Prepare kernel parameters
    mov qword [rbp-56], d_input    ; params[0] = &d_input
    mov qword [rbp-48], d_output    ; params[1] = &d_output  
    mov qword [rbp-40], arg_width    ; params[2] = &arg_width
    mov qword [rbp-32], arg_height    ; params[3] = &arg_height
    
    ; Calculate grid dimensions
    kBLOCK_DIM_X equ 16
    kBLOCK_DIM_Y equ 16
    mov r8d, kBLOCK_DIM_X
    mov r9d, kBLOCK_DIM_Y

    mov eax, [arg_width]
    div_up r8
    mov r8d, eax
    
    mov eax, [arg_height]
    div_up r9
    mov r9d, eax
    
    ; Debug: Kernel launch
    mov rsi, msg_kernel
    call log_message

    ; Debug: Check if cuda_function is valid
    mov rax, [cuda_function]
    test rax, rax
    jz .error_kernel_null_fptr
    
    ; cuLaunchKernel parameters: f, gridX, gridY, gridZ, blockX, blockY, blockZ, sharedMem, stream, params, extra
    mov rdi, [cuda_function]  ; f
    mov rsi, r8              ; gridDimX  
    mov rdx, r9              ; gridDimY
    mov rcx, 1               ; gridDimZ
    mov r8d, kBLOCK_DIM_X          ; blockDimX
    mov r9d, kBLOCK_DIM_Y          ; blockDimY
    
    ; Ensure 16-byte stack alignment before call
    ; We're pushing 5 qwords (40 bytes), so add 8 bytes padding
    push 0                   ; padding for alignment, otherwise causing SSE segfault, eg. movaps
    push 0                   ; extra (NULL)
    lea rax, [rbp-56]        ; kernelParams array (start from the last parameter)
    push rax                 
    push 0                   ; hStream (NULL)
    push 0                   ; sharedMemBytes
    push 1                   ; blockDimZ
    
    call log_kernel_launch
    call [fptr_cuLaunchKernel]
    chk_cuda
    
    call [fptr_cuCtxSynchronize]
    chk_cuda
    jmp .done

.error_kernel_null_fptr:
    mov rsi, msg_memory_error  ; reuse error message
    call log_message
    jmp exit_failure

.done:
    mov rsp, rbp
    pop rbp
    ret

; Clobbers: rax, rdi
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
    ; Note: Not using chk_cuda here to avoid infinite recursion on exit
    mov qword [d_input], 0
.skip_d_input:
    
    mov rdi, [d_output]
    test rdi, rdi
    jz .skip_d_output
    call [fptr_cuMemFree]
    ; Note: Not using chk_cuda here to avoid infinite recursion on exit
    mov qword [d_output], 0
.skip_d_output:
    
.done:
    mov rsp, rbp
    pop rbp
    ret

; Error handlers
fail_malloc_error:
    mov rsi, msg_memory_error
    call log_message
    jmp exit_failure

fail_load_library_cuda:
    mov rsi, msg_load_library_cuda
    call log_message
    jmp exit_failure

fail_os_error:
    call __errno_location
    mov rdi, [rax]
    call strerror
    mov rsi, rax
    call log_message
    jmp exit_failure

exit_failure:
    mov rax, 1  ; exit code

; Returns: rax = 1 on success, 0 on failure
exit_program:
    push rax
    mov rsi, msg_exit
    call log_message
    mov rdi, rax
    mov rcx, sz_int32
    call convert_rdi_hex
    mov rsi, txt_exit_code
    call log_debug

    call cleanup ; clobbers rax, rdi
    
    ; Exit with status code
    pop rdi ; exit code
    mov rax, sys_exit_group
    syscall
