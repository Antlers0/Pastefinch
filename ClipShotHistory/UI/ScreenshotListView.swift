import SwiftUI
import AppKit

struct ScreenshotListView: View {
    let items: [ScreenshotHistoryItem]
    @ObservedObject var store: HistoryStore
    var onSelect: (ScreenshotHistoryItem) -> Void

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10)
    ]

    var body: some View {
        if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(PFTheme.accentSoft)
                    .frame(width: 52, height: 52)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(PFTheme.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            Text("暂无截图记录")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PFTheme.inkSecondary)
            Text("⌘⇧3/4 存盘，或 ⌃⌘⇧3/4 复制到剪贴板")
                .font(.system(size: 11))
                .foregroundStyle(PFTheme.inkTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ScreenshotCell: View {
    let item: ScreenshotHistoryItem
    @ObservedObject var store: HistoryStore
    var onSelect: () -> Void
    var onDelete: () -> Void

    @State private var hovering = false
    private let thumbHeight: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                Button(action: onSelect) {
                    thumbnail
                }
                .buttonStyle(.plain)

                PFGhostIconButton(
                    systemName: "trash",
                    tint: .white,
                    help: "删除",
                    action: onDelete
                )
                .padding(6)
                .background(
                    Circle()
                        .fill(Color.black.opacity(hovering ? 0.45 : 0))
                )
                .opacity(hovering ? 1 : 0)
                .padding(6)
                .animation(.easeOut(duration: 0.12), value: hovering)
            }

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                        .font(.system(size: 10.5, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(PFTheme.ink)
                    Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PFTheme.inkTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovering ? PFTheme.rowHover : PFTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(hovering ? PFTheme.accent.opacity(0.28) : PFTheme.hairline, lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .clipped()
    }

    private var thumbnail: some View {
        PFTheme.surfaceMuted
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
                            .foregroundStyle(PFTheme.inkTertiary)
                    }
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(PFTheme.hairline, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
