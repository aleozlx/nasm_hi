# System Call Reminder

`int 0x80` is a software interrupt used for system calls in Linux on x86 architecture.

## File Operations

**Open file:**
```nasm
mov eax, 5          ; sys_open
mov ebx, filename   ; filename pointer
mov ecx, 0          ; O_RDONLY
int 0x80
```

**Read file:**
```nasm
mov eax, 3          ; sys_read
mov ebx, fd         ; file descriptor
mov ecx, buffer     ; buffer pointer
mov edx, count      ; bytes to read
int 0x80
```

**Write file:**
```nasm
mov eax, 4          ; sys_write
mov ebx, 1          ; stdout
mov ecx, message    ; message pointer
mov edx, msg_len    ; message length
int 0x80
```

**Close file:**
```nasm
mov eax, 6          ; sys_close
mov ebx, fd         ; file descriptor
int 0x80
```

## Process Management

**Exit program:**
```nasm
mov eax, 1          ; sys_exit
mov ebx, 0          ; exit status
int 0x80
```

**Fork process:**
```nasm
mov eax, 2          ; sys_fork
int 0x80
```

**Execute program:**
```nasm
mov eax, 11         ; sys_execve
mov ebx, filename   ; program path
mov ecx, argv       ; argument array
mov edx, envp       ; environment array
int 0x80
```

## Memory Management

**Break (extend heap):**
```nasm
mov eax, 45         ; sys_brk
mov ebx, new_brk    ; new break address
int 0x80
```

## Time Operations

**Get time:**
```nasm
mov eax, 13         ; sys_time
mov ebx, 0          ; time_t pointer (or 0)
int 0x80
```

**Sleep:**
```nasm
mov eax, 162        ; sys_nanosleep
mov ebx, timespec   ; timespec structure
mov ecx, 0          ; remaining time
int 0x80
```

## Directory Operations

**Create directory:**
```nasm
mov eax, 39         ; sys_mkdir
mov ebx, pathname   ; directory path
mov ecx, 0755       ; permissions
int 0x80
```

**Remove directory:**
```nasm
mov eax, 40         ; sys_rmdir
mov ebx, pathname   ; directory path
int 0x80
```