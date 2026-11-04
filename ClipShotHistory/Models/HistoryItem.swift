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
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: ClipboardContentKind,
        text: String? = nil,
        imageFileName: String? = nil,
        filePath: String? = nil,
        contentHash: String,
        isPinned: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.text = text
        self.imageFileName = imageFileName
        self.filePath = filePath
        self.contentHash = contentHash
        self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        kind = try container.decode(ClipboardContentKind.self, forKey: .kind)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        contentHash = try container.decode(String.self, forKey: .contentHash)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

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

struct DailyStats: Codable, Hashable {
    /// Calendar day key, e.g. `2026-11-04`
    var day: String
    var clipboardCount: Int
    var screenshotCount: Int

    static func empty(for day: String) -> DailyStats {
        DailyStats(day: day, clipboardCount: 0, screenshotCount: 0)
    }
}

struct HistoryIndex: Codable {
    var clipboard: [ClipboardHistoryItem]
    var screenshots: [ScreenshotHistoryItem]
    var dailyStats: DailyStats?

    static let empty = HistoryIndex(clipboard: [], screenshots: [], dailyStats: nil)

    init(clipboard: [ClipboardHistoryItem], screenshots: [ScreenshotHistoryItem], dailyStats: DailyStats? = nil) {
        self.clipboard = clipboard
        self.screenshots = screenshots
        self.dailyStats = dailyStats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clipboard = try container.decodeIfPresent([ClipboardHistoryItem].self, forKey: .clipboard) ?? []
        screenshots = try container.decodeIfPresent([ScreenshotHistoryItem].self, forKey: .screenshots) ?? []
        dailyStats = try container.decodeIfPresent(DailyStats.self, forKey: .dailyStats)
    }
}
