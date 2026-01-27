import Foundation

/// MP4 Atom (Box) structure
struct MP4Atom {
    let type: String
    let offset: UInt64
    let size: UInt64

    var endOffset: UInt64 {
        return offset + size
    }
}

/// MP4 optimization analysis result
struct MP4Analysis {
    /// Whether moov is before mdat (Fast-start)
    var isFastStart: Bool = false
    /// Whether free atom exists (unnecessary space)
    var hasFreeAtom: Bool = false
    /// free atom size
    var freeAtomSize: UInt64 = 0
    /// Total file size
    var fileSize: UInt64 = 0
    /// moov atom size
    var moovSize: UInt64 = 0
    /// mdat atom size
    var mdatSize: UInt64 = 0
    /// Discovered top-level atoms
    var atoms: [String] = []

    /// Streaming optimization status
    var isStreamingOptimized: Bool {
        return isFastStart && !hasFreeAtom
    }

    /// Metadata ratio (moov/total)
    var metadataRatio: Double {
        guard fileSize > 0 else { return 0 }
        return Double(moovSize) / Double(fileSize) * 100
    }
}

/// MP4 file parsing and analysis
class MP4Parser {

    enum ParserError: Error, LocalizedError {
        case fileNotFound
        case invalidMP4Format
        case readError

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "File not found."
            case .invalidMP4Format:
                return "Not a valid MP4 file."
            case .readError:
                return "File read error occurred."
            }
        }
    }

    /// Parse top-level atom list of file
    static func parseAtoms(url: URL) throws -> [MP4Atom] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParserError.fileNotFound
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            throw ParserError.readError
        }
        defer { try? fileHandle.close() }

        let fileSize = try fileHandle.seekToEnd()
        try fileHandle.seek(toOffset: 0)

        var atoms: [MP4Atom] = []
        var currentOffset: UInt64 = 0

        while currentOffset < fileSize {
            try fileHandle.seek(toOffset: currentOffset)

            // Read 8-byte header (4-byte size + 4-byte type)
            guard let headerData = try fileHandle.read(upToCount: 8),
                  headerData.count == 8 else {
                break
            }

            // Parse size (big-endian)
            var size = UInt64(headerData[0]) << 24 |
                       UInt64(headerData[1]) << 16 |
                       UInt64(headerData[2]) << 8 |
                       UInt64(headerData[3])

            // Parse type
            let typeData = headerData[4..<8]
            let type = String(bytes: typeData, encoding: .ascii) ?? "????"

            // Handle extended size (use 64-bit size when size == 1)
            if size == 1 {
                guard let extendedSizeData = try fileHandle.read(upToCount: 8),
                      extendedSizeData.count == 8 else {
                    break
                }
                size = UInt64(extendedSizeData[0]) << 56 |
                       UInt64(extendedSizeData[1]) << 48 |
                       UInt64(extendedSizeData[2]) << 40 |
                       UInt64(extendedSizeData[3]) << 32 |
                       UInt64(extendedSizeData[4]) << 24 |
                       UInt64(extendedSizeData[5]) << 16 |
                       UInt64(extendedSizeData[6]) << 8 |
                       UInt64(extendedSizeData[7])
            }

            // If size is 0, read to end of file
            if size == 0 {
                size = fileSize - currentOffset
            }

            let atom = MP4Atom(type: type, offset: currentOffset, size: size)
            atoms.append(atom)

            currentOffset += size
        }

        return atoms
    }

    /// Check if moov is after mdat (whether faststart is needed)
    static func needsFastStart(url: URL) throws -> Bool {
        let atoms = try parseAtoms(url: url)

        var moovOffset: UInt64?
        var mdatOffset: UInt64?

        for atom in atoms {
            if atom.type == "moov" {
                moovOffset = atom.offset
            } else if atom.type == "mdat" {
                mdatOffset = atom.offset
            }
        }

        guard let moov = moovOffset, let mdat = mdatOffset else {
            throw ParserError.invalidMP4Format
        }

        // Need faststart if moov is after mdat
        return moov > mdat
    }

    /// Find atom of specific type
    static func findAtom(_ type: String, in atoms: [MP4Atom]) -> MP4Atom? {
        return atoms.first { $0.type == type }
    }

    /// Analyze entire file
    static func analyze(url: URL) throws -> MP4Analysis {
        let atoms = try parseAtoms(url: url)

        var analysis = MP4Analysis()

        // File size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? UInt64 {
            analysis.fileSize = size
        }

        // Atom list
        analysis.atoms = atoms.map { $0.type }

        var moovOffset: UInt64?
        var mdatOffset: UInt64?

        for atom in atoms {
            switch atom.type {
            case "moov":
                moovOffset = atom.offset
                analysis.moovSize = atom.size
            case "mdat":
                mdatOffset = atom.offset
                analysis.mdatSize = atom.size
            case "free", "skip":
                analysis.hasFreeAtom = true
                analysis.freeAtomSize += atom.size
            default:
                break
            }
        }

        // Check Fast-start
        if let moov = moovOffset, let mdat = mdatOffset {
            analysis.isFastStart = moov < mdat
        }

        return analysis
    }
}
