#!/bin/bash

# QuickMoov Screenshot Automation Script
# Captures screenshots for App Store submission
#
# Usage: ./capture_screenshots.sh
#
# Note: This script requires accessibility permissions for Terminal/iTerm.
# Go to: System Preferences > Privacy & Security > Accessibility
# And add your terminal app.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/Build/Products/Release/QuickMoov.app"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/QuickMoov"
SCREENSHOTS_DIR="$PROJECT_DIR/Screenshots"

# Create screenshots directory
mkdir -p "$SCREENSHOTS_DIR"

# Build the app if needed
echo "Building QuickMoov..."
xcodebuild -project "$PROJECT_DIR/QuickMoov.xcodeproj" \
    -scheme QuickMoov \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build 2>&1 | tail -5

echo "Build complete."
echo ""

# Function to capture screenshot using AppleScript
capture_screenshot() {
    local scenario=$1
    local filename=$2

    echo "Capturing: $filename ($scenario)..."

    # Kill any existing instance
    pkill -x QuickMoov 2>/dev/null || true
    sleep 0.5

    # Launch app with demo mode
    if [ "$scenario" = "idle" ]; then
        "$APP_EXECUTABLE" &
    else
        QUICKMOOV_DEMO="$scenario" "$APP_EXECUTABLE" &
    fi
    APP_PID=$!

    # Wait for app to launch and render
    sleep 2

    # Activate the app
    osascript -e 'tell application "System Events" to set frontmost of process "QuickMoov" to true' 2>/dev/null || true
    sleep 1

    # Get window ID using CGWindowListCopyWindowInfo
    WINDOW_ID=$(osascript -e '
        tell application "System Events"
            tell process "QuickMoov"
                set windowId to id of window 1
            end tell
        end tell
        return windowId
    ' 2>/dev/null || echo "")

    if [ -n "$WINDOW_ID" ]; then
        screencapture -l"$WINDOW_ID" -o "$SCREENSHOTS_DIR/$filename.png"
    else
        # Fallback: Use python to get window ID
        WINDOW_ID=$(python3 -c "
import Quartz
windows = Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID)
for w in windows:
    if w.get('kCGWindowOwnerName') == 'QuickMoov':
        print(w.get('kCGWindowNumber'))
        break
" 2>/dev/null || echo "")

        if [ -n "$WINDOW_ID" ]; then
            screencapture -l"$WINDOW_ID" -o "$SCREENSHOTS_DIR/$filename.png"
        fi
    fi

    if [ -f "$SCREENSHOTS_DIR/$filename.png" ]; then
        echo "  Saved: $SCREENSHOTS_DIR/$filename.png"
    else
        echo "  Failed to capture (check accessibility permissions)"
    fi

    # Close app
    kill $APP_PID 2>/dev/null || true
    sleep 0.5
}

echo "=== Capturing Screenshots ==="
echo ""
echo "Note: If screenshots fail, ensure Terminal has Accessibility permissions."
echo "Go to: System Settings > Privacy & Security > Accessibility"
echo ""

# Capture all scenarios
capture_screenshot "idle" "01_idle"
capture_screenshot "needs-conversion" "02_needs_conversion"
capture_screenshot "already-optimized" "03_already_optimized"
capture_screenshot "optimization-complete" "04_optimization_complete"

echo ""
echo "=== Screenshots Complete ==="
echo ""

if ls "$SCREENSHOTS_DIR"/*.png 1> /dev/null 2>&1; then
    echo "Screenshots saved to: $SCREENSHOTS_DIR"
    ls -la "$SCREENSHOTS_DIR"/*.png
else
    echo "No screenshots were captured."
    echo ""
    echo "Alternative: Use Xcode Preview Canvas"
    echo "1. Open QuickMoov.xcodeproj in Xcode"
    echo "2. Open ContentView.swift"
    echo "3. Show Canvas (Editor > Canvas)"
    echo "4. Select each Preview variant and use Editor > Canvas > Capture Preview"
fi
