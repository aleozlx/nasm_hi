; common.asm - Common utility functions for NASM assembly programs
; Contains: logging, string handling, conversion, and abort utilities

; Constants needed by common functions
sz_int32 equ 4
sz_int64 equ 8
fd_stdin equ 0
fd_stdout equ 1
fd_stderr equ 2
sys_read equ 0
sys_write equ 1
sys_exit equ 60

section .rodata
    hex_chars db '0123456789ABCDEF'

section .data
    cuda_error_msg db 'CUDA Error: ', 0
    cuda_error_len equ $ - cuda_error_msg - 1
    
    cuda_fallback_msg db '<cuGetErrorString failed>', 0
    cuda_fallback_len equ $ - cuda_fallback_msg - 1
    
    os_error_prefix db 'OS Error: ', 0
    os_error_prefix_len equ $ - os_error_prefix - 1
    
    newline db 0xA, 0
    
    
    hex_buffer db '0x0000000000000000', 0  ; "0x" + 16 hex digits + null terminator
    debug_buffer_safety db 0  ; safety null terminator for debug_buffer
    
    debug_prefix db '[D] ', 0
    debug_prefix_len equ $ - debug_prefix - 1
    debug_separator db ' = ', 0
    debug_separator_len equ $ - debug_separator - 1

    msg_abort db '[D] Abort!', 0xA, 0
    msg_abort_len equ $ - msg_abort - 1

section .bss
    debug_buffer resb 64  ; buffer for formatted debug output
    cuda_error_string_ptr resq 1  ; pointer to error string from cuGetErrorString

section .text
    ; Export all utility functions
    global hex_chars
    global convert_rdi_hex
    global strlen0
    global log_debug
    global print_cuda_error
    global print_system_error
    global abort_cuda
    global log_message
    global msg_abort
    global msg_abort_len
    
    ; External functions we need
    extern fptr_cuGetErrorString  ; CUDA function pointer from load_library_cuda module
    extern strerror
    extern __errno_location


; Convert integer to hexadecimal string
; Input: rdi = value to convert, rcx = bytes to output
; Output: hex_buffer contains "0x" + hex digits + null terminator
convert_rdi_hex:
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

; Calculate length of null-terminated string
; Input: rsi = null-terminated string
; Output: rcx = string length
; Clobbers: rax, rcx, rdi
strlen0:
    push rdi      ; save caller's rdi since repne scasb modifies it
    
    mov rcx, -1   ; no size limit
    xor al, al    ; store null terminator in al
    mov rdi, rsi  ; repne scasb uses rdi
    repne scasb   ; scan for null, rcx will be -(length+1)
    neg rcx
    dec rcx       ; rcx now has string length
    
    pop rdi       ; restore caller's rdi
    ret

; Log a message to stderr (new line not included)
; Input: rsi = message string
; Output: none
; Clobbers: nothing
log_message:
    push rax
    push rcx
    push rdx
    push rdi

    call strlen0
    
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rdx, rcx
    syscall
    
    pop rdi
    pop rdx
    pop rcx
    pop rax
    ret

; Debug logging function
; Input: rsi = variable name string (null terminated)
;        hex_buffer should contain the hex value to print
log_debug:
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

; Print CUDA error with readable message
; Input: rax = CUDA error code
print_cuda_error:
    push rbp
    mov rbp, rsp
    push rdi
    push rsi
    push rdx
    push rcx
    push rax
    
    ; Print "CUDA Error: " prefix
    mov rsi, cuda_error_msg
    call log_message
    
    ; Check if CUDA library is loaded and cuGetErrorString is available
    mov rax, [fptr_cuGetErrorString]
    test rax, rax
    jz .print_fallback_error  ; if function pointer is null, use fallback
    
    ; Get error string from CUDA  
    pop rax  ; restore error code
    push rax ; save it again
    mov rdi, rax  ; error code as first parameter
    mov rsi, cuda_error_string_ptr  ; pointer to pointer for output string
    call [fptr_cuGetErrorString]
    ; rax now contains the result code, cuda_error_string_ptr contains the string pointer
    
    ; Check if cuGetErrorString succeeded and string pointer is valid
    test rax, rax
    jnz .print_fallback_error  ; if cuGetErrorString failed
    mov rax, [cuda_error_string_ptr]  ; load the actual string pointer
    test rax, rax
    jz .print_fallback_error   ; if string pointer is null, use fallback
    
    ; Use the CUDA error string
    mov qword [cuda_error_string_ptr], rax
    jmp .print_cuda_error_string
    
.print_fallback_error:
    ; Use fallback message (always for now)
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
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    mov rsp, rbp
    pop rbp
    ret

; Print system error using errno
print_system_error:
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

; CUDA error abort handler
abort_cuda:
    call print_cuda_error
    
    ; Exit with code 1
    mov rax, sys_exit
    mov rdi, 1
    syscall
