env = Environment()

env['ASFLAGS'] = ['-f', 'elf32']
env['LINKFLAGS'] = ['-m32', '-nostdlib', '-no-pie']

object_file = env.Object('hello.o', 'hello.asm', AS='nasm')
executable = env.Program('hello', object_file)

Default(executable)