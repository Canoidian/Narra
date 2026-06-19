import SwiftUI
import AppKit
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var showInputMonitoringAlert = false
    @State private var showMicMenu = false
    @State private var didTriggerOnboarding = false
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            switch viewModel.uiMode {
            case .hidden:
                Color.clear.frame(width: 1, height: 1)
            case .home:
                homeBody
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .recording, .processing, .reviewing:
                GlassHUD(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(Motion.snappy, value: viewModel.uiMode)
        .background(WindowBehavior(mode: viewModel.uiMode))
        .task {
            MenuBarShared.viewModel = viewModel
            KeybindingManager.shared.onPushToTalkStart = { viewModel.startPushToTalk() }
            KeybindingManager.shared.onPushToTalkStop  = { viewModel.stopPushToTalk() }
            KeybindingManager.shared.onPushToToggle    = { viewModel.handleToggleHotkey() }
            KeybindingManager.shared.start()
            if !KeybindingManager.shared.hasInputMonitoringAccess {
                showInputMonitoringAlert = true
            }
            // ponytail: guard fires once per launch — relaunch after a
            // Settings "Re-run onboarding…" reopens the wizard on next start.
            if !didTriggerOnboarding && !AppSettings.shared.hasCompletedOnboarding {
                didTriggerOnboarding = true
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "onboarding")
            }
        }
        .alert("Input Monitoring Required", isPresented: $showInputMonitoringAlert) {
            Button("Open System Settings") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
                )
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Narra needs Input Monitoring to use fn key shortcuts. Enable it in System Settings → Privacy & Security → Input Monitoring.")
        }
    }

    // MARK: - Home panel

    private var homeBody: some View {
        ZStack {
            // ponytail: clear window + rounded glass card = transparent panel
            // floating in the room. WindowBehavior sets backgroundColor = .clear.
            Color.clear.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    Button {
                        NSApp.activate(ignoringOtherApps: true)
                        openSettings()
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 32, height: 32)
                            .background(glassyButtonBackground(prominent: false))
                    }
                    .buttonStyle(.plain)
                    .help("Open Narra Settings")

                    Text("Narra")
                        .font(Typography.serif(22, .medium))
                        .foregroundStyle(Palette.ink)

                    Spacer()

                    Button(action: viewModel.hideHome) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }

                // Paste Last + preview
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    homeButton(title: "Paste Last Transcription",
                               icon: "doc.on.clipboard",
                               filled: false,
                               disabled: viewModel.lastTranscript.isEmpty,
                               action: viewModel.pasteLastTranscription)
                    Text(viewModel.lastTranscript.isEmpty
                         ? "No transcription yet"
                         : viewModel.lastTranscript)
                        .font(Typography.sans(11))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.xs)
                }

                // Microphone button — click to reveal device menu
                Button {
                    showMicMenu.toggle()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "mic")
                            .font(.system(size: 13, weight: .medium))
                        Text("Microphone")
                            .font(Typography.sans(13, .medium))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(glassyButtonBackground(prominent: false))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showMicMenu, arrowEdge: .bottom) {
                    HomeMicrophonePicker()
                }

                Spacer(minLength: Spacing.sm)

                // Quit at the bottom
                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .medium))
                        Text("Quit Narra")
                            .font(Typography.sans(12, .medium))
                        Spacer()
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(glassyButtonBackground(prominent: false))
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.lg)
            .background(homePanelBackground)
            .padding(Spacing.md)
        }
        .frame(width: 340, height: 320)
    }

    @ViewBuilder
    private var homePanelBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if #available(macOS 26.0, *) {
            shape.fill(.clear)
                .glassEffect(.regular, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.10), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 12)
        } else {
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(Color.black.opacity(0.30)))
                .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 12)
        }
    }

    private func homeButton(title: String,
                            icon: String,
                            filled: Bool,
                            disabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(Typography.sans(13, .medium))
                Spacer()
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(glassyButtonBackground(prominent: filled))
            .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    @ViewBuilder
    private func glassyButtonBackground(prominent: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
        if #available(macOS 26.0, *) {
            ZStack {
                shape.fill(.clear)
                    .glassEffect(.regular.interactive(), in: shape)
                if prominent {
                    shape.fill(Color.white.opacity(0.10))
                }
            }
        } else {
            ZStack {
                shape.fill(prominent ? Palette.ink : Color.clear)
                shape.stroke(prominent ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
            }
        }
    }
}

// MARK: - Glass HUD (recording / processing / reviewing)

