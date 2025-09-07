# CLAUDE Development Notes

## Project Overview
This project demonstrates CUDA kernel execution from pure NASM assembly without relying on the C standard library. The main challenge was creating a runtime environment that satisfies CUDA's dependencies while maintaining a `-nostdlib` approach.

## Key Technical Achievement
**Successfully implemented a separate C runtime library approach** that allows NASM assembly programs to use CUDA Driver API through dynamic loading (`dlopen`/`dlsym`) while keeping the main program completely standard library-free.

## Architecture

### Core Components
1. **Main Program**: `zero_runner.asm` - Pure NASM assembly with `-nostdlib`
2. **Runtime Library**: `runtime_init.c` - Provides C runtime functions via shared library
3. **CUDA Kernel**: `zero_filter.ptx` - GPU kernel for zeroing image data
4. **Build System**: `SConstruct` - SCons-based build with proper dependency management

### Memory Management Strategy
- **Host Memory**: Custom `mmap`-based allocator in runtime library
- **Device Memory**: CUDA Driver API (`cuMemAlloc`)
- **Data Transfer**: Explicit `cuMemcpyHtoD`/`cuMemcpyDtoH` calls
- **Dynamic Loading**: Runtime functions loaded via `dlopen`/`dlsym`

## Critical Debugging Workflow

### 1. Systematic Error Isolation
**Pattern**: Start broad, narrow down incrementally
- Begin with high-level error (e.g., "CUDA Error 0xC9")
- Add extensive debug output at each step
- Test small changes iteratively
- Use comparison with working C programs

### 2. Tool-Driven Investigation
**Essential Tools**:
- `nm`: Symbol analysis (`nm libcuda.so | grep malloc`)
- `ldd`: Dynamic library dependencies
- `strace`: System call tracing (especially for NVIDIA driver ioctls)
- `gdb`: Precise crash location and register state
- `compute-sanitizer`: CUDA-specific memory error detection

### 3. Root Cause Analysis Process
1. **Symptom**: Observe the error (segfault, CUDA error, etc.)
2. **Hypothesis**: Form theory about the cause
3. **Minimal Test**: Create smallest possible reproduction
4. **Comparison**: Build equivalent working C version
5. **Tool Analysis**: Use appropriate debugging tools
6. **Incremental Fix**: Apply smallest possible change
7. **Verification**: Test the fix thoroughly

## Major Issues Encountered & Solutions

### Issue 1: CUDA Error 0xC9 (CUDA_ERROR_NOT_INITIALIZED)
**Root Cause**: Incorrect `cuGetErrorString` usage (passing `CUresult` instead of `CUresult*`)
**Solution**: 
```asm
cuda_error_string_ptr resq 1  ; Pointer storage in BSS
; Pass address of pointer to cuGetErrorString
lea rdi, [cuda_error_string_ptr]
mov rsi, rax  ; CUresult error code
call cuGetErrorString
```

### Issue 2: CUDA_ERROR_INVALID_CONTEXT (201)
**Root Cause**: Missing `cuCtxSetCurrent` after `cuCtxCreate`
**Solution**: CUDA contexts must be explicitly set as current for the thread
```asm
call cuCtxCreate
chk_cuda
mov rdi, [cuda_context]
call cuCtxSetCurrent  ; Critical addition
chk_cuda
```

### Issue 3: Memory Allocation Failures
**Root Cause**: `-nostdlib` prevents glibc heap initialization
**Solution**: Separate runtime library with custom allocator
```c
// runtime_init.c
static void* heap_start = NULL;
void* runtime_malloc(size_t size) {
    // Custom mmap-based allocator
    if (!heap_initialized) initialize_heap();
    // Bump allocator implementation
}
```

### Issue 4: PTX Compilation Error (CUDA_ERROR_INVALID_PTX)
**Root Cause**: `st.global.u8` instruction incompatible with target architecture
**Solution**: Use `st.global.u32` with proper alignment
```ptx
// Before (failed):
st.global.u8 [%output_ptr + %idx], 0;

// After (working):
shl.b32 %idx, %idx, 2;              // 4-byte alignment
cvt.u64.u32 %idx64, %idx;
add.u64 %output_ptr, %output_ptr, %idx64;
st.global.u32 [%output_ptr], %zero;  // 32-bit store
```

