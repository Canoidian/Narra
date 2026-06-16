import SwiftUI

struct ContentView: View {
    @State private var isShowingSettings = false
    @State private var transcribedText: String = "Transcription will appear here..."

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 0) {
                // MARK: Header
                HStack {
                    StatusIndicator(status: "Ready")
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Status: Ready")

                    Spacer()

                    Button(action: { isShowingSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Settings")
                    .keyboardShortcut(",")
                }
                .padding(.horizontal)
                .padding(.top, 16)

                Divider()
                    .background(.white.opacity(0.2))
                    .padding(.horizontal)

                // MARK: Transcription Area
                ScrollView {
                    Text(transcribedText)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
                        .padding()
                }
                .padding()
                .background {
                    if #available(macOS 26.0, *) {
                        RoundedRectangle(cornerRadius: 16)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thinMaterial)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.bottom, 16)

            // MARK: Settings Panel (overlay)
            if isShowingSettings {
                SettingsPanel(isPresented: $isShowingSettings)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(WindowAccessor.configure())
        .frame(minWidth: 500, minHeight: 300)
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let status: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status == "Ready" ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(status)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Settings Panel

struct SettingsPanel: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Close Settings")
                .keyboardShortcut(.escape)
            }

            Divider()

            Group {
                Text("Speech Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Whisper Tiny")
                    .font(.body)

                Text("Language Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Llama 3.2 1B (local)")
                    .font(.body)

                Text("Shortcut")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("⌘R – Start / Stop recording")
                    .font(.body)
            }

            Spacer()
        }
        .padding()
        .frame(width: 280, height: 320)
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 20)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 10)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}
