import SwiftUI
import AppKit

struct ScreenshotListView: View {
    let items: [ScreenshotHistoryItem]
    @ObservedObject var store: HistoryStore
    var onSelect: (ScreenshotHistoryItem) -> Void

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 12),
        GridItem(.flexible(minimum: 0), spacing: 12)
    ]

    var body: some View {
        if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { item in
                        ScreenshotCell(
                            item: item,
                            store: store,
                            onSelect: { onSelect(item) },
                            onDelete: { store.deleteScreenshotItem(item) }
                        )
                        .frame(maxWidth: .infinity, alignment: .top)
                        .contextMenu {
                            Button("复制图片") { onSelect(item) }
                            Button("在 Finder 中显示") {
                                store.revealScreenshotInFinder(item)
                            }
                            Divider()
                            Button("删除", role: .destructive) {
                                store.deleteScreenshotItem(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("暂无截图记录")
                .foregroundStyle(.secondary)
            Text("⌘⇧3/4 存盘，或 ⌃⌘⇧3/4 复制到剪贴板，都会出现在这里")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ScreenshotCell: View {
    let item: ScreenshotHistoryItem
    @ObservedObject var store: HistoryStore
    var onSelect: () -> Void
    var onDelete: () -> Void

    private let thumbHeight: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Button(action: onSelect) {
                    thumbnail
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                }
                .buttonStyle(.plain)
                .help("删除")
                .padding(8)
            }

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileName)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary)
                    Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .clipped()
    }

    /// Use overlay so `.scaledToFill` cannot expand the cell layout width.
    private var thumbnail: some View {
        Color(nsColor: .controlBackgroundColor)
            .frame(height: thumbHeight)
            .frame(maxWidth: .infinity)
            .overlay {
                Group {
                    if let image = store.loadNSImage(named: item.thumbnailFileName, fromThumbnails: true) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else if let original = NSImage(contentsOf: URL(fileURLWithPath: item.originalPath)) {
                        Image(nsImage: original)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}
