import Foundation
import AVFoundation

/// MP4 file metadata info
struct MP4Info {
    let fileSize: Int64
    let duration: TimeInterval
    let resolution: CGSize?
    let videoCodec: String?
    let audioCodec: String?
    let videoBitrate: Int?
    let audioBitrate: Int?
    let frameRate: Double?

    /// Formatted file size
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// Formatted duration
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Formatted resolution
    var formattedResolution: String? {
        guard let size = resolution else { return nil }
        return "\(Int(size.width)) x \(Int(size.height))"
    }

    /// Extract MP4 info using AVFoundation
    static func extract(from url: URL) async throws -> MP4Info {
        let asset = AVURLAsset(url: url)

        // File size
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0

        // Duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        // Video track info
        var resolution: CGSize?
        var videoCodec: String?
        var frameRate: Double?

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        if let videoTrack = videoTracks.first {
            let size = try await videoTrack.load(.naturalSize)
            let transform = try await videoTrack.load(.preferredTransform)

            // Actual size with rotation applied
            let transformedSize = size.applying(transform)
            resolution = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

            // Frame rate
            frameRate = try await Double(videoTrack.load(.nominalFrameRate))

            // Video codec
            let formatDescriptions = try await videoTrack.load(.formatDescriptions)
            if let formatDesc = formatDescriptions.first {
                let codecType = CMFormatDescriptionGetMediaSubType(formatDesc)
                videoCodec = fourCCToString(codecType)
            }
        }

        // Audio track info
        var audioCodec: String?
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        if let audioTrack = audioTracks.first {
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            if let formatDesc = formatDescriptions.first {
                let codecType = CMFormatDescriptionGetMediaSubType(formatDesc)
                audioCodec = fourCCToString(codecType)
            }
        }

        return MP4Info(
            fileSize: fileSize,
            duration: durationSeconds,
            resolution: resolution,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            videoBitrate: nil,
            audioBitrate: nil,
            frameRate: frameRate
        )
    }

    /// Convert FourCC code to string
    private static func fourCCToString(_ code: FourCharCode) -> String {
        let chars: [Character] = [
            Character(UnicodeScalar((code >> 24) & 0xFF)!),
            Character(UnicodeScalar((code >> 16) & 0xFF)!),
            Character(UnicodeScalar((code >> 8) & 0xFF)!),
            Character(UnicodeScalar(code & 0xFF)!)
        ]
        let raw = String(chars)

        // Convert to common codec names
        switch raw {
        case "avc1", "avc2", "avc3", "avc4":
            return "H.264"
        case "hvc1", "hev1":
            return "H.265 (HEVC)"
        case "mp4v":
            return "MPEG-4"
        case "ap4h", "ap4x":
            return "ProRes 4444"
        case "apch":
            return "ProRes 422 HQ"
        case "apcn":
            return "ProRes 422"
        case "apcs":
            return "ProRes 422 LT"
        case "apco":
            return "ProRes 422 Proxy"
        case "av01":
            return "AV1"
        case "vp09":
            return "VP9"
        case "mp4a":
            return "AAC"
        case "ac-3":
            return "AC-3"
        case "ec-3":
            return "E-AC-3"
        case "alac":
            return "Apple Lossless"
        case "fLaC":
            return "FLAC"
        default:
            return raw.trimmingCharacters(in: .whitespaces)
        }
    }
}
