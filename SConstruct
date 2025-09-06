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
    sobel_env = Environment()
    sobel_env['ASFLAGS'] = ['-f', 'elf64']
    sobel_env['LIBS'] = ['cuda', 'cudart', 'c']
    sobel_env['LIBPATH'] = ['/usr/local/cuda/lib64', '/opt/cuda/lib64', '/usr/lib/x86_64-linux-gnu']
    sobel_env['LINKFLAGS'] = ['-nostdlib']
    
    # Compile PTX from CUDA source using ptxas
    ptx_source = 'sobel_filter.cu'
    ptx_compiled = sobel_env.Command(
        os.path.join(build_dir, 'sobel_filter.ptx'), 
        ptx_source,
        'nvcc -ptx -arch=sm_50 -o $TARGET $SOURCE'
    )
    
    sobel_object = sobel_env.Object(os.path.join(build_dir, 'sobel_runner.o'), 'sobel_runner.asm', AS='nasm')
    sobel_executable = sobel_env.Program(os.path.join(build_dir, 'sobel_runner'), sobel_object)
    
    # Add dependency
    sobel_env.Depends(sobel_executable, ptx_compiled)
    
    return [sobel_executable, ptx_compiled]

# Check for CUDA build flag
build_cuda = ARGUMENTS.get('cuda', 0)
if int(build_cuda):
    try:
        sobel_targets = build_sobel_target()
        Default(sobel_targets)
        print("CUDA Sobel filter target enabled")
    except:
        print("Warning: CUDA toolkit not found, skipping Sobel filter target")
else:
    print("Use 'scons cuda=1' to build CUDA Sobel filter target")

Default([executable_x32, executable])