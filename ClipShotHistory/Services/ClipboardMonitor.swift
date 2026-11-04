import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    private let store: HistoryStore
    private var timer: Timer?
    private var lastChangeCount: Int = -1

    init(store: HistoryStore = .shared) {
        self.store = store
    }

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if store.consumeIgnoreNextClipboardChange() {
            return
        }

        let fileURLs = readFileURLs(from: pb)
        if let shot = fileURLs.first(where: { ScreenshotWatcher.isScreenshotCandidate($0) }) {
            store.addScreenshot(at: shot)
            return
        }

        if let image = readImage(from: pb), isScreenshotImagePayload(pb, fileURLs: fileURLs) {
            store.addScreenshot(from: image)
            return
        }

        if let image = readImage(from: pb) {
            store.addClipboardImage(image)
            return
        }

        if let first = fileURLs.first {
            store.addClipboardFile(path: first.path)
            return
        }

        if let text = pb.string(forType: .string), !text.isEmpty {
            store.addClipboardText(text)
        }
    }

    /// System clipboard screenshots (⌃⌘⇧3/4) are typically image-only: png/tiff, no HTML/RTF/URL.
    /// Copied images from browsers usually also carry HTML / URL flavors.
    private func isScreenshotImagePayload(_ pb: NSPasteboard, fileURLs: [URL]) -> Bool {
        if fileURLs.contains(where: { ScreenshotWatcher.isScreenshotCandidate($0) }) {
            return true
        }
        // Non-screenshot file copy should stay on clipboard as file, not become a screenshot.
        if !fileURLs.isEmpty {
            return false
        }

        if let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return false
        }

        let typeStrings = Set((pb.types ?? []).map(\.rawValue))
        let hasRichContext = typeStrings.contains(where: {
            $0 == "public.html"
                || $0 == "public.rtf"
                || $0 == "com.apple.webarchive"
                || $0 == "public.url"
                || $0.contains("html")
        })
        if hasRichContext {
            return false
        }

        return typeStrings.contains(where: {
            $0.contains("png")
                || $0.contains("tiff")
                || $0.contains("jpeg")
                || $0.contains("image")
        })
    }

    private func readFileURLs(from pb: NSPasteboard) -> [URL] {
        (pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL])?.filter(\.isFileURL) ?? []
    }

    private func readImage(from pb: NSPasteboard) -> NSImage? {
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            return image
        }
        if let data = pb.data(forType: .png) ?? pb.data(forType: .tiff),
           let image = NSImage(data: data) {
            return image
        }
        return nil
    }
}