### Issue 5: Syscall Error Handling
**Root Cause**: Misunderstanding Linux syscall return conventions
**Solution**: Positive values are success for file operations
```asm
; Wrong:
call openat
test rax, rax
js fs_error  ; Treats positive FD as error

; Correct:
call openat
cmp rax, 0
jl fs_error  ; Only negative values are errors
```

## Dynamic Linking Strategy

### Why This Approach Works
1. **Main Program Isolation**: NASM program stays completely `-nostdlib`
2. **Runtime Separation**: C runtime complexity isolated in shared library
3. **Selective Loading**: Only load functions actually needed
4. **CUDA Compatibility**: Shared libraries get proper runtime environment

### Implementation Pattern
```asm
; 1. Load runtime library
mov rdi, runtime_lib_name     ; "./build/libruntime_init.so"
mov rsi, 1                    ; RTLD_LAZY
call dlopen
mov [runtime_handle], rax

; 2. Resolve function symbols
mov rdi, [runtime_handle]
mov rsi, malloc_name          ; "runtime_malloc"
call dlsym
mov [malloc_ptr], rax

; 3. Use function pointers
mov rdi, [frame_size]
call [malloc_ptr]             ; Indirect call through pointer
```

## Build System Evolution

### Final SConstruct Structure
```python
# Separate environments for different components
runtime_env = Environment()
runtime_env['LIBS'] = ['pthread', 'c']
runtime_lib = runtime_env.SharedLibrary('runtime_init', 'runtime_init.c')

sobel_env = Environment()
sobel_env['LIBS'] = ['cuda', 'dl', 'pthread', 'c']  # Note: 'c' for dlopen/dlsym
sobel_env['LINKFLAGS'] = ['-nostdlib', '-no-pie', '-g', '-dynamic-linker', '/lib64/ld-linux-x86-64.so.2']
```

## Key Insights & Best Practices

### 1. Incremental Development
- **Never change multiple things simultaneously**
- Add one debug message, test, add another
- Each change should be verifiable independently
- Keep working versions for comparison

### 2. Debug Output Strategy
```asm
; Extensive debug output pattern:
mov rdi, some_value
mov rcx, sz_int64
call convert_rdi_hex
mov rsi, debug_msg
call log_debug
```

### 3. Error Handling Patterns
```asm
; Consistent error checking:
call cuda_function
chk_cuda              ; Macro for consistent error handling

; Syscall error checking:
call syscall_function
cmp rax, 0
jl error_handler      ; Negative = error for most syscalls
```

### 4. Memory Management Discipline
- **Always initialize pointers to zero**
- **Check for null before freeing**
- **Use consistent allocation/deallocation patterns**
- **Separate host and device memory clearly**

### 5. CUDA Best Practices
- **Always call `cuCtxSetCurrent` after `cuCtxCreate`**
- **Use `cuCtxSynchronize` after kernel launches**
- **Check errors after every CUDA call**
- **Prefer explicit memory transfers over unified memory for debugging**

## Current Status (as of latest session)

### ✅ Working Components
- Runtime library loading via `dlopen`/`dlsym`
- Custom memory allocation (mmap-based)
- CUDA context creation and management
- PTX module loading and compilation
- Device memory allocation
- Host-to-device memory transfers
- Kernel launch parameter setup

### ❌ Current Issue
- Segfault in `cuLaunchKernel` call
- Likely related to parameter passing or stack alignment
- Grid/block dimensions are calculated correctly
- All prerequisite steps complete successfully

### 🔄 Next Steps
1. Debug `cuLaunchKernel` parameter setup
2. Verify C ABI compliance for function calls
3. Test kernel execution and output verification
4. Optimize performance and cleanup debug output

## Lessons for Future Development

### 1. Start with Working Examples
Always create a minimal working C version first, then port to assembly incrementally.

### 2. Embrace Verbose Debugging
Debug output is cheap compared to debugging time. Add extensive logging early.

### 3. Understand the Full Stack
Know the dependencies: syscalls → glibc → CUDA Driver → GPU hardware

### 4. Tool Mastery is Critical
Invest time learning `nm`, `ldd`, `strace`, `gdb` - they save hours of guesswork.

### 5. Separate Concerns Aggressively
The runtime library approach proves that separation of concerns enables complex integrations.

## References & Resources
- CUDA Driver API Documentation
- Linux System Call Reference
- x86-64 ABI Specification
- NASM Manual
- PTX ISA Documentation

---
*This document captures the iterative debugging process and architectural decisions that led to a working CUDA-enabled NASM assembly program.*