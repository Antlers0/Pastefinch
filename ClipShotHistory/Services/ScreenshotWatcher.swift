import Foundation
import AppKit

@MainActor
final class ScreenshotWatcher {
    private let store: HistoryStore
    private var sources: [DispatchSourceFileSystemObject] = []
    private var directoryFileDescriptors: [Int32] = []
    private var knownPaths: Set<String> = []
    private var debounceWorkItems: [String: DispatchWorkItem] = [:]

    init(store: HistoryStore = .shared) {
        self.store = store
    }

    func start() {
        stop()
        let directories = Self.resolveScreenshotDirectories()
        for dir in directories {
            beginWatching(directory: dir)
            seedExisting(in: dir)
        }
    }

    func stop() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
        for fd in directoryFileDescriptors {
            close(fd)
        }
        directoryFileDescriptors.removeAll()
        debounceWorkItems.values.forEach { $0.cancel() }
        debounceWorkItems.removeAll()
    }

    private func beginWatching(directory: URL) {
        let path = directory.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("Pastefinch: cannot open screenshot directory \(path)")
            return
        }
        directoryFileDescriptors.append(fd)

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename, .link],
            queue: DispatchQueue.main
        )
        source.setEventHandler { [weak self] in
            self?.handleDirectoryChange(directory)
        }
        source.setCancelHandler {
            // fd closed in stop()
        }
        source.resume()
        sources.append(source)
    }

    private func seedExisting(in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let screenshots = files
            .filter { Self.isScreenshotCandidate($0) }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
            .prefix(HistoryStore.screenshotLimit)

        for url in screenshots {
            knownPaths.insert(url.path)
            store.addScreenshot(at: url)
        }
    }

    private func handleDirectoryChange(_ directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in files where Self.isScreenshotCandidate(url) {
            let path = url.path
            guard !knownPaths.contains(path) else { continue }
            debounceWorkItems[path]?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                // Wait until file is fully written
                guard FileManager.default.fileExists(atPath: path),
                      let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let size = attrs[.size] as? NSNumber,
                      size.intValue > 0 else { return }
                self.knownPaths.insert(path)
                self.store.addScreenshot(at: url)
                self.debounceWorkItems[path] = nil
            }
            debounceWorkItems[path] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
        }
    }

    static func resolveScreenshotDirectories() -> [URL] {
        var dirs: [URL] = []
        var seen = Set<String>()

        func add(_ url: URL) {
            let standardized = url.standardizedFileURL
            let key = standardized.path
            guard !seen.contains(key) else { return }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: key, isDirectory: &isDir), isDir.boolValue else { return }
            seen.insert(key)
            dirs.append(standardized)
        }

        if let custom = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            add(URL(fileURLWithPath: (custom as NSString).expandingTildeInPath))
        }

        // Fallback common locations
        add(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"))
        add(FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures")
            .appendingPathComponent("Screenshots"))

        return dirs
    }

    static func isScreenshotCandidate(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "heic"].contains(ext) else { return false }
        let name = url.lastPathComponent
        // Match common macOS screenshot naming (EN / ZH)
        let patterns = ["Screenshot", "Screen Shot", "截屏", "屏幕快照"]
        return patterns.contains { name.contains($0) }
    }
}
