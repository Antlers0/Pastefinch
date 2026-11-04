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

        // Finder copy of a system screenshot file → Screenshots tab.
        if let shot = fileURLs.first(where: { ScreenshotWatcher.isScreenshotCandidate($0) }) {
            store.addScreenshot(at: shot)
            return
        }

        // Prefer file records when Finder (or others) put file URLs on the pasteboard.
        // Image/PDF copies often also include a preview image — don't swallow them as images.
        if !fileURLs.isEmpty {
            for url in fileURLs {
                store.addClipboardFile(path: url.path)
            }
            return
        }

        if let image = readImage(from: pb), isScreenshotImagePayload(pb) {
            store.addScreenshot(from: image)
            return
        }

        if let image = readImage(from: pb) {
            store.addClipboardImage(image)
            return
        }

        if let text = pb.string(forType: .string), !text.isEmpty {
            store.addClipboardText(text)
        }
    }

    /// System clipboard screenshots (⌃⌘⇧3/4) are typically image-only: png/tiff, no HTML/RTF/URL.
    /// Copied images from browsers usually also carry HTML / URL flavors.
    private func isScreenshotImagePayload(_ pb: NSPasteboard) -> Bool {
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
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] {
            let files = urls.filter(\.isFileURL)
            if !files.isEmpty { return uniqueFiles(files) }
        }

        // Finder legacy type: NSFilenamesPboardType
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let paths = pb.propertyList(forType: filenamesType) as? [String], !paths.isEmpty {
            return uniqueFiles(paths.map { URL(fileURLWithPath: $0) })
        }

        if let data = pb.data(forType: .fileURL),
           let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: raw), url.isFileURL {
            return [url]
        }

        if let raw = pb.string(forType: .fileURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: raw), url.isFileURL {
            return [url]
        }

        return []
    }

    private func uniqueFiles(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls {
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { continue }
            result.append(url.standardizedFileURL)
        }
        return result
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
