; common.inc - Shared constants and macros for NASM assembly programs
; Include this file in other assembly files with: %include "common.inc"

; External functions from common.asm
extern common_init
extern parse_int
extern convert_rdi_hex
extern strlen0
extern log_debug
extern log_message
extern print_cuda_error
extern print_system_error
extern abort_cuda

; Constants
sz_int32 equ 4
sz_int64 equ 8
fd_stdin equ 0
fd_stdout equ 1
fd_stderr equ 2

%macro div_up 1
    xor rdx, rdx
    add rax, %1
    dec rax
    div %1
%endmacro

; Immediate abort with exit code
; Usage: abort_now 1
%macro abort_now 1
    mov rax, sys_write
    mov rdi, fd_stderr
    mov rsi, msg_abort
    mov rdx, msg_abort_len
    syscall
    
    mov rax, sys_exit
    mov rdi, %1 ; exit code
    syscall
%endmacro

%define align_stack_16B and rsp, -16
