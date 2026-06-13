import SwiftUI

@main
struct NarraV2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
    }
}
