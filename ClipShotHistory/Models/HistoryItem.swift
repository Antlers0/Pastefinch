import Foundation
import AppKit

enum ClipboardContentKind: String, Codable, Hashable {
    case text
    case image
    case file
}

struct ClipboardHistoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    var createdAt: Date
    var kind: ClipboardContentKind
    var text: String?
    var imageFileName: String?
    var filePath: String?
    var contentHash: String

    var previewText: String {
        switch kind {
        case .text:
            return text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case .image:
            return "图片"
        case .file:
            return filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "文件"
        }
    }
}

struct ScreenshotHistoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    var createdAt: Date
    var originalPath: String
    var thumbnailFileName: String
    var contentHash: String

    var fileName: String {
        URL(fileURLWithPath: originalPath).lastPathComponent
    }
}

struct HistoryIndex: Codable {
    var clipboard: [ClipboardHistoryItem]
    var screenshots: [ScreenshotHistoryItem]

    static let empty = HistoryIndex(clipboard: [], screenshots: [])
}
