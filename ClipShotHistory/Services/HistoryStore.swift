import Foundation
import AppKit
import Combine

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    static let clipboardLimit = 200
    static let screenshotLimit = 100

    @Published private(set) var clipboardItems: [ClipboardHistoryItem] = []
    @Published private(set) var screenshotItems: [ScreenshotHistoryItem] = []

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var rootURL: URL
    private var indexURL: URL
    private var imagesURL: URL
    private var thumbnailsURL: URL
    private var capturedURL: URL

    /// Skip recording the next clipboard change (after we write to pasteboard ourselves).
    private(set) var ignoreNextClipboardChange = false

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        rootURL = appSupport.appendingPathComponent("Pastefinch", isDirectory: true)
        let legacyRoot = appSupport.appendingPathComponent("ClipShotHistory", isDirectory: true)
        if !fileManager.fileExists(atPath: rootURL.path),
           fileManager.fileExists(atPath: legacyRoot.path) {
            try? fileManager.moveItem(at: legacyRoot, to: rootURL)
        }
        indexURL = rootURL.appendingPathComponent("index.json")
        imagesURL = rootURL.appendingPathComponent("images", isDirectory: true)
        thumbnailsURL = rootURL.appendingPathComponent("thumbnails", isDirectory: true)
        capturedURL = rootURL.appendingPathComponent("captured", isDirectory: true)
        try? fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: capturedURL, withIntermediateDirectories: true)
        load()
    }

    func markIgnoreNextClipboardChange() {
        ignoreNextClipboardChange = true
    }

    func consumeIgnoreNextClipboardChange() -> Bool {
        if ignoreNextClipboardChange {
            ignoreNextClipboardChange = false
            return true
        }
        return false
    }

    func imageURL(for fileName: String) -> URL {
        imagesURL.appendingPathComponent(fileName)
    }

    func thumbnailURL(for fileName: String) -> URL {
        thumbnailsURL.appendingPathComponent(fileName)
    }

    func loadNSImage(named fileName: String, fromThumbnails: Bool = false) -> NSImage? {
        let url = fromThumbnails ? thumbnailURL(for: fileName) : imageURL(for: fileName)
        return NSImage(contentsOf: url)
    }

    // MARK: - Clipboard

    @discardableResult
    func addClipboardText(_ text: String) -> Bool {
        let trimmed = text
        guard !trimmed.isEmpty else { return false }
        let hash = Self.hash(trimmed)
        if let existingIndex = clipboardItems.firstIndex(where: { $0.contentHash == hash && $0.kind == .text }) {
            var item = clipboardItems.remove(at: existingIndex)
            item.createdAt = Date()
            clipboardItems.insert(item, at: 0)
            persistAndTrim()
            return true
        }
        let item = ClipboardHistoryItem(
            id: UUID(),
            createdAt: Date(),
            kind: .text,
            text: trimmed,
            imageFileName: nil,
            filePath: nil,
            contentHash: hash
        )
        clipboardItems.insert(item, at: 0)
        persistAndTrim()
        return true
    }

    @discardableResult
    func addClipboardImage(_ image: NSImage) -> Bool {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return false
        }
        let hash = Self.hash(png)
        if let existingIndex = clipboardItems.firstIndex(where: { $0.contentHash == hash && $0.kind == .image }) {
            var item = clipboardItems.remove(at: existingIndex)
            item.createdAt = Date()
            clipboardItems.insert(item, at: 0)
            persistAndTrim()
            return true
        }
        let fileName = "\(UUID().uuidString).png"
        let url = imageURL(for: fileName)
        do {
            try png.write(to: url)
        } catch {
            return false
        }
        let item = ClipboardHistoryItem(
            id: UUID(),
            createdAt: Date(),
            kind: .image,
            text: nil,
            imageFileName: fileName,
            filePath: nil,
            contentHash: hash
        )
        clipboardItems.insert(item, at: 0)
        persistAndTrim()
        return true
    }

    @discardableResult
    func addClipboardFile(path: String) -> Bool {
        let hash = Self.hash("file:" + path)
        if let existingIndex = clipboardItems.firstIndex(where: { $0.contentHash == hash && $0.kind == .file }) {
            var item = clipboardItems.remove(at: existingIndex)
            item.createdAt = Date()
            clipboardItems.insert(item, at: 0)
            persistAndTrim()
            return true
        }
        let item = ClipboardHistoryItem(
            id: UUID(),
            createdAt: Date(),
            kind: .file,
            text: nil,
            imageFileName: nil,
            filePath: path,
            contentHash: hash
        )
        clipboardItems.insert(item, at: 0)
        persistAndTrim()
        return true
    }

    func copyClipboardItem(_ item: ClipboardHistoryItem) {
        markIgnoreNextClipboardChange()
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text:
            pb.setString(item.text ?? "", forType: .string)
        case .image:
            if let name = item.imageFileName, let image = loadNSImage(named: name) {
                pb.writeObjects([image])
            }
        case .file:
            if let path = item.filePath {
                let url = URL(fileURLWithPath: path)
                pb.writeObjects([url as NSURL])
            }
        }
    }

    func deleteClipboardItem(_ item: ClipboardHistoryItem) {
        guard let index = clipboardItems.firstIndex(where: { $0.id == item.id }) else { return }
        let removed = clipboardItems.remove(at: index)
        if let name = removed.imageFileName {
            try? fileManager.removeItem(at: imageURL(for: name))
        }
        persist()
    }

    func clearClipboardHistory() {
        for item in clipboardItems where item.kind == .image {
            if let name = item.imageFileName {
                try? fileManager.removeItem(at: imageURL(for: name))
            }
        }
        clipboardItems = []
        persist()
    }

    // MARK: - Screenshots

    @discardableResult
    func addScreenshot(at originalURL: URL) -> Bool {
        guard fileManager.fileExists(atPath: originalURL.path) else { return false }
        guard let data = try? Data(contentsOf: originalURL) else { return false }
        return upsertScreenshot(data: data, originalURL: originalURL)
    }

    /// Save a clipboard-only screenshot (e.g. ⌃⌘⇧4) into app storage and list it under Screenshots.
    @discardableResult
    func addScreenshot(from image: NSImage) -> Bool {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return false
        }
        let fileName = "Clipboard-\(Self.fileTimestamp()).png"
        let dest = capturedURL.appendingPathComponent(fileName)
        do {
            try png.write(to: dest, options: .atomic)
        } catch {
            return false
        }
        return upsertScreenshot(data: png, originalURL: dest)
    }

    private func upsertScreenshot(data: Data, originalURL: URL) -> Bool {
        let hash = Self.hash(data)
        if let existingIndex = screenshotItems.firstIndex(where: { $0.contentHash == hash }) {
            var item = screenshotItems.remove(at: existingIndex)
            item.createdAt = Date()
            item.originalPath = originalURL.path
            screenshotItems.insert(item, at: 0)
            persistAndTrim()
            return true
        }

        guard let image = NSImage(data: data),
              let thumbData = Self.thumbnailPNG(from: image, maxSize: 320) else {
            return false
        }
        let thumbName = "\(UUID().uuidString).png"
        do {
            try thumbData.write(to: thumbnailURL(for: thumbName))
        } catch {
            return false
        }

        let item = ScreenshotHistoryItem(
            id: UUID(),
            createdAt: Date(),
            originalPath: originalURL.path,
            thumbnailFileName: thumbName,
            contentHash: hash
        )
        screenshotItems.insert(item, at: 0)
        persistAndTrim()
        return true
    }

    func copyScreenshot(_ item: ScreenshotHistoryItem) {
        let url = URL(fileURLWithPath: item.originalPath)
        guard let image = NSImage(contentsOf: url) else { return }
        markIgnoreNextClipboardChange()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    func revealScreenshotInFinder(_ item: ScreenshotHistoryItem) {
        let url = URL(fileURLWithPath: item.originalPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func deleteScreenshotItem(_ item: ScreenshotHistoryItem) {
        guard let index = screenshotItems.firstIndex(where: { $0.id == item.id }) else { return }
        let removed = screenshotItems.remove(at: index)
        try? fileManager.removeItem(at: thumbnailURL(for: removed.thumbnailFileName))
        // Only drop app-owned clipboard captures; never touch system screenshot files.
        removeOwnedScreenshotFile(at: removed.originalPath)
        persist()
    }

    func clearScreenshotHistory() {
        for item in screenshotItems {
            try? fileManager.removeItem(at: thumbnailURL(for: item.thumbnailFileName))
            removeOwnedScreenshotFile(at: item.originalPath)
        }
        screenshotItems = []
        persist()
    }

    // MARK: - Persist

    private func load() {
        guard fileManager.fileExists(atPath: indexURL.path),
              let data = try? Data(contentsOf: indexURL),
              let index = try? decoder.decode(HistoryIndex.self, from: data) else {
            clipboardItems = []
            screenshotItems = []
            return
        }
        clipboardItems = index.clipboard
        screenshotItems = index.screenshots
        persistAndTrim()
    }

    private func persistAndTrim() {
        trimClipboard()
        trimScreenshots()
        persist()
    }

    private func trimClipboard() {
        while clipboardItems.count > Self.clipboardLimit {
            let removed = clipboardItems.removeLast()
            if let name = removed.imageFileName {
                try? fileManager.removeItem(at: imageURL(for: name))
            }
        }
    }

    private func trimScreenshots() {
        while screenshotItems.count > Self.screenshotLimit {
            let removed = screenshotItems.removeLast()
            try? fileManager.removeItem(at: thumbnailURL(for: removed.thumbnailFileName))
            removeOwnedScreenshotFile(at: removed.originalPath)
        }
    }

    /// Only deletes app-owned clipboard-captured copies under Application Support, never Desktop screenshots.
    private func removeOwnedScreenshotFile(at path: String) {
        let capturedPath = capturedURL.path
        guard path.hasPrefix(capturedPath) else { return }
        try? fileManager.removeItem(at: URL(fileURLWithPath: path))
    }

    private func persist() {
        let index = HistoryIndex(clipboard: clipboardItems, screenshots: screenshotItems)
        do {
            let data = try encoder.encode(index)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            NSLog("Pastefinch: failed to persist index: \(error)")
        }
    }

    // MARK: - Helpers

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func hash(_ string: String) -> String {
        hash(Data(string.utf8))
    }

    private static func hash(_ data: Data) -> String {
        var hash: UInt64 = 5381
        for byte in data {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }

    private static func thumbnailPNG(from image: NSImage, maxSize: CGFloat) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxSize / max(size.width, size.height))
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let thumb = NSImage(size: target)
        thumb.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1)
        thumb.unlockFocus()
        guard let tiff = thumb.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
