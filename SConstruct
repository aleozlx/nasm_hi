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

Default([executable_x32, executable])