#!/bin/zsh

# QuickMoov Localized Screenshot Automation
# Captures screenshots for all supported languages

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_EXECUTABLE="$BUILD_DIR/Build/Products/Release/QuickMoov.app/Contents/MacOS/QuickMoov"
SCREENSHOTS_DIR="$PROJECT_DIR/fastlane/screenshots"

# App Store screenshot size
WIDTH=2880
HEIGHT=1800

echo "=== QuickMoov Localized Screenshot Generator ==="
echo ""

# Build the app
echo "Building QuickMoov..."
xcodebuild -project "$PROJECT_DIR/QuickMoov.xcodeproj" \
    -scheme QuickMoov \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build 2>&1 | grep -E "(BUILD|ARCHIVE|SUCCEEDED|FAILED)" | tail -3

echo ""

# Function to get window ID using Swift
get_window_id() {
    swift -e '
import Cocoa
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
    for window in windowList {
        if let ownerName = window[kCGWindowOwnerName as String] as? String,
           ownerName == "QuickMoov",
           let windowNumber = window[kCGWindowNumber as String] as? Int {
            print(windowNumber)
            break
        }
    }
}
' 2>/dev/null
}

# Function to capture screenshot
capture_screenshot() {
    local lang_code=$1
    local apple_lang=$2
    local scenario=$3
    local filename=$4
    local output_dir="$SCREENSHOTS_DIR/$lang_code"

    mkdir -p "$output_dir"

    # Kill any existing instance
    pkill -x QuickMoov 2>/dev/null || true
    sleep 1

    # Launch app with language and demo mode
    if [ "$scenario" = "idle" ]; then
        "$APP_EXECUTABLE" -AppleLanguages "($apple_lang)" &
    else
        QUICKMOOV_DEMO="$scenario" "$APP_EXECUTABLE" -AppleLanguages "($apple_lang)" &
    fi
    APP_PID=$!

    # Wait for app to fully launch
    sleep 3

    local temp_file="/tmp/quickmoov_temp_${lang_code}_${filename}.png"
    local final_file="$output_dir/${filename}.png"

    # Get window ID using Swift
    WINDOW_ID=$(get_window_id)

    if [ -n "$WINDOW_ID" ] && [ "$WINDOW_ID" != "" ]; then
        # Capture specific window by ID
        screencapture -l"$WINDOW_ID" -o "$temp_file"

        if [ -f "$temp_file" ]; then
            # Add white background and resize to App Store dimensions
            magick "$temp_file" \
                \( +clone -background black -shadow 50x15+0+8 \) \
                +swap -background none -layers merge +repage \
                -background white -gravity center -extent ${WIDTH}x${HEIGHT} \
                "$final_file"

            rm "$temp_file"
            echo "  ✓ $(basename $final_file)"
        else
            echo "  ✗ Failed to capture temp file"
        fi
    else
        echo "  ✗ Failed to get window ID"
    fi

    # Close app
    kill $APP_PID 2>/dev/null || true
    sleep 0.5
}

# Languages: folder_name apple_language_code
LANG_CODES=("en-US" "ko" "ja" "zh-Hans")
APPLE_LANGS=("en" "ko" "ja" "zh-Hans")

# Scenarios
SCENARIOS=("idle" "needs-conversion" "already-optimized" "optimization-complete")
SCENARIO_NAMES=("01_idle" "02_needs_conversion" "03_already_optimized" "04_optimization_complete")

# Capture screenshots for each language
for ((l=1; l<=${#LANG_CODES[@]}; l++)); do
    lang_code="${LANG_CODES[$l]}"
    apple_lang="${APPLE_LANGS[$l]}"

    echo ""
    echo "=== Language: $lang_code ==="

    for ((s=1; s<=${#SCENARIOS[@]}; s++)); do
        scenario="${SCENARIOS[$s]}"
        filename="${SCENARIO_NAMES[$s]}"
        echo "Capturing: $filename..."
        capture_screenshot "$lang_code" "$apple_lang" "$scenario" "$filename"
    done
done

# Cleanup
pkill -x QuickMoov 2>/dev/null || true

echo ""
echo "=== Complete ==="
echo ""

# Summary
total=0
for lang_code in $LANG_CODES; do
    if [ -d "$SCREENSHOTS_DIR/$lang_code" ]; then
        count=$(ls -1 "$SCREENSHOTS_DIR/$lang_code"/*.png 2>/dev/null | wc -l | tr -d ' ')
        echo "$lang_code: $count screenshots"
        total=$((total + count))
    else
        echo "$lang_code: 0 screenshots"
    fi
done

echo ""
echo "Total: $total screenshots"
echo "Saved to: $SCREENSHOTS_DIR"
