#!/usr/bin/env swift

import Foundation

// Simple atom parser
func analyzeFile(_ path: String) -> (isFastStart: Bool, hasFree: Bool, freeSize: UInt64, fileSize: UInt64) {
    guard let handle = FileHandle(forReadingAtPath: path) else {
        return (false, false, 0, 0)
    }
    defer { try? handle.close() }

    let fileSize = try! handle.seekToEnd()
    try! handle.seek(toOffset: 0)

    var moovOffset: UInt64?
    var mdatOffset: UInt64?
    var freeSize: UInt64 = 0
    var offset: UInt64 = 0

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

        if type == "moov" { moovOffset = offset }
        if type == "mdat" { mdatOffset = offset }
        if type == "free" || type == "skip" { freeSize += size }

        offset += size
    }

    let isFastStart = (moovOffset ?? UInt64.max) < (mdatOffset ?? 0)
    return (isFastStart, freeSize > 0, freeSize, fileSize)
}

print("=== Free Atom Removal Test ===\n")

// Test optimized file (has free atoms)
let optimizedFile = "test_optimized.mp4"
let result = analyzeFile(optimizedFile)

print("[\(optimizedFile)]")
print("  Fast-start: \(result.isFastStart)")
print("  Has free atoms: \(result.hasFree)")
print("  Free atom size: \(result.freeSize) bytes")
print("  Total file size: \(result.fileSize) bytes")

if result.hasFree {
    print("\n  → This file has free atoms that can be removed!")
    print("  → Potential size reduction: \(result.freeSize) bytes (\(String(format: "%.1f", Double(result.freeSize) / Double(result.fileSize) * 100))%)")
}

print("\n--- All test files ---\n")

let files = ["test_not_optimized.mp4", "test_optimized.mp4", "test.mov", "test.m4v", "test.m4a", "test.3gp"]
for file in files {
    let r = analyzeFile(file)
    let freePercent = r.fileSize > 0 ? String(format: "%.1f%%", Double(r.freeSize) / Double(r.fileSize) * 100) : "0%"
    print("\(file): fast-start=\(r.isFastStart), free=\(r.freeSize) bytes (\(freePercent))")
}
