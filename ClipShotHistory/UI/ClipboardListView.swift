import SwiftUI
import AppKit

struct ClipboardListView: View {
    let items: [ClipboardHistoryItem]
    @ObservedObject var store: HistoryStore
    var onSelect: (ClipboardHistoryItem) -> Void

    var body: some View {
        if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        ClipboardRow(
                            item: item,
                            store: store,
                            onSelect: { onSelect(item) },
                            onDelete: { store.deleteClipboardItem(item) }
                        )
                        .contextMenu {
                            Button("复制") { onSelect(item) }
                            if item.kind == .file, let path = item.filePath {
                                Button("在 Finder 中显示") {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                                }
                            }
                            Divider()
                            Button("删除", role: .destructive) {
                                store.deleteClipboardItem(item)
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
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("暂无剪贴板记录")
                .foregroundStyle(.secondary)
            Text("复制文本或图片后会出现在这里")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardHistoryItem
    @ObservedObject var store: HistoryStore
    var onSelect: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    thumbnail
                        .frame(width: 44, height: 44)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.previewText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("删除")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch item.kind {
        case .image:
            if let name = item.imageFileName,
               let image = store.loadNSImage(named: name) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        case .text:
            Image(systemName: "text.alignleft")
                .foregroundStyle(.secondary)
        case .file:
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
        }
    }
}
