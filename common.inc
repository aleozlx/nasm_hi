; common.inc - Shared constants and macros for NASM assembly programs
; Include this file in other assembly files with: %include "common.inc"

; Constants
sz_int32 equ 4
sz_int64 equ 8
fd_stdin equ 0
fd_stdout equ 1
fd_stderr equ 2

; Syscall numbers (Linux x86_64)
sys_read equ 0
sys_write equ 1
sys_open equ 2
sys_openat equ 257
sys_close equ 3
sys_lseek equ 8
sys_fstat equ 5
sys_mmap equ 9
sys_exit equ 60

; CUDA error checking macro
; Usage: call cuda_function
;        chk_cuda
%macro chk_cuda 0
    test rax, rax
    jnz abort_cuda
%endmacro

; Immediate abort with exit code
; Usage: abort_now 1
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

; Write debug message to stderr
; Usage: debug_write message, length
%macro debug_write 2
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, %1
    mov rdx, %2
    syscall
%endmacro
