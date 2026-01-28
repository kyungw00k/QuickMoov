#!/bin/bash

# Create App Store screenshots with gradient background
# Output: 2880 × 1800px (Retina)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INPUT_DIR="$PROJECT_DIR/screenshots"
OUTPUT_DIR="$PROJECT_DIR/screenshots/appstore"

# App Store screenshot size (Retina)
WIDTH=2880
HEIGHT=1800

# Gradient colors (purple to blue)
COLOR_START="#667eea"
COLOR_END="#764ba2"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "=== Creating App Store Screenshots ==="
echo "Output size: ${WIDTH}x${HEIGHT}px"
echo ""

# Process each screenshot
for img in "$INPUT_DIR"/*.png; do
    if [ ! -f "$img" ]; then
        continue
    fi

    filename=$(basename "$img")

    # Skip if already in appstore folder
    if [[ "$img" == *"/appstore/"* ]]; then
        continue
    fi

    echo "Processing: $filename"

    # Create gradient background
    convert -size ${WIDTH}x${HEIGHT} \
        gradient:"$COLOR_START"-"$COLOR_END" \
        -rotate 135 \
        -resize ${WIDTH}x${HEIGHT}! \
        "$OUTPUT_DIR/bg_temp.png"

    # Add shadow to the app window and composite
    convert "$img" \
        \( +clone -background black -shadow 60x20+0+10 \) \
        +swap -background none -layers merge +repage \
        "$OUTPUT_DIR/window_temp.png"

    # Get window dimensions
    win_width=$(sips -g pixelWidth "$OUTPUT_DIR/window_temp.png" | grep pixelWidth | awk '{print $2}')
    win_height=$(sips -g pixelHeight "$OUTPUT_DIR/window_temp.png" | grep pixelHeight | awk '{print $2}')

    # Calculate center position
    x_offset=$(( (WIDTH - win_width) / 2 ))
    y_offset=$(( (HEIGHT - win_height) / 2 ))

    # Composite window on background
    convert "$OUTPUT_DIR/bg_temp.png" \
        "$OUTPUT_DIR/window_temp.png" \
        -geometry +${x_offset}+${y_offset} \
        -composite \
        "$OUTPUT_DIR/$filename"

    echo "  Created: $OUTPUT_DIR/$filename"
done

# Cleanup temp files
rm -f "$OUTPUT_DIR/bg_temp.png" "$OUTPUT_DIR/window_temp.png"

echo ""
echo "=== Complete ==="
echo "Screenshots saved to: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"/*.png 2>/dev/null || echo "No screenshots generated"

# Verify sizes
echo ""
echo "Verifying sizes:"
for img in "$OUTPUT_DIR"/*.png; do
    if [ -f "$img" ]; then
        size=$(sips -g pixelWidth -g pixelHeight "$img" | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo "  $(basename "$img"): ${size}"
    fi
done
