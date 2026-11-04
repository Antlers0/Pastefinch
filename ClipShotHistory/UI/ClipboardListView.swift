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
                LazyVStack(spacing: 2) {
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
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(PFTheme.accentSoft)
                    .frame(width: 52, height: 52)
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(PFTheme.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            Text("暂无剪贴板记录")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PFTheme.inkSecondary)
            Text("复制文本、图片或文件后会出现在这里")
                .font(.system(size: 11))
                .foregroundStyle(PFTheme.inkTertiary)
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

    @State private var hovering = false

    private var parsedColor: ParsedColor? {
        guard item.kind == .text else { return nil }
        return ColorParser.parse(item.text ?? "")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onSelect) {
                HStack(alignment: .center, spacing: 10) {
                    thumbnail

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.previewText.isEmpty ? " " : item.previewText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(PFTheme.ink)

                        HStack(spacing: 6) {
                            if item.isPinned {
                                HStack(spacing: 3) {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 8, weight: .bold))
                                    Text("PIN")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(PFTheme.pin)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(PFTheme.pin.opacity(0.12)))
                            }
                            if let color = parsedColor {
                                Text(color.hex)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(PFTheme.inkSecondary)
                            } else {
                                Text(kindLabel)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(PFTheme.inkTertiary)
                            }
                            Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(PFTheme.inkTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 2) {
                PFGhostIconButton(
                    systemName: item.isPinned ? "pin.fill" : "pin",
                    tint: item.isPinned ? PFTheme.pin : PFTheme.inkSecondary,
                    help: item.isPinned ? "取消固定" : "固定",
                    action: onTogglePin
                )
                .opacity(hovering || item.isPinned ? 1 : 0)

                PFGhostIconButton(
                    systemName: "trash",
                    tint: PFTheme.inkSecondary,
                    help: "删除",
                    action: onDelete
                )
                .opacity(hovering ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: PFTheme.rowCorner, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PFTheme.rowCorner, style: .continuous)
                .strokeBorder(item.isPinned ? PFTheme.accent.opacity(0.22) : .clear, lineWidth: 1)
        )
        .onHover { hovering = $0 }
    }

    private var backgroundFill: Color {
        if hovering { return PFTheme.rowHover }
        if item.isPinned { return PFTheme.rowPinned }
        return PFTheme.rowIdle
    }

    private var kindLabel: String {
        switch item.kind {
        case .text: return "TEXT"
        case .image: return "IMAGE"
        case .file: return "FILE"
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch item.kind {
        case .image:
            Group {
                if let name = item.imageFileName,
                   let image = store.loadNSImage(named: name) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 36)
            .background(PFTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(PFTheme.hairline, lineWidth: 1)
            )
        case .text:
            if let color = parsedColor {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.swiftUIColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(PFTheme.hairline, lineWidth: 1)
                    )
                    .shadow(color: color.swiftUIColor.opacity(0.28), radius: 4, y: 1)
            } else {
                PFIconBadge(systemName: "text.alignleft", tint: PFTheme.accent)
            }
        case .file:
            PFIconBadge(systemName: "doc", tint: PFTheme.inkSecondary)
        }
    }
}