private struct GlassHUD: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var open = false

    private let collapsedWidth: CGFloat = 48
    private let height: CGFloat = 40

    /// Snug width per state — bead hugs its content.
    private var targetWidth: CGFloat {
        switch viewModel.uiMode {
        case .recording:  return 144
        case .processing: return 48
        case .reviewing:  return 116
        default:          return collapsedWidth
        }
    }

    var body: some View {
        GlassBead(width: open ? targetWidth : collapsedWidth, height: height) {
            ZStack {
                switch viewModel.uiMode {
                case .recording:
                    recordingContent
                case .processing:
                    processingContent
                case .reviewing:
                    reviewContent
                default:
                    EmptyView()
                }
            }
            .opacity(open ? 1 : 0)
            .animation(.easeOut(duration: 0.18).delay(0.30), value: open)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05)) {
                open = true
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.80), value: viewModel.uiMode)
        .frame(width: 240, height: 96)
    }

    // MARK: - HUD contents

    /// Push-to-talk + push-to-toggle both show this while recording.
    /// Just the waveform inside the bead — no mic chip, no stop button.
    private var recordingContent: some View {
        WaveformView(levels: viewModel.audioLevels)
            .frame(height: 24)
    }

    /// Processing is silent — a thin progress bar pulses inside the bead.
    private var processingContent: some View {
        ProgressView()
            .progressViewStyle(.linear)
            .tint(Palette.ink)
            .frame(width: 28)
    }

    /// Only reachable via push-to-toggle. X (discard) / check (paste) and nothing else.
    private var reviewContent: some View {
        HStack(spacing: Spacing.md) {
            hudIconButton(symbol: "xmark",
                          bg: Palette.redBg.opacity(0.55),
                          fg: Palette.redInk,
                          action: viewModel.cancelReview)
                .accessibilityLabel("Discard transcription")

            Spacer(minLength: 0)

            hudIconButton(symbol: "checkmark",
                          bg: Palette.greenBg.opacity(0.55),
                          fg: Palette.greenInk,
                          action: viewModel.acceptReview)
                .accessibilityLabel("Paste transcription")
        }
    }

    private func hudIconButton(symbol: String,
                               bg: Color,
                               fg: Color,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(fg)
                .frame(width: 28, height: 28)
                .background(glassyCircle(tint: bg))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func glassyCircle(tint: Color) -> some View {
        if #available(macOS 26.0, *) {
            ZStack {
                Circle().fill(.clear)
                    .glassEffect(.regular.interactive(), in: Circle())
                Circle().fill(tint.opacity(0.55))
            }
        } else {
            Circle().fill(tint)
        }
    }
}

// MARK: - Window Behavior

/// Sizes / positions / hides the single shared window based on `uiMode`.
private struct WindowBehavior: NSViewRepresentable {
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
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let screen = NSScreen.main ?? NSScreen.screens[0]
            switch mode {
            case .hidden:
                window.orderOut(nil)
                NSApp.setActivationPolicy(.accessory)
            case .home:
                window.isMovable = true
                window.isMovableByWindowBackground = true
                let w: CGFloat = 340, h: CGFloat = 320
                let x = screen.visibleFrame.midX - w / 2
                let y = screen.visibleFrame.midY - h / 2
                window.level = .normal
                window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true, animate: false)
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            case .recording, .processing, .reviewing:
                // HUD bead is pinned to the bottom; user shouldn't drag it.
                window.isMovable = false
                window.isMovableByWindowBackground = false
                // Roomier window so the bead's drop shadow isn't clipped.
                // Bottom-center, ~28pt above the bottom of the visible area.
                let w: CGFloat = 240, h: CGFloat = 96
                let x = screen.visibleFrame.midX - w / 2
                let y = screen.visibleFrame.minY + 28
                window.level = .floating
                window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true, animate: false)
                NSApp.setActivationPolicy(.accessory)
                window.orderFront(nil)
            }
        }
    }
}

// MARK: - Home microphone picker

private struct HomeMicrophonePicker: View {
    @State private var devices: [AVCaptureDevice] = []
    @State private var selectedUID: String? = UserDefaults.standard.string(forKey: "preferredMicUniqueID")

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row(label: "System Default", checked: selectedUID == nil) {
                UserDefaults.standard.removeObject(forKey: "preferredMicUniqueID")
                selectedUID = nil
            }
            if !devices.isEmpty {
                Divider().background(Color.white.opacity(0.08))
            }
            ForEach(devices, id: \.uniqueID) { device in
                row(label: device.localizedName, checked: selectedUID == device.uniqueID) {
                    UserDefaults.standard.set(device.uniqueID, forKey: "preferredMicUniqueID")
                    selectedUID = device.uniqueID
                }
            }
        }
        .padding(Spacing.xs)
        .frame(minWidth: 240)
        .background(Palette.canvas)
        .onAppear(perform: refresh)
    }

    private func row(label: String, checked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: checked ? "checkmark" : "")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 14)
                Text(label)
                    .font(Typography.sans(12, .medium))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func refresh() {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        devices = session.devices
    }
}

// MARK: - Menu bar bridge

/// Holds a weak reference to the active `ContentViewModel` so the
/// menu bar extra (which lives in the App scene, separate from
/// `ContentView`) can drive it. Populated in `ContentView.task`.
@MainActor
enum MenuBarShared {
    static weak var viewModel: ContentViewModel?
}
