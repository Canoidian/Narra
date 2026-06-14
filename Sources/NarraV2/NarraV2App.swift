import SwiftUI
import AppKit

// MARK: - Window Configuration

/// Provides an AppKit hook to elevate the window level and make it
/// draggable by its background. Placed as a non-interactive overlay.
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.level = .floating
            window.isMovableByWindowBackground = true
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func configure() -> some View {
        WindowAccessor()
            .allowsHitTesting(false)
    }
}

// MARK: - App Entry Point

@main
struct NarraV2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 500, minHeight: 300)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 400)
        .windowResizability(.contentSize)
    }
}
