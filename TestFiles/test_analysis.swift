#!/usr/bin/env swift

import Foundation

// Simple atom parser for testing
func analyzeFile(_ path: String) {
    guard let handle = FileHandle(forReadingAtPath: path) else {
        print("  Error: Cannot open file")
        return
    }
    defer { try? handle.close() }

    let fileSize = try! handle.seekToEnd()
    try! handle.seek(toOffset: 0)

    var offset: UInt64 = 0
    var atoms: [(String, UInt64, UInt64)] = []
    var moovOffset: UInt64?
    var mdatOffset: UInt64?

    while offset < fileSize {
        try! handle.seek(toOffset: offset)
        guard let header = try? handle.read(upToCount: 8), header.count == 8 else { break }

        var size = UInt64(header[0]) << 24 | UInt64(header[1]) << 16 | UInt64(header[2]) << 8 | UInt64(header[3])
        let type = String(bytes: header[4..<8], encoding: .ascii) ?? "????"

        if size == 1 {
            guard let ext = try? handle.read(upToCount: 8), ext.count == 8 else { break }
            size = UInt64(ext[0]) << 56 | UInt64(ext[1]) << 48 | UInt64(ext[2]) << 40 | UInt64(ext[3]) << 32 |
                   UInt64(ext[4]) << 24 | UInt64(ext[5]) << 16 | UInt64(ext[6]) << 8 | UInt64(ext[7])
        }
        if size == 0 { size = fileSize - offset }

        atoms.append((type, offset, size))
        if type == "moov" { moovOffset = offset }
        if type == "mdat" { mdatOffset = offset }

        offset += size
    }

    let atomList = atoms.map { $0.0 }.joined(separator: " → ")
    print("  Atoms: \(atomList)")

    if let moov = moovOffset, let mdat = mdatOffset {
        let isFastStart = moov < mdat
        print("  Fast-start: \(isFastStart ? "YES (optimized)" : "NO (needs fix)")")
        print("  moov@\(moov), mdat@\(mdat)")
    }
}

// Test all files
let testFiles = [
    "test_not_optimized.mp4",
    "test_optimized.mp4",
    "test.mov",
    "test.m4v",
    "test.m4a",
    "test.3gp"
]

print("=== QuickMoov Test File Analysis ===\n")

for file in testFiles {
    print("[\(file)]")
    analyzeFile(file)
    print()
}
