import SwiftUI
import AVFoundation

// MARK: - AudioSection
//
// Microphone picker + the "mute system output while recording" toggle.
// The mic selection persists under the same `preferredMicUniqueID` key
// that the rest of the app reads, so changing it here changes the device
// the recorder will pick up.

struct AudioSection: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var mics = MicrophoneList()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            micBlock
            Divider().background(Color.white.opacity(0.08))
            muteBlock
        }
    }

    // MARK: - Mic

    private var micBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EditorialSectionLabel(text: "Input Device")
            Text("Used by the recorder. \"System Default\" follows the macOS audio settings.")
                .font(Typography.sans(11))
                .foregroundStyle(Palette.muted)
            Picker("", selection: micSelectionBinding) {
                Text("System Default").tag(String?.none)
                ForEach(mics.devices, id: \.uniqueID) { device in
                    Text(device.localizedName).tag(String?.some(device.uniqueID))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Palette.ink)
        }
        .onAppear { mics.refresh() }
    }

    private var micSelectionBinding: Binding<String?> {
        Binding(
            get: { mics.selectedUID },
            set: { newValue in
                if let uid = newValue {
                    UserDefaults.standard.set(uid, forKey: "preferredMicUniqueID")
                } else {
                    UserDefaults.standard.removeObject(forKey: "preferredMicUniqueID")
                }
                mics.refresh()
            }
        )
    }

    // MARK: - Mute

    private var muteBlock: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mute Audio While Recording")
                    .font(Typography.sans(12, .medium))
                    .foregroundStyle(Palette.ink)
                Text("Silences system output so music or video doesn't bleed into the mic. Volume is restored when recording ends.")
                    .font(Typography.sans(11))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $settings.muteOutputWhenRecording)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}
