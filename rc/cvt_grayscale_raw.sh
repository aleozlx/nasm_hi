#!/bin/bash

# Enhanced grayscale conversion script
# Converts between JPEG and raw grayscale formats
# Usage: ./cvt_grayscale_raw.sh <source_file> <dest_file>

show_usage() {
    echo "Usage: $0 <source_file> <dest_file>"
    echo ""
    echo "Converts between JPEG and raw grayscale formats:"
    echo "  JPEG → RAW: Converts any JPEG to grayscale raw frame file"
    echo "  RAW → JPEG: Converts raw grayscale data to JPEG"
    echo ""
    echo "Examples:"
    echo "  $0 image.jpeg image.raw      # JPEG to raw"
    echo "  $0 data.raw output.jpeg      # Raw to JPEG"
    echo ""
    echo "Note: For RAW→JPEG conversion, the script will attempt to"
    echo "      detect dimensions or prompt for width/height if needed."
}

# Check arguments
if [ $# -ne 2 ]; then
    echo "Error: Wrong number of arguments"
    show_usage
    exit 1
fi

SOURCE_FILE="$1"
DEST_FILE="$2"

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file '$SOURCE_FILE' not found!"
    exit 1
fi

# Get file extensions
SOURCE_EXT="${SOURCE_FILE##*.}"
DEST_EXT="${DEST_FILE##*.}"

# Convert to lowercase for comparison
SOURCE_EXT=$(echo "$SOURCE_EXT" | tr '[:upper:]' '[:lower:]')
DEST_EXT=$(echo "$DEST_EXT" | tr '[:upper:]' '[:lower:]')

echo "=== Grayscale Conversion ==="
echo "Source: $SOURCE_FILE (.$SOURCE_EXT)"
echo "Destination: $DEST_FILE (.$DEST_EXT)"
echo ""

# Determine conversion type
if [[ "$SOURCE_EXT" =~ ^(jpg|jpeg)$ ]] && [[ "$DEST_EXT" == "raw" ]]; then
    # JPEG to RAW conversion
    echo "Converting JPEG to grayscale raw format..."
    
    # Get image dimensions
    DIMENSIONS=$(identify -format "%wx%h" "$SOURCE_FILE" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error: Could not read image information from '$SOURCE_FILE'"
        echo "Make sure the file is a valid image format."
        exit 1
    fi
    
    WIDTH=$(echo $DIMENSIONS | cut -d'x' -f1)
    HEIGHT=$(echo $DIMENSIONS | cut -d'x' -f2)
    
    echo "Image dimensions: ${WIDTH}x${HEIGHT}"
    
    # Convert to grayscale raw
    convert "$SOURCE_FILE" -colorspace Gray -depth 8 -type grayscale "gray:$DEST_FILE"
    
    if [ $? -eq 0 ]; then
        echo "✓ Conversion successful!"
        
        # Verify file size
        EXPECTED_SIZE=$((WIDTH * HEIGHT))
        ACTUAL_SIZE=$(stat -c%s "$DEST_FILE")
        
        echo "Expected size: $EXPECTED_SIZE bytes (${WIDTH}x${HEIGHT})"
        echo "Actual size: $ACTUAL_SIZE bytes"
        
        if [ $EXPECTED_SIZE -eq $ACTUAL_SIZE ]; then
            echo "✓ File size verification passed"
        else
            echo "⚠ Warning: File size doesn't match expected dimensions"
        fi
    else
        echo "✗ Conversion failed!"
        exit 1
    fi

elif [[ "$SOURCE_EXT" == "raw" ]] && [[ "$DEST_EXT" =~ ^(jpg|jpeg)$ ]]; then
    # RAW to JPEG conversion
    echo "Converting raw grayscale to JPEG format..."
    
    # Get file size
    FILE_SIZE=$(stat -c%s "$SOURCE_FILE")
    echo "Raw file size: $FILE_SIZE bytes"
    
    # Try to determine dimensions from file size
    # Common square dimensions
    SQRT_SIZE=$(echo "sqrt($FILE_SIZE)" | bc -l | cut -d'.' -f1)
    
    if [ $((SQRT_SIZE * SQRT_SIZE)) -eq $FILE_SIZE ]; then
        # Perfect square - likely square image
        WIDTH=$SQRT_SIZE
        HEIGHT=$SQRT_SIZE
        echo "Detected square image: ${WIDTH}x${HEIGHT}"
    else
        # Try common aspect ratios
        declare -a COMMON_WIDTHS=(64 128 256 512 640 800 1024 1280 1920)
        FOUND_DIMS=false
        
        for w in "${COMMON_WIDTHS[@]}"; do
            if [ $((FILE_SIZE % w)) -eq 0 ]; then
                h=$((FILE_SIZE / w))
                # Check if this gives reasonable dimensions
                if [ $h -ge 64 ] && [ $h -le 2160 ]; then
                    WIDTH=$w
                    HEIGHT=$h
                    echo "Detected dimensions: ${WIDTH}x${HEIGHT}"
                    FOUND_DIMS=true
                    break
                fi
            fi
        done
        
        if [ "$FOUND_DIMS" = false ]; then
            # Ask user for dimensions
            echo "Could not auto-detect image dimensions."
            echo "Please enter the image dimensions:"
            read -p "Width: " WIDTH
            read -p "Height: " HEIGHT
            
            # Validate dimensions
            EXPECTED_SIZE=$((WIDTH * HEIGHT))
            if [ $EXPECTED_SIZE -ne $FILE_SIZE ]; then
                echo "Error: Dimensions ${WIDTH}x${HEIGHT} don't match file size"
                echo "Expected: $EXPECTED_SIZE bytes, Got: $FILE_SIZE bytes"
                exit 1
            fi
        fi
    fi
    
    echo "Using dimensions: ${WIDTH}x${HEIGHT}"
    
    # Convert raw to JPEG
    convert -size ${WIDTH}x${HEIGHT} -depth 8 gray:"$SOURCE_FILE" "$DEST_FILE"
    
    if [ $? -eq 0 ]; then
        echo "✓ Conversion successful!"
        echo "Output info:"
        identify "$DEST_FILE"
    else
        echo "✗ Conversion failed!"
        exit 1
    fi

else
    echo "Error: Unsupported conversion"
    echo "Supported conversions:"
    echo "  .jpg/.jpeg → .raw (any JPEG to grayscale raw)"
    echo "  .raw → .jpg/.jpeg (raw grayscale to JPEG)"
    echo ""
    echo "Source extension: .$SOURCE_EXT"
    echo "Destination extension: .$DEST_EXT"
    exit 1
fi

echo ""
echo "=== Conversion Complete ==="
ls -la "$SOURCE_FILE" "$DEST_FILE"
