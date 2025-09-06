env = Environment()

env['ASFLAGS'] = ['-f', 'elf32']
env['LINKFLAGS'] = ['-m32', '-nostdlib', '-no-pie']

# Build everything inside the "build" folder
import os
build_dir = 'build'
env.VariantDir(build_dir, '.', duplicate=0)

object_file = env.Object(os.path.join(build_dir, 'hello.o'), 'hello.asm', AS='nasm')
executable = env.Program(os.path.join(build_dir, 'hello'), object_file)

Default(executable)