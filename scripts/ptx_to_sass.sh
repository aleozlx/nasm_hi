#!/bin/bash

#
# PTX to SASS Compiler and Disassembler Script
# 
# This script compiles a PTX kernel to cubin format and then disassembles
# it to SASS (Streaming ASSembler) format using NVIDIA's tools.
#
# Usage: ./ptx_to_sass.sh <input.ptx> [output_basename]
#
# Arguments:
#   input.ptx       - Input PTX file to compile and disassemble
#   output_basename - Optional base name for output files (default: same as input)
#
# Output files:
#   <basename>.cubin - Compiled CUDA binary
#   <basename>.sass  - Disassembled SASS code
#
# Environment:
#   CUDA_PATH - Path to CUDA installation (required)
#
# Example:
#   CUDA_PATH=/a/cuda-12.9 ./ptx_to_sass.sh kernels/sobel_filter.ptx
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <input.ptx> [output_basename]"
    echo ""
    echo "Arguments:"
    echo "  input.ptx       - Input PTX file to compile and disassemble"
    echo "  output_basename - Optional base name for output files (default: same as input)"
    echo ""
    echo "Environment Variables:"
    echo "  CUDA_PATH - Path to CUDA installation (required)"
    echo ""
    echo "Example:"
    echo "  CUDA_PATH=/a/cuda-12.9 $0 kernels/sobel_filter.ptx"
    echo "  CUDA_PATH=/a/cuda-12.9 $0 kernels/sobel_filter.ptx my_kernel"
}

# Check arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    print_error "Invalid number of arguments"
    show_usage
    exit 1
fi

# Check if CUDA_PATH is set
if [ -z "$CUDA_PATH" ]; then
    print_error "CUDA_PATH environment variable is not set"
    print_info "Please set CUDA_PATH to your CUDA installation directory"
    print_info "Example: export CUDA_PATH=/usr/local/cuda"
    exit 1
fi

# Check if CUDA_PATH directory exists
if [ ! -d "$CUDA_PATH" ]; then
    print_error "CUDA_PATH directory does not exist: $CUDA_PATH"
    exit 1
fi

# Set CUDA tool paths
PTXAS="$CUDA_PATH/bin/ptxas"
NVDISASM="$CUDA_PATH/bin/nvdisasm"

# Check if CUDA tools exist
if [ ! -f "$PTXAS" ]; then
    print_error "ptxas not found at: $PTXAS"
    print_info "Please ensure CUDA_PATH points to a valid CUDA installation"
    exit 1
fi

if [ ! -f "$NVDISASM" ]; then
    print_error "nvdisasm not found at: $NVDISASM"
    print_info "Please ensure CUDA_PATH points to a valid CUDA installation"
    exit 1
fi

# Get input file
INPUT_PTX="$1"

# Check if input file exists
if [ ! -f "$INPUT_PTX" ]; then
    print_error "Input PTX file does not exist: $INPUT_PTX"
    exit 1
fi

# Determine output basename
if [ $# -eq 2 ]; then
    OUTPUT_BASENAME="$2"
else
    # Remove directory path and .ptx extension from input file
    OUTPUT_BASENAME=$(basename "$INPUT_PTX" .ptx)
fi

# Set output file paths
OUTPUT_CUBIN="${OUTPUT_BASENAME}.cubin"
OUTPUT_SASS="${OUTPUT_BASENAME}.sass"

print_info "Starting PTX to SASS conversion process"
print_info "Input PTX file: $INPUT_PTX"
print_info "Output cubin file: $OUTPUT_CUBIN"
print_info "Output SASS file: $OUTPUT_SASS"
print_info "Using CUDA installation: $CUDA_PATH"

# Step 1: Compile PTX to cubin
print_info "Step 1: Compiling PTX to cubin using ptxas..."
if "$PTXAS" -v -arch=sm_52 -o "$OUTPUT_CUBIN" "$INPUT_PTX"; then
    print_success "PTX compilation completed successfully"
else
    print_error "PTX compilation failed"
    exit 1
fi

# Check if cubin file was created
if [ ! -f "$OUTPUT_CUBIN" ]; then
    print_error "Cubin file was not created: $OUTPUT_CUBIN"
    exit 1
fi

print_info "Cubin file size: $(stat -c%s "$OUTPUT_CUBIN") bytes"

# Step 2: Disassemble cubin to SASS
print_info "Step 2: Disassembling cubin to SASS using nvdisasm..."
if "$NVDISASM" -c "$OUTPUT_CUBIN" > "$OUTPUT_SASS"; then
    print_success "SASS disassembly completed successfully"
else
    print_error "SASS disassembly failed"
    # Clean up cubin file on failure
    rm -f "$OUTPUT_CUBIN"
    exit 1
fi

# Check if SASS file was created and has content
if [ ! -f "$OUTPUT_SASS" ]; then
    print_error "SASS file was not created: $OUTPUT_SASS"
    rm -f "$OUTPUT_CUBIN"
    exit 1
fi

if [ ! -s "$OUTPUT_SASS" ]; then
    print_error "SASS file is empty: $OUTPUT_SASS"
    rm -f "$OUTPUT_CUBIN" "$OUTPUT_SASS"
    exit 1
fi

print_info "SASS file size: $(stat -c%s "$OUTPUT_SASS") bytes"

# Show summary
print_success "Conversion completed successfully!"
print_info "Generated files:"
print_info "  - Cubin binary: $OUTPUT_CUBIN"
print_info "  - SASS assembly: $OUTPUT_SASS"

# Show first few lines of SASS output
print_info "Preview of generated SASS code:"
echo "----------------------------------------"
head -n 20 "$OUTPUT_SASS" || true
echo "----------------------------------------"
print_info "Use 'cat $OUTPUT_SASS' to view the complete SASS code"
