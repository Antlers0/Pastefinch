import SwiftUI
import AppKit

enum HistoryTab: String, CaseIterable, Identifiable {
    case clipboard = "剪贴板"
    case screenshots = "截图"

    var id: String { rawValue }
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
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 400, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pastefinch")
                    .font(.headline)
                Spacer()
                todayStatsChip
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }

            Picker("", selection: $tab) {
                ForEach(HistoryTab.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(tab == .clipboard ? "搜索文本…" : "搜索文件名…", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .contentShape(Rectangle())
            .onTapGesture {
                isSearchFocused = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var todayStatsChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("今日 \(store.todayClipboardCount)+\(store.todayScreenshotCount)")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
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
        case .screenshots:
            ScreenshotListView(
                items: filteredScreenshots,
                store: store,
                onSelect: { item in
                    store.copyScreenshot(item)
                    onClose()
                }
            )
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tab == .clipboard
                     ? "\(store.clipboardItems.count)/\(HistoryStore.clipboardLimit)"
                     : "\(store.screenshotItems.count)/\(HistoryStore.screenshotLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("⌥⌘V")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("今日 剪贴板 \(store.todayClipboardCount) · 截图 \(store.todayScreenshotCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack {
                Spacer()
                Button(tab == .clipboard ? "清空剪贴板历史" : "清空截图历史") {
                    if tab == .clipboard {
                        store.clearClipboardHistory()
                    } else {
                        store.clearScreenshotHistory()
                    }
                }
                .controlSize(.small)
                .help(tab == .clipboard
                      ? "清空未固定项；固定项会保留"
                      : "只清除本 App 记录，不删除系统截图文件")
                Button("退出") {
                    NSApp.terminate(nil)
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
