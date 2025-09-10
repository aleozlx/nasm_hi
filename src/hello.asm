section .data
    hello_msg db 'Hi!', 0xA, 0
    hello_len equ $ - hello_msg - 1
    prompt_msg db '> ', 0
    prompt_len equ $ - prompt_msg - 1

section .bss
    input_buffer resb 256

section .text
    global _start

_start:
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    mov rsi, hello_msg
    mov rdx, hello_len
    syscall

input_loop:
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    mov rsi, prompt_msg
    mov rdx, prompt_len
    syscall
    
    mov rax, 0              ; sys_read
    mov rdi, 0              ; stdin
    mov rsi, input_buffer
    mov rdx, 256
    syscall
    
    cmp rax, 0
    je exit_program
    
    mov rdx, rax            ; bytes read
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    mov rsi, input_buffer
    syscall
    
    jmp input_loop

exit_program:
    mov rax, 60             ; sys_exit
    mov rdi, 0              ; exit status
    syscall