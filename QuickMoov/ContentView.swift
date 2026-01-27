import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @State private var processingState: ProcessingState = .idle
    @State private var resultMessage: String = ""
    @State private var isTargeted = false
    @State private var fileInfo: MP4Info?
    @State private var currentFileURL: URL?
    @State private var needsConversion: Bool = false
    @State private var fileName: String = ""
    @State private var filePath: String = ""
    @State private var analysis: MP4Analysis?

    // Supported file extensions
    private let supportedExtensions = ["mp4", "mov", "m4v", "m4a", "3gp"]

    enum ProcessingState {
        case idle
        case analyzing
        case needsConversion
        case converting
        case success
        case alreadyOptimized
        case error
    }

    var body: some View {
        VStack(spacing: 20) {
            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(dropZoneColor)

                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundColor(isTargeted ? .accentColor : .gray)

                VStack(spacing: 16) {
                    Image(systemName: iconName)
                        .font(.system(size: 64))
                        .foregroundColor(iconColor)

                    Text(statusText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    // Display file name and path
                    if !fileName.isEmpty {
                        VStack(spacing: 6) {
                            Text(fileName)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text(filePath)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        .padding(.horizontal)
                    }

                    if !resultMessage.isEmpty {
                        Text(resultMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if processingState == .idle {
                        Text(String(localized: "drop_hint"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Display file info
                    if let info = fileInfo {
                        fileInfoView(info: info)
                    }

                    // Display optimization analysis results
                    if let analysis = analysis, processingState != .idle && processingState != .analyzing {
                        optimizationStatusView(analysis: analysis)
                    }
                }
            }
            .frame(width: 480, height: 500)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }

            // Button area
            HStack(spacing: 12) {
                // Convert button (shown only when conversion is needed)
                if processingState == .needsConversion {
                    Button(action: convertFile) {
                        Label(String(localized: "button_convert"), systemImage: "arrow.up.doc")
                    }
                    .buttonStyle(.borderedProminent)
                }

                // Reset button
                if processingState != .idle && processingState != .analyzing && processingState != .converting {
                    Button(String(localized: "process_another")) {
                        resetState()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(30)
        .frame(width: 540, height: 620)
    }

    // MARK: - File Info View

    @ViewBuilder
    private func fileInfoView(info: MP4Info) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .padding(.vertical, 8)

            HStack {
                Label(info.formattedFileSize, systemImage: "doc")
                Spacer()
                Label(info.formattedDuration, systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if let resolution = info.formattedResolution {
                HStack {
                    Label(resolution, systemImage: "rectangle.arrowtriangle.2.outward")
                    Spacer()
                    if let fps = info.frameRate {
                        Label(String(format: "%.1f fps", fps), systemImage: "film")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if let videoCodec = info.videoCodec {
                HStack {
                    Label(videoCodec, systemImage: "video")
                    Spacer()
                    if let audioCodec = info.audioCodec {
                        Label(audioCodec, systemImage: "speaker.wave.2")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - Optimization Status View

    @ViewBuilder
    private func optimizationStatusView(analysis: MP4Analysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 4)

            Text(String(localized: "optimization_status"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                // Fast-start (moov position)
                HStack(spacing: 6) {
                    Image(systemName: analysis.isFastStart ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(analysis.isFastStart ? .green : .orange)
                    Text("Fast-start (moov)")
                    Spacer()
                    Text(analysis.isFastStart ? String(localized: "optimized") : String(localized: "needs_fix"))
                        .foregroundColor(analysis.isFastStart ? .green : .orange)
                }

                // Free atom (unnecessary space)
                HStack(spacing: 6) {
                    Image(systemName: analysis.hasFreeAtom ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(analysis.hasFreeAtom ? .yellow : .green)
                    Text(String(localized: "free_atom"))
                    Spacer()
                    if analysis.hasFreeAtom {
                        Text(formatBytes(analysis.freeAtomSize))
                            .foregroundColor(.yellow)
                    } else {
                        Text(String(localized: "none"))
                            .foregroundColor(.green)
                    }
                }

                // Atom structure
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.secondary)
                    Text("Atoms")
                    Spacer()
                    Text(analysis.atoms.joined(separator: " → "))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .font(.caption)
        }
        .padding(.horizontal, 20)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Computed Properties

    private var dropZoneColor: Color {
        switch processingState {
        case .idle:
            return isTargeted ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05)
        case .analyzing, .converting:
            return Color.orange.opacity(0.1)
        case .needsConversion:
            return Color.yellow.opacity(0.1)
        case .success:
            return Color.green.opacity(0.1)
        case .alreadyOptimized:
            return Color.blue.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        }
    }

    private var iconName: String {
        switch processingState {
        case .idle:
            return "arrow.down.doc"
        case .analyzing:
            return "magnifyingglass"
        case .needsConversion:
            return "exclamationmark.arrow.triangle.2.circlepath"
        case .converting:
            return "gearshape.2"
        case .success:
            return "checkmark.circle"
        case .alreadyOptimized:
            return "checkmark.seal"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch processingState {
        case .idle:
            return .gray
        case .analyzing, .converting:
            return .orange
        case .needsConversion:
            return .yellow
        case .success:
            return .green
        case .alreadyOptimized:
            return .blue
        case .error:
            return .red
        }
    }

    private var statusText: LocalizedStringKey {
        switch processingState {
        case .idle:
            return "status_idle"
        case .analyzing:
            return "status_analyzing"
        case .needsConversion:
            return "status_needs_conversion"
        case .converting:
            return "status_processing"
        case .success:
            return "status_success"
        case .alreadyOptimized:
            return "status_optimized"
        case .error:
            return "status_error"
        }
    }

    // MARK: - Methods

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        // Reset state when new file is dragged
        resetState()

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                DispatchQueue.main.async {
                    self.processingState = .error
                    self.resultMessage = String(localized: "error_read_file")
                }
                return
            }

            let ext = url.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else {
                DispatchQueue.main.async {
                    self.processingState = .error
                    self.resultMessage = String(localized: "error_unsupported_format")
                }
                return
            }

            analyzeFile(url: url)
        }
    }

    private func analyzeFile(url: URL) {
        DispatchQueue.main.async {
            self.processingState = .analyzing
            self.fileName = url.lastPathComponent
            self.filePath = url.deletingLastPathComponent().path
            self.resultMessage = ""
            self.fileInfo = nil
            self.analysis = nil
            self.currentFileURL = url
        }

        Task {
            // Extract file info
            do {
                let info = try await MP4Info.extract(from: url)
                await MainActor.run {
                    self.fileInfo = info
                }
            } catch {
                // Continue analysis even if file info extraction fails
            }

            // Full analysis
            do {
                let analysisResult = try MP4Parser.analyze(url: url)

                await MainActor.run {
                    self.analysis = analysisResult

                    if !analysisResult.isFastStart {
                        self.processingState = .needsConversion
                        self.resultMessage = String(localized: "result_needs_conversion")
                        self.needsConversion = true
                    } else if analysisResult.hasFreeAtom {
                        // Fast-start is OK, but has free atoms that can be removed
                        self.processingState = .needsConversion
                        self.resultMessage = String(localized: "result_has_free_atoms")
                        self.needsConversion = true
                    } else {
                        self.processingState = .alreadyOptimized
                        self.resultMessage = String(localized: "result_already_optimized")
                        self.needsConversion = false
                    }
                }

            } catch {
                await MainActor.run {
                    self.processingState = .error
                    self.resultMessage = error.localizedDescription
                }
            }
        }
    }

    private func convertFile() {
        guard let inputURL = currentFileURL else { return }

        // Select save location with NSSavePanel
        let savePanel = NSSavePanel()
        savePanel.title = String(localized: "save_panel_title")
        savePanel.nameFieldStringValue = generateOutputFilename(for: inputURL)
        savePanel.allowedContentTypes = [UTType(filenameExtension: inputURL.pathExtension) ?? .mpeg4Movie]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let outputURL = savePanel.url else { return }

            self.processingState = .converting

            Task {
                do {
                    try FastStartConverter.convert(input: inputURL, output: outputURL)

                    await MainActor.run {
                        self.processingState = .success
                        self.resultMessage = String(localized: "result_saved \(outputURL.lastPathComponent)")
                    }
                } catch {
                    await MainActor.run {
                        self.processingState = .error
                        self.resultMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func generateOutputFilename(for inputURL: URL) -> String {
        let filename = inputURL.deletingPathExtension().lastPathComponent
        let ext = inputURL.pathExtension
        return "\(filename)_modified.\(ext)"
    }

    private func resetState() {
        processingState = .idle
        resultMessage = ""
        fileName = ""
        filePath = ""
        fileInfo = nil
        analysis = nil
        currentFileURL = nil
        needsConversion = false
    }
}

#Preview {
    ContentView()
}
