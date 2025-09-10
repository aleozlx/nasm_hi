env = Environment()

env['ASFLAGS'] = ['-f', 'elf64', '-I', 'src/']
env['LINKFLAGS'] = ['-nostdlib', '-no-pie']

# Build everything inside the "build" folder
import os
build_dir = 'build'
env.VariantDir(build_dir, '.', duplicate=0)

# Build both 32-bit and 64-bit versions
object_file_x32 = env.Object(os.path.join(build_dir, 'hello_x32.o'), 'src/hello_x32.asm', AS='nasm', ASFLAGS=['-f', 'elf32', '-I', 'src/'])
executable_x32 = env.Program(os.path.join(build_dir, 'hello_x32'), object_file_x32, LINKFLAGS=['-m32', '-nostdlib', '-no-pie'])

object_file = env.Object(os.path.join(build_dir, 'hello.o'), 'src/hello.asm', AS='nasm')
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
    
    # Use CUDA_PATH for library paths
    cuda_lib64 = os.path.join(cuda_path, 'targets/x86_64-linux/lib')
    cuda_stubs = os.path.join(cuda_path, 'targets/x86_64-linux/lib/stubs')

    sobel_env = Environment()
    sobel_env['ASFLAGS'] = ['-f', 'elf64', '-g', '-F', 'dwarf', '-I', 'src/']  # Add debug symbols and include path

    # Use gcc for linking - simplifies C runtime initialization
    sobel_env['LINK'] = 'gcc'
    sobel_env['LINKCOM'] = '$LINK $LINKFLAGS -o $TARGET $SOURCES $_LIBDIRFLAGS $_LIBFLAGS'
    sobel_env['LIBPATH'] = ['/usr/lib/x86_64-linux-gnu']
    
    # gcc flags - proper C runtime + dlopen for CUDA
    sobel_env['LINKFLAGS'] = [
        '-g',
        '-no-pie',
        '-ldl',        # Dynamic loading
        '-lpthread',   # Threading
        '-lc'          # C library
    ]
    
    # Build common utilities object file
    common_object = sobel_env.Object(os.path.join(build_dir, 'common.o'), 'src/common.asm', AS='nasm')
    
    # Build CUDA library loader object file
    cuda_loader_object = sobel_env.Object(os.path.join(build_dir, 'load_library_cuda.o'), 'src/load_library_cuda.asm', AS='nasm')

    # Build zero_runner
    zero_object = sobel_env.Object(os.path.join(build_dir, 'zero_runner.o'), 'src/zero_runner.asm', AS='nasm')
    zero_executable = sobel_env.Program(os.path.join(build_dir, 'zero_runner'), [zero_object, common_object, cuda_loader_object])

    # Build sobel_runner the same way as zero_runner
    sobel_object = sobel_env.Object(os.path.join(build_dir, 'sobel_runner.o'), 'src/sobel_runner.asm', AS='nasm')
    sobel_executable = sobel_env.Program(os.path.join(build_dir, 'sobel_runner'), [sobel_object, common_object, cuda_loader_object])

    return [sobel_executable, zero_executable, common_object]

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