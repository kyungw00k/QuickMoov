import Foundation

/// MP4 FastStart converter (moves moov atom before mdat)
class FastStartConverter {

    enum ConversionError: Error, LocalizedError {
        case atomNotFound(String)
        case readError
        case writeError
        case alreadyOptimized
        case nothingToOptimize

        var errorDescription: String? {
            switch self {
            case .atomNotFound(let type):
                return "Cannot find \(type) atom."
            case .readError:
                return "File read error occurred."
            case .writeError:
                return "File write error occurred."
            case .alreadyOptimized:
                return "File is already optimized."
            case .nothingToOptimize:
                return "Nothing to optimize."
            }
        }
    }

    /// Conversion options
    struct Options {
        var moveMoovToFront: Bool = true
        var removeFreeAtoms: Bool = true

        static let `default` = Options()
        static let fastStartOnly = Options(moveMoovToFront: true, removeFreeAtoms: false)
        static let removeFreeOnly = Options(moveMoovToFront: false, removeFreeAtoms: true)
    }

    /// Perform FastStart conversion (legacy method)
    /// - Parameters:
    ///   - input: Input file URL
    ///   - output: Output file URL
    static func convert(input: URL, output: URL) throws {
        try convert(input: input, output: output, options: .default)
    }

    /// Perform conversion with options
    /// - Parameters:
    ///   - input: Input file URL
    ///   - output: Output file URL
    ///   - options: Conversion options
    static func convert(input: URL, output: URL, options: Options) throws {
        let atoms = try MP4Parser.parseAtoms(url: input)

        // Find required atoms
        guard let ftypAtom = MP4Parser.findAtom("ftyp", in: atoms) else {
            throw ConversionError.atomNotFound("ftyp")
        }
        guard let moovAtom = MP4Parser.findAtom("moov", in: atoms) else {
            throw ConversionError.atomNotFound("moov")
        }
        guard let mdatAtom = MP4Parser.findAtom("mdat", in: atoms) else {
            throw ConversionError.atomNotFound("mdat")
        }

        let isFastStart = moovAtom.offset < mdatAtom.offset
        let hasFreeAtoms = atoms.contains { $0.type == "free" || $0.type == "skip" }

        // Check if there's anything to do
        let needsMoovMove = options.moveMoovToFront && !isFastStart
        let needsFreeRemoval = options.removeFreeAtoms && hasFreeAtoms

        if !needsMoovMove && !needsFreeRemoval {
            throw ConversionError.nothingToOptimize
        }

        guard let inputHandle = try? FileHandle(forReadingFrom: input) else {
            throw ConversionError.readError
        }
        defer { try? inputHandle.close() }

        // Create output file
        FileManager.default.createFile(atPath: output.path, contents: nil)
        guard let outputHandle = try? FileHandle(forWritingTo: output) else {
            throw ConversionError.writeError
        }
        defer { try? outputHandle.close() }

        // Calculate sizes for offset adjustment
        let freeAtomsTotalSize = atoms
            .filter { $0.type == "free" || $0.type == "skip" }
            .filter { $0.offset < mdatAtom.offset } // Only count free atoms before mdat
            .reduce(0) { $0 + $1.size }

        // 1. Write ftyp
        try inputHandle.seek(toOffset: ftypAtom.offset)
        guard let ftypData = try inputHandle.read(upToCount: Int(ftypAtom.size)) else {
            throw ConversionError.readError
        }
        try outputHandle.write(contentsOf: ftypData)

        // 2. Handle moov
        try inputHandle.seek(toOffset: moovAtom.offset)
        guard var moovData = try inputHandle.read(upToCount: Int(moovAtom.size)) else {
            throw ConversionError.readError
        }

        if needsMoovMove {
            // moov moves from after mdat to before mdat
            // New mdat offset = ftyp.size + moov.size (free atoms removed)
            // Old mdat offset = ftyp.size + free.size + mdat_header...
            // Delta = moov.size - free.size (if removing free) or just moov.size
            let offsetDelta: Int64
            if options.removeFreeAtoms {
                offsetDelta = Int64(moovAtom.size) - Int64(freeAtomsTotalSize)
            } else {
                offsetDelta = Int64(moovAtom.size)
            }
            updateChunkOffsets(in: &moovData, delta: offsetDelta)
            try outputHandle.write(contentsOf: moovData)
        } else if isFastStart {
            // moov is already at front, but we might need to adjust offsets if removing free atoms
            if options.removeFreeAtoms && freeAtomsTotalSize > 0 {
                // Offsets decrease by the size of removed free atoms between moov and mdat
                let freeAtomsBetweenMoovAndMdat = atoms
                    .filter { $0.type == "free" || $0.type == "skip" }
                    .filter { $0.offset > moovAtom.offset && $0.offset < mdatAtom.offset }
                    .reduce(0) { $0 + $1.size }

                if freeAtomsBetweenMoovAndMdat > 0 {
                    updateChunkOffsets(in: &moovData, delta: -Int64(freeAtomsBetweenMoovAndMdat))
                }
            }
            try outputHandle.write(contentsOf: moovData)
        }

        // 3. Write remaining atoms (excluding ftyp, moov which are already written)
        for atom in atoms {
            // Skip ftyp (already written) and moov (already written)
            if atom.type == "ftyp" || atom.type == "moov" {
                continue
            }

            // Skip free/skip atoms if removing
            if options.removeFreeAtoms && (atom.type == "free" || atom.type == "skip") {
                continue
            }

            // Write this atom
            try inputHandle.seek(toOffset: atom.offset)

            // Write in chunks for large atoms (like mdat)
            var remaining = Int(atom.size)
            let chunkSize = 1024 * 1024 // 1MB
            while remaining > 0 {
                let toRead = min(remaining, chunkSize)
                guard let chunk = try inputHandle.read(upToCount: toRead), !chunk.isEmpty else {
                    break
                }
                try outputHandle.write(contentsOf: chunk)
                remaining -= chunk.count
            }
        }
    }

