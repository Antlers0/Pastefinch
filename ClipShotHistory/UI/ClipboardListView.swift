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
                            onDelete: { store.deleteClipboardItem(item) },
                            onTogglePin: { store.togglePin(item) }
                        )
                        .contextMenu {
                            Button("复制") { onSelect(item) }
                            if let color = ColorParser.parse(item.text ?? "") {
                                Divider()
                                Button("复制 HEX \(color.hex)") {
                                    store.copyPlainString(color.hex)
                                }
                                Button("复制 \(color.rgbLabel)") {
                                    store.copyPlainString(color.rgbLabel)
                                }
                            }
                            if item.kind == .file, let path = item.filePath {
                                Divider()
                                Button("在 Finder 中显示") {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                                }
                            }
                            Divider()
                            Button(item.isPinned ? "取消固定" : "固定") {
                                store.togglePin(item)
                            }
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
    var onTogglePin: () -> Void

    private var parsedColor: ParsedColor? {
        guard item.kind == .text else { return nil }
        return ColorParser.parse(item.text ?? "")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    thumbnail
                        .frame(width: 44, height: 44)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.primary.opacity(parsedColor == nil ? 0 : 0.12), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.previewText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            if item.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.orange)
                            }
                            if let color = parsedColor {
                                Text(color.hex)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onTogglePin) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(item.isPinned ? Color.orange : Color.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "取消固定" : "固定")

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
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(item.isPinned ? Color.orange.opacity(0.35) : Color.clear, lineWidth: 1)
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
            if let color = parsedColor {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.swiftUIColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )
            } else {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.secondary)
            }
        case .file:
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
        }
    }
}
