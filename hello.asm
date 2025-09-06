section .data
    hello_msg db 'Hi!', 0xA, 0
    hello_len equ $ - hello_msg - 1
    prompt_msg db '> ', 0
    prompt_len equ $ - prompt_msg - 1
    newline db 0xA, 0

section .bss
    input_buffer resb 256

section .text
    global _start

_start:
    mov eax, 4
    mov ebx, 1
    mov ecx, hello_msg
    mov edx, hello_len
    int 0x80

input_loop:
    mov eax, 4
    mov ebx, 1
    mov ecx, prompt_msg
    mov edx, prompt_len
    int 0x80
    
    mov eax, 3
    mov ebx, 0
    mov ecx, input_buffer
    mov edx, 256
    int 0x80
    
    cmp eax, 0
    je exit_program
    
    mov edx, eax
    mov eax, 4
    mov ebx, 1
    mov ecx, input_buffer
    int 0x80
    
    jmp input_loop

exit_program:
    mov eax, 1
    mov ebx, 0
    int 0x80