    /// Update chunk offset values of stco/co64 atoms inside moov
    private static func updateChunkOffsets(in data: inout Data, delta: Int64) {
        var index = 8 // Skip moov header

        while index < data.count - 8 {
            // Read atom size and type
            let size = readUInt32(from: data, at: index)
            let typeBytes = data[index + 4 ..< index + 8]
            let type = String(bytes: typeBytes, encoding: .ascii) ?? ""

            if size < 8 || index + Int(size) > data.count {
                break
            }

            if type == "stco" {
                updateStco(in: &data, atomOffset: index, delta: delta)
            } else if type == "co64" {
                updateCo64(in: &data, atomOffset: index, delta: delta)
            } else if isContainerAtom(type) {
                // Recursively traverse inside container atoms
                // Start from after header (8 bytes)
                var innerIndex = index + 8
                let atomEnd = index + Int(size)

                while innerIndex < atomEnd - 8 {
                    let innerSize = readUInt32(from: data, at: innerIndex)
                    let innerTypeBytes = data[innerIndex + 4 ..< innerIndex + 8]
                    let innerType = String(bytes: innerTypeBytes, encoding: .ascii) ?? ""

                    if innerSize < 8 || innerIndex + Int(innerSize) > atomEnd {
                        break
                    }

                    if innerType == "stco" {
                        updateStco(in: &data, atomOffset: innerIndex, delta: delta)
                    } else if innerType == "co64" {
                        updateCo64(in: &data, atomOffset: innerIndex, delta: delta)
                    } else if isContainerAtom(innerType) {
                        // Handle deeper containers with recursive call
                        updateChunkOffsetsRecursive(in: &data, start: innerIndex + 8, end: innerIndex + Int(innerSize), delta: delta)
                    }

                    innerIndex += Int(innerSize)
                }
            }

            index += Int(size)
        }
    }

