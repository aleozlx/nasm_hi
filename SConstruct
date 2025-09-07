env = Environment()

env['ASFLAGS'] = ['-f', 'elf64']
env['LINKFLAGS'] = ['-nostdlib', '-no-pie']

# Build everything inside the "build" folder
import os
build_dir = 'build'
env.VariantDir(build_dir, '.', duplicate=0)

# Build both 32-bit and 64-bit versions
object_file_x32 = env.Object(os.path.join(build_dir, 'hello_x32.o'), 'hello_x32.asm', AS='nasm', ASFLAGS=['-f', 'elf32'])
executable_x32 = env.Program(os.path.join(build_dir, 'hello_x32'), object_file_x32, LINKFLAGS=['-m32', '-nostdlib', '-no-pie'])

object_file = env.Object(os.path.join(build_dir, 'hello.o'), 'hello.asm', AS='nasm')
executable = env.Program(os.path.join(build_dir, 'hello'), object_file)

# Sobel filter with CUDA support (opt-in)
def build_sobel_target():
    # Check for CUDA_PATH environment variable
    cuda_path = os.environ.get('CUDA_PATH')
    if not cuda_path:
        # Try common CUDA installation paths
        common_paths = ['/usr/local/cuda', '/opt/cuda', '/usr/cuda']
        for path in common_paths:
            if os.path.exists(path):
                cuda_path = path
                break
    
    if not cuda_path:
        raise Exception("CUDA toolkit not found. Please set CUDA_PATH environment variable or install CUDA in a standard location.")
    
    # Verify CUDA tools exist
    nvcc_path = os.path.join(cuda_path, 'bin', 'nvcc')
    if not os.path.exists(nvcc_path):
        raise Exception(f"nvcc not found at {nvcc_path}. Please check CUDA_PATH: {cuda_path}")
    
    print(f"Using CUDA toolkit at: {cuda_path}")
    
    sobel_env = Environment()
    sobel_env['ASFLAGS'] = ['-f', 'elf64', '-g', '-F', 'dwarf']  # Add debug symbols
    sobel_env['LIBS'] = ['cuda', 'c']
    
    # Use CUDA_PATH for library paths
    cuda_lib64 = os.path.join(cuda_path, 'lib64')
    sobel_env['LIBPATH'] = [cuda_lib64, '/usr/lib/x86_64-linux-gnu']
    sobel_env['LINKFLAGS'] = ['-nostdlib', '-no-pie', '-g', '-dynamic-linker', '/lib64/ld-linux-x86-64.so.2']  # Add dynamic linker explicitly
    
    # Copy existing PTX file to build directory (PTX source already exists)
    ptx_source = 'sobel_filter.ptx'
    ptx_target = os.path.join(build_dir, 'sobel_filter.ptx')
    
    if not os.path.exists(ptx_source):
        raise Exception(f"PTX source file {ptx_source} not found")
    
    # Copy PTX file to build directory
    ptx_compiled = sobel_env.Command(
        ptx_target,
        ptx_source,
        'cp $SOURCE $TARGET'
    )
    
    sobel_object = sobel_env.Object(os.path.join(build_dir, 'sobel_runner.o'), 'sobel_runner.asm', AS='nasm')
    sobel_executable = sobel_env.Program(os.path.join(build_dir, 'sobel_runner'), sobel_object)
    
    sobel0_object = sobel_env.Object(os.path.join(build_dir, 'sobel_runner0.o'), 'sobel_runner0.asm', AS='nasm')
    sobel0_executable = sobel_env.Program(os.path.join(build_dir, 'sobel_runner0'), sobel0_object)
    
    # Zero runner target
    zero_ptx_source = 'zero_filter.ptx'
    zero_ptx_target = os.path.join(build_dir, 'zero_filter.ptx')
    
    if os.path.exists(zero_ptx_source):
        zero_ptx_compiled = sobel_env.Command(
            zero_ptx_target,
            zero_ptx_source,
            'cp $SOURCE $TARGET'
        )
        
        zero_object = sobel_env.Object(os.path.join(build_dir, 'zero_runner.o'), 'zero_runner.asm', AS='nasm')
        zero_executable = sobel_env.Program(os.path.join(build_dir, 'zero_runner'), zero_object)
        
        # Add dependencies
        sobel_env.Depends(sobel_executable, ptx_compiled)
        sobel_env.Depends(sobel0_executable, ptx_compiled)
        sobel_env.Depends(zero_executable, zero_ptx_compiled)
        
        return [sobel_executable, sobel0_executable, ptx_compiled, zero_executable, zero_ptx_compiled]
    else:
        # Add dependencies
        sobel_env.Depends(sobel_executable, ptx_compiled)
        sobel_env.Depends(sobel0_executable, ptx_compiled)
        
        return [sobel_executable, sobel0_executable, ptx_compiled]

# Check for CUDA build flag
build_cuda = ARGUMENTS.get('cuda', 0)
if int(build_cuda):
    try:
        sobel_targets = build_sobel_target()
        Default(sobel_targets)
        print("CUDA Sobel filter target enabled")
    except Exception as e:
        print(f"Error: {e}")
        print("Hint: Set CUDA_PATH environment variable, e.g.:")
        print("  export CUDA_PATH=/usr/local/cuda")
        print("  scons cuda=1")
        Exit(1)
else:
    print("Use 'scons cuda=1' to build CUDA Sobel filter target")

Default([executable_x32, executable])