import AppKit
import SwiftUI
import Carbon.HIToolbox

/// Borderless panels cannot become key by default, which blocks TextField focus.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: KeyablePanel?
    private var escapeMonitor: Any?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var resignKeyObserver: NSObjectProtocol?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?

    private let store = HistoryStore.shared
    private var clipboardMonitor: ClipboardMonitor?
    private var screenshotWatcher: ScreenshotWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        clipboardMonitor = ClipboardMonitor(store: store)
        clipboardMonitor?.start()

        screenshotWatcher = ScreenshotWatcher(store: store)
        screenshotWatcher?.start()

        setupStatusItem()
        setupPanel()
        registerHotKey()
        setupLocalEscapeMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        screenshotWatcher?.stop()
        stopOutsideClickMonitoring()
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let hotKeyHandler {
            RemoveEventHandler(hotKeyHandler)
        }
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bird", accessibilityDescription: "Pastefinch")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePanel()
            return
        }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "打开面板", action: #selector(togglePanel), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "退出 Pastefinch", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            togglePanel()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func setupPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.acceptsMouseMovedEvents = true

        let root = PopoverRootView(store: store) { [weak self] in
            self?.hidePanel()
        }
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 500)
        panel.contentView = hosting
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 12
        panel.contentView?.layer?.masksToBounds = true

        self.panel = panel
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let panel, let button = statusItem?.button else { return }
        // Refresh hosting root to bind latest store (already ObservedObject)
        let root = PopoverRootView(store: store) { [weak self] in
            self?.hidePanel()
        }
        panel.contentView = NSHostingView(rootView: root)
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 12
        panel.contentView?.layer?.masksToBounds = true

        if let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            let panelSize = panel.frame.size
            var origin = NSPoint(
                x: screenRect.midX - panelSize.width / 2,
                y: screenRect.minY - panelSize.height - 6
            )
            if let screen = buttonWindow.screen ?? NSScreen.main {
                let visible = screen.visibleFrame
                origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - panelSize.width - 8)
                if origin.y < visible.minY {
                    origin.y = screenRect.maxY + 6
                }
            }
            panel.setFrameOrigin(origin)
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        startOutsideClickMonitoring()
    }

    private func hidePanel() {
        stopOutsideClickMonitoring()
        panel?.orderOut(nil)
    }

    private func setupLocalEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.hidePanel()
                return nil
            }
            return event
        }
    }

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closeIfClickOutside(event)
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            // Global monitor has no window association; use mouse location.
            self?.closeIfClickOutside(nil)
        }

        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // Clicking into another app often resigns key before global click arrives.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard let self, let panel = self.panel, panel.isVisible, !panel.isKeyWindow else { return }
                self.hidePanel()
            }
        }
    }

    private func stopOutsideClickMonitoring() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
            self.resignKeyObserver = nil
        }
    }

    private func closeIfClickOutside(_ event: NSEvent?) {
        guard let panel, panel.isVisible else { return }

        let location: NSPoint
        if let event, let window = event.window {
            location = window.convertToScreen(
                NSRect(origin: event.locationInWindow, size: .zero)
            ).origin
        } else {
            location = NSEvent.mouseLocation
        }

        if panel.frame.contains(location) {
            return
        }

        // Let the status item handle its own click (toggle), don't double-close/open.
        if let button = statusItem?.button, let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            if screenRect.contains(location) {
                return
            }
        }

        hidePanel()
    }

    // ⌥⌘V
    private func registerHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x43534831), id: 1) // 'CSH1'
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    delegate.togglePanel()
                }
                return noErr
            },
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &hotKeyHandler
        )

        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
