# QuickMoov

A macOS app for optimizing MP4/MOV/M4V/M4A/3GP files for streaming by relocating the moov atom.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## What is Fast-start?

MP4 and QuickTime files contain a "moov" atom that stores metadata (codec info, duration, etc.). When this atom is at the end of the file, the entire file must be downloaded before playback can begin.

**Fast-start** (also known as "web-optimized" or "streaming-optimized") moves the moov atom to the beginning of the file, enabling:
- Instant playback on web browsers
- Faster streaming start time
- Progressive download support

## Features

- Drag and drop interface
- Supports MP4, MOV, M4V, M4A, and 3GP formats
- Shows file analysis before conversion:
  - Fast-start status (moov position)
  - Free atom detection (unnecessary space)
  - Atom structure visualization
- Removes free/skip atoms to reduce file size
- File metadata display (resolution, duration, codecs, frame rate)
- Pure Swift implementation (no external dependencies)
- Multi-language support (English, Korean, Japanese, Chinese)
- Menu bar mode for quick access
- App Sandbox enabled for security

## Requirements

- macOS 13.0 or later

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/kyungw00k/quickmoov.git
   ```

2. Open `MoovIt.xcodeproj` in Xcode

3. Build and run (⌘R)

## Usage

1. Launch QuickMoov
2. Drag and drop a video file onto the window
3. The app will analyze the file and show:
   - Whether fast-start optimization is needed
   - File metadata and atom structure
4. If optimization is needed, click "Convert" to save an optimized copy

## How it Works

The app performs the following operations:

1. **Parse** - Reads the MP4 atom structure to locate ftyp, moov, and mdat atoms
2. **Analyze** - Checks if moov is already before mdat (fast-start ready)
3. **Convert** - If needed:
   - Writes ftyp atom first
   - Relocates moov atom before mdat
   - Updates chunk offsets (stco/co64) to account for the move
   - Removes free/skip atoms to reduce file size
   - Writes mdat and remaining data

## Technical Details

- Uses native Swift `FileHandle` for file I/O
- Handles both 32-bit (stco) and 64-bit (co64) chunk offset tables
- Supports extended atom sizes (64-bit)
- Memory-efficient chunked file writing

## License

MIT License - see [LICENSE](LICENSE) for details

## Author

[@kyungw00k](https://github.com/kyungw00k)
