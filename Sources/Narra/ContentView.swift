import SwiftUI
import AppKit
import AVFoundation

/// The HUD window's root view. Shows the notch-aligned waveform bead during
/// recording / processing / reviewing; hidden otherwise. The main app window
/// (provider/model status) lives in `MainWindowView`.
struct ContentView: View {
    @ObservedObject private var viewModel = ContentViewModel.shared

    var body: some View {
        Group {
            switch viewModel.uiMode {
            case .hidden:
                Color.clear
            case .recording, .processing, .reviewing:
                NotchBead(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        // ponytail: fixed outer frame so NSHostingView's content-size extrema
        // never flap. Without this, the (1,1) → unbounded transition on fn
        // races setFrame and crashes in _postWindowNeedsUpdateConstraints.
        .frame(width: 320, height: 72)
        .animation(Motion.snappy, value: viewModel.uiMode)
        .background(HUDWindowBehavior(mode: viewModel.uiMode))
    }
}

// MARK: - HUD window behavior

/// Sizes / positions / hides the HUD window based on `uiMode`. Pins the
/// window to the notch on notched displays, or to a top-center pill on
/// everything else (external monitors, older MacBooks).
private struct HUDWindowBehavior: NSViewRepresentable {
    let mode: ContentViewModel.UIMode

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = false

            switch mode {
            case .hidden:
                window.orderOut(nil)
            case .recording, .processing, .reviewing:
                let screen = NSScreen.main ?? NSScreen.screens[0]
                // Window is the same width as the notch (or a sensible
                // ~200pt pill on non-notch displays); height leaves room
                // for the bead's drop expansion + drop shadow.
                // ponytail: fixed 320 matches ContentView's outer frame, which
                // exists so NSHostingView extrema don't flap on mode change.
                let w: CGFloat = 320
                let h: CGFloat = 72
                // visibleFrame excludes the menu bar / notch strip, so the
                // window's top sits flush under the notch — the bead reads as
                // dropping down from it instead of hiding behind it.
                let x = screen.visibleFrame.midX - w / 2
                let y = screen.visibleFrame.maxY - h
                window.level = .statusBar
                window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true, animate: false)
                window.orderFront(nil)
            }
        }
    }
}

// MARK: - Menu bar bridge

/// Holds a weak reference to the shared `ContentViewModel` so the menu bar
/// extra can drive it. Populated by `NarraApp` at startup.
@MainActor
enum MenuBarShared {
    static weak var viewModel: ContentViewModel?
}
