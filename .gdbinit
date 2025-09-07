# GDB initialization for zero_runner debugging
set confirm off
set verbose off

# Set architecture and disassembly format
set architecture i386:x86-64
set disassembly-flavor intel

# Display settings
set print pretty on
set print array on
set print array-indexes on

# Default arguments for zero_runner
set args 64 64

# Input redirection setup (user needs to run: gdb ./build/zero_runner < test_input.raw)
# Or use: (gdb) run < test_input.raw

# Key breakpoints - focused on kernel launch issue
# break _start
# break init_cuda
# break allocate_memory  
# break load_ptx_module
# break process_single_frame
break launch_zero_kernel

# CUDA-specific breakpoints - more targeted
# break cuInit
# Break right before cuLaunchKernel call in launch_zero_kernel
break *launch_zero_kernel+200

# Display useful info at each stop
define hook-stop
    echo \n=== BREAKPOINT HIT ===\n
    info registers rdi rsi rcx rdx rax rbx
    x/5i $pc
end

# Custom commands
define show-cuda-params
    echo \n=== CUDA Launch Parameters ===\n
    printf "Grid: %d x %d\n", $r8d, $r9d
    printf "Block: 16 x 16\n"
    printf "Width: %d, Height: %d\n", *(int*)&width, *(int*)&height
end

define show-memory
    echo \n=== Memory Pointers ===\n
    printf "input_buffer: %p\n", *(long*)&input_buffer
    printf "output_buffer: %p\n", *(long*)&output_buffer  
    printf "d_input: %p\n", *(long*)&d_input
    printf "d_output: %p\n", *(long*)&d_output
end

define show-hex-buffer
    echo \n=== Hex Buffer Contents ===\n
    x/20c hex_buffer
end

# Show cuLaunchKernel parameters (call this when at the cuLaunchKernel call)
define show-launch-params
    echo \n=== cuLaunchKernel Parameters ===\n
    printf "function: %p\n", $rdi
    printf "gridDimX: %d\n", $rsi  
    printf "gridDimY: %d\n", $rdx
    printf "gridDimZ: %d\n", $rcx
    echo \nStack parameters (blocks, shared mem, etc):\n
    x/8xg $rsp
end

# Start at the beginning
echo \n=== GDB Ready for zero_runner debugging ===\n
echo Auto-running with: run 64 64 < test_input.raw\n
echo Custom commands: show-cuda-params, show-memory, show-hex-buffer\n

# Automatically start debugging
run 64 64 < test_input.raw
