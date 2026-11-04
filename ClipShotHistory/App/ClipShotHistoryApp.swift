import SwiftUI

@main
struct ClipShotHistoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app: no windows from SwiftUI scenes.
        Settings {
            EmptyView()
        }
    }
}