    /// Recursively traverse inside containers
    private static func updateChunkOffsetsRecursive(in data: inout Data, start: Int, end: Int, delta: Int64) {
        var index = start

        while index < end - 8 {
            let size = readUInt32(from: data, at: index)
            let typeBytes = data[index + 4 ..< index + 8]
            let type = String(bytes: typeBytes, encoding: .ascii) ?? ""

            if size < 8 || index + Int(size) > end {
                break
            }

            if type == "stco" {
                updateStco(in: &data, atomOffset: index, delta: delta)
            } else if type == "co64" {
                updateCo64(in: &data, atomOffset: index, delta: delta)
            } else if isContainerAtom(type) {
                updateChunkOffsetsRecursive(in: &data, start: index + 8, end: index + Int(size), delta: delta)
            }

            index += Int(size)
        }
    }

    /// Update 32-bit offsets in stco atom
    private static func updateStco(in data: inout Data, atomOffset: Int, delta: Int64) {
        // stco structure: size(4) + type(4) + version(1) + flags(3) + entry_count(4) + entries(4 each)
        let entryCountOffset = atomOffset + 12
        guard entryCountOffset + 4 <= data.count else { return }

        let entryCount = readUInt32(from: data, at: entryCountOffset)
        var entryOffset = entryCountOffset + 4

        for _ in 0..<entryCount {
            guard entryOffset + 4 <= data.count else { break }

            let currentOffset = readUInt32(from: data, at: entryOffset)
            let newOffset = UInt32(clamping: Int64(currentOffset) + delta)
            writeUInt32(to: &data, at: entryOffset, value: newOffset)

            entryOffset += 4
        }
    }

    /// Update 64-bit offsets in co64 atom
    private static func updateCo64(in data: inout Data, atomOffset: Int, delta: Int64) {
        // co64 structure: size(4) + type(4) + version(1) + flags(3) + entry_count(4) + entries(8 each)
        let entryCountOffset = atomOffset + 12
        guard entryCountOffset + 4 <= data.count else { return }

        let entryCount = readUInt32(from: data, at: entryCountOffset)
        var entryOffset = entryCountOffset + 4

        for _ in 0..<entryCount {
            guard entryOffset + 8 <= data.count else { break }

            let currentOffset = readUInt64(from: data, at: entryOffset)
            let newOffset = UInt64(clamping: Int64(currentOffset) + delta)
            writeUInt64(to: &data, at: entryOffset, value: newOffset)

            entryOffset += 8
        }
    }

    /// Check if atom is a container
    private static func isContainerAtom(_ type: String) -> Bool {
        let containers = ["moov", "trak", "mdia", "minf", "stbl", "udta", "edts", "meta"]
        return containers.contains(type)
    }

    // MARK: - Helper Functions

    private static func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        return UInt32(data[offset]) << 24 |
               UInt32(data[offset + 1]) << 16 |
               UInt32(data[offset + 2]) << 8 |
               UInt32(data[offset + 3])
    }

    private static func readUInt64(from data: Data, at offset: Int) -> UInt64 {
        return UInt64(data[offset]) << 56 |
               UInt64(data[offset + 1]) << 48 |
               UInt64(data[offset + 2]) << 40 |
               UInt64(data[offset + 3]) << 32 |
               UInt64(data[offset + 4]) << 24 |
               UInt64(data[offset + 5]) << 16 |
               UInt64(data[offset + 6]) << 8 |
               UInt64(data[offset + 7])
    }

    private static func writeUInt32(to data: inout Data, at offset: Int, value: UInt32) {
        data[offset] = UInt8((value >> 24) & 0xFF)
        data[offset + 1] = UInt8((value >> 16) & 0xFF)
        data[offset + 2] = UInt8((value >> 8) & 0xFF)
        data[offset + 3] = UInt8(value & 0xFF)
    }

    private static func writeUInt64(to data: inout Data, at offset: Int, value: UInt64) {
        data[offset] = UInt8((value >> 56) & 0xFF)
        data[offset + 1] = UInt8((value >> 48) & 0xFF)
        data[offset + 2] = UInt8((value >> 40) & 0xFF)
        data[offset + 3] = UInt8((value >> 32) & 0xFF)
        data[offset + 4] = UInt8((value >> 24) & 0xFF)
        data[offset + 5] = UInt8((value >> 16) & 0xFF)
        data[offset + 6] = UInt8((value >> 8) & 0xFF)
        data[offset + 7] = UInt8(value & 0xFF)
    }
}
