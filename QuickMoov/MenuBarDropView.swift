import SwiftUI
import UniformTypeIdentifiers

struct MenuBarDropView: View {
    @State private var isTargeted = false
    @State private var statusMessage: String = ""
    @State private var isProcessing = false

    private let supportedExtensions = ["mp4", "mov", "m4v", "m4a", "3gp"]

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTargeted ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))

                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(isTargeted ? .accentColor : .gray.opacity(0.5))

                VStack(spacing: 8) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 24))
                            .foregroundColor(isTargeted ? .accentColor : .gray)
                    }

                    Text(statusMessage.isEmpty ? String(localized: "menubar_drop_hint") : statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding()
            }
            .frame(width: 200, height: 100)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }

            Divider()

            Button(String(localized: "menubar_quit")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 220)
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                DispatchQueue.main.async {
                    statusMessage = String(localized: "error_read_file")
                    clearStatusAfterDelay()
                }
                return
            }

            let ext = url.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else {
                DispatchQueue.main.async {
                    statusMessage = String(localized: "menubar_unsupported")
                    clearStatusAfterDelay()
                }
                return
            }

            processFile(url: url)
        }
    }

    private func processFile(url: URL) {
        DispatchQueue.main.async {
            isProcessing = true
            statusMessage = url.lastPathComponent
        }

        Task {
            do {
                let needsConversion = try MP4Parser.needsFastStart(url: url)

                if !needsConversion {
                    await MainActor.run {
                        isProcessing = false
                        statusMessage = String(localized: "menubar_already_optimized")
                        clearStatusAfterDelay()
                    }
                    return
                }

                let outputURL = generateOutputURL(for: url)
                try FastStartConverter.convert(input: url, output: outputURL)

                await MainActor.run {
                    isProcessing = false
                    statusMessage = String(localized: "menubar_success")
                    clearStatusAfterDelay()
                }

            } catch {
                await MainActor.run {
                    isProcessing = false
                    statusMessage = error.localizedDescription
                    clearStatusAfterDelay()
                }
            }
        }
    }

    private func generateOutputURL(for inputURL: URL) -> URL {
        let directory = inputURL.deletingLastPathComponent()
        let filename = inputURL.deletingPathExtension().lastPathComponent
        let ext = inputURL.pathExtension
        return directory.appendingPathComponent("\(filename)_modified.\(ext)")
    }

    private func clearStatusAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            statusMessage = ""
        }
    }
}

#Preview {
    MenuBarDropView()
}
