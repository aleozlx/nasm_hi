# Project Context for Claude

## Build System
This project uses SCons for building. Run `scons` to build the project.

### CUDA Sobel Filter (Optional)
- Use `scons cuda=1` to build the CUDA Sobel filter target
- Requires NVIDIA CUDA Toolkit with nvcc and ptxas
- Creates `sobel_runner` executable and compiles PTX kernel

## Project Structure
- Assembly source files (.asm)
- SCons build configuration (SConstruct)
- `sobel_runner.asm` - NASM CUDA runner with stdin/stdout frame processing
- `sobel_filter.ptx` - PTX kernel for Sobel edge detection

## Sobel Filter Usage
Command: `sobel_runner <width> <height>`

Process raw frames with ffmpeg pipeline:
```bash
ffmpeg -i input.mp4 -f rawvideo -pix_fmt gray - | ./build/sobel_runner 1920 1080 | ffmpeg -f rawvideo -pix_fmt gray -s 1920x1080 -i - output.mp4
```

The sobel_runner expects grayscale raw frames from stdin and outputs processed frames to stdout.