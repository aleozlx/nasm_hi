; load_library_cuda.inc - Include file for CUDA library loading
; Provides externs and constants for dynamic CUDA library loading

; External function to load CUDA library
extern load_cuda_library
extern log_kernel_launch

; External CUDA function pointers (defined in load_library_cuda.asm)
extern fptr_cuInit
extern fptr_cuDeviceGet
extern fptr_cuCtxCreate
extern fptr_cuCtxSetCurrent
extern fptr_cuCtxGetCurrent
extern fptr_cuMemAlloc
extern fptr_cuMemAllocManaged
extern fptr_cuMemFree
extern fptr_cuMemcpyHtoD
extern fptr_cuMemcpyDtoH
extern fptr_cuModuleLoadData
extern fptr_cuModuleGetFunction
extern fptr_cuLaunchKernel
extern fptr_cuCtxSynchronize
extern fptr_cuGetErrorString

; CUDA error checking macro
; Usage: call cuda_function
;        chk_cuda
%macro chk_cuda 0
    test rax, rax
    jnz abort_cuda
%endmacro
