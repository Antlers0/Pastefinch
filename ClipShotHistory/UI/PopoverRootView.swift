import SwiftUI
import AppKit

enum HistoryTab: String, CaseIterable, Identifiable {
    case clipboard
    case screenshots

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboard: return "剪贴板"
        case .screenshots: return "截图"
        }
    }

    var symbol: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .screenshots: return "camera.viewfinder"
        }
    }
}

struct PopoverRootView: View {
    @ObservedObject var store: HistoryStore
    var onClose: () -> Void

    @State private var tab: HistoryTab = .clipboard
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            PFHairline()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(tab)
            PFHairline()
            footer
        }
        .frame(width: 392, height: 528)
        .background {
            ZStack {
                PFTheme.panel
                LinearGradient(
                    colors: [
                        PFTheme.panelTint,
                        PFTheme.panel,
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PFTheme.panelCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PFTheme.panelCorner, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white,
                            PFTheme.hairline,
                            PFTheme.accent.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .preferredColorScheme(.light)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PFTheme.accentSoft)
                    Image(systemName: "bird")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PFTheme.accent)
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Pastefinch")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .tracking(0.2)
                        .foregroundStyle(PFTheme.ink)
                    Text("LOCAL · HISTORY")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(PFTheme.inkTertiary)
                }

                Spacer(minLength: 8)

                todayStatsChip

                PFGhostIconButton(systemName: "xmark", help: "关闭", action: onClose)
            }

            tabSwitcher

            searchField
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var tabSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(HistoryTab.allCases) { item in
                tabChip(item)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(PFTheme.surfaceMuted)
        )
    }

    private func tabChip(_ item: HistoryTab) -> some View {
        let selected = tab == item
        return HStack(spacing: 6) {
            Image(systemName: item.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(item.title)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(selected ? PFTheme.ink : PFTheme.inkSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected ? PFTheme.surface : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(selected ? PFTheme.accent.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard tab != item else { return }
            tab = item
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(item.title)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PFTheme.inkTertiary)
            TextField(tab == .clipboard ? "搜索文本" : "搜索文件名", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(PFTheme.ink)
                .focused($isSearchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(PFTheme.inkTertiary)
                }
                .buttonStyle(.plain)
            } else {
                PFKeyCap(text: "⌥⌘V")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: PFTheme.controlCorner, style: .continuous)
                .fill(PFTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PFTheme.controlCorner, style: .continuous)
                .strokeBorder(
                    isSearchFocused ? PFTheme.accent.opacity(0.45) : PFTheme.hairline,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { isSearchFocused = true }
        .animation(.easeOut(duration: 0.15), value: isSearchFocused)
    }

    private var todayStatsChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(PFTheme.accent)
                .frame(width: 5, height: 5)
                .shadow(color: PFTheme.accent.opacity(0.55), radius: 3, y: 0)
            Text("今日 \(store.todayClipboardCount)+\(store.todayScreenshotCount)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(PFTheme.inkSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(PFTheme.surface)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(PFTheme.hairline, lineWidth: 1)
        )
        .help("今日捕获：剪贴板 \(store.todayClipboardCount) · 截图 \(store.todayScreenshotCount)")
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .clipboard:
            ClipboardListView(
                items: filteredClipboard,
                store: store,
                onSelect: { item in
                    store.copyClipboardItem(item)
                    onClose()
                }
            )
            .transition(.opacity)
        case .screenshots:
            ScreenshotListView(
                items: filteredScreenshots,
                store: store,
                onSelect: { item in
                    store.copyScreenshot(item)
                    onClose()
                }
            )
            .transition(.opacity)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(capacityLabel)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(PFTheme.inkTertiary)

            Spacer(minLength: 0)

            Button(tab == .clipboard ? "清空" : "清空截图") {
                if tab == .clipboard {
                    store.clearClipboardHistory()
                } else {
                    store.clearScreenshotHistory()
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(PFTheme.inkSecondary)
            .help(tab == .clipboard
                  ? "清空未固定项；固定项会保留"
                  : "只清除本 App 记录，不删除系统截图文件")

            Text("·")
                .foregroundStyle(PFTheme.inkTertiary)

            Button("退出") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(PFTheme.inkSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var capacityLabel: String {
        if tab == .clipboard {
            return "\(store.clipboardItems.count)/\(HistoryStore.clipboardLimit)  ·  今日 \(store.todayClipboardCount)"
        }
        return "\(store.screenshotItems.count)/\(HistoryStore.screenshotLimit)  ·  今日 \(store.todayScreenshotCount)"
    }

    private var filteredClipboard: [ClipboardHistoryItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.clipboardItems }
        return store.clipboardItems.filter {
            $0.previewText.localizedCaseInsensitiveContains(q)
            || ($0.text?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    private var filteredScreenshots: [ScreenshotHistoryItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.screenshotItems }
        return store.screenshotItems.filter {
            $0.fileName.localizedCaseInsensitiveContains(q)
            || $0.originalPath.localizedCaseInsensitiveContains(q)
        }
    }
}
