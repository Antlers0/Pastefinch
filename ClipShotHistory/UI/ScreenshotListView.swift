import SwiftUI
import AppKit

struct ScreenshotListView: View {
    let items: [ScreenshotHistoryItem]
    @ObservedObject var store: HistoryStore
    var onSelect: (ScreenshotHistoryItem) -> Void

    @State private var previewItem: ScreenshotHistoryItem?

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10)
    ]

    var body: some View {
        ZStack {
            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(items) { item in
                            ScreenshotCell(
                                item: item,
                                store: store,
                                onPreview: { previewItem = item },
                                onSelect: { onSelect(item) },
                                onDelete: { store.deleteScreenshotItem(item) }
                            )
                            .frame(maxWidth: .infinity, alignment: .top)
                            .contextMenu {
                                Button("放大预览") { previewItem = item }
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

            if let previewItem {
                ScreenshotPreviewOverlay(
                    item: previewItem,
                    store: store,
                    onClose: { self.previewItem = nil },
                    onCopy: {
                        onSelect(previewItem)
                    },
                    onReveal: {
                        store.revealScreenshotInFinder(previewItem)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.16), value: previewItem?.id)
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
    var onPreview: () -> Void
    var onSelect: () -> Void
    var onDelete: () -> Void

    @State private var hovering = false
    private let thumbHeight: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                Button(action: onPreview) {
                    thumbnail
                        .overlay(alignment: .bottomTrailing) {
                            if hovering {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(Circle().fill(Color.black.opacity(0.42)))
                                    .padding(6)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help("放大预览")

                HStack(spacing: 4) {
                    PFGhostIconButton(
                        systemName: "doc.on.doc",
                        tint: .white,
                        help: "复制图片",
                        action: onSelect
                    )
                    PFGhostIconButton(
                        systemName: "trash",
                        tint: .white,
                        help: "删除",
                        action: onDelete
                    )
                }
                .padding(4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(hovering ? 0.42 : 0))
                )
                .opacity(hovering ? 1 : 0)
                .padding(6)
                .animation(.easeOut(duration: 0.12), value: hovering)
            }

            Button(action: onPreview) {
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

private struct ScreenshotPreviewOverlay: View {
    let item: ScreenshotHistoryItem
    @ObservedObject var store: HistoryStore
    var onClose: () -> Void
    var onCopy: () -> Void
    var onReveal: () -> Void

    @State private var scale: CGFloat = 1
    @State private var loadedImage: NSImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.fileName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PFTheme.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(PFTheme.inkTertiary)
                    }
                    Spacer(minLength: 8)

                    previewToolbarButton("minus.magnifyingglass", help: "缩小") {
                        scale = max(0.5, scale - 0.25)
                    }
                    previewToolbarButton("plus.magnifyingglass", help: "放大") {
                        scale = min(3, scale + 0.25)
                    }
                    previewToolbarButton("doc.on.doc", help: "复制图片", action: onCopy)
                    previewToolbarButton("folder", help: "在 Finder 中显示", action: onReveal)
                    previewToolbarButton("xmark", help: "关闭", action: onClose)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                PFHairline()

                ZStack {
                    PFTheme.surfaceMuted.opacity(0.65)
                    if let loadedImage {
                        Image(nsImage: loadedImage)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .scaleEffect(scale)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                            .padding(14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = min(3, max(0.5, value))
                                    }
                            )
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: 360, maxHeight: 420)
            .background(PFTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(PFTheme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .padding(16)
        }
        .onAppear {
            loadedImage = NSImage(contentsOf: URL(fileURLWithPath: item.originalPath))
                ?? store.loadNSImage(named: item.thumbnailFileName, fromThumbnails: true)
        }
        .onExitCommand(perform: onClose)
        .focusable()
    }

    private func previewToolbarButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PFTheme.inkSecondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(PFTheme.surfaceMuted)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(PFTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
