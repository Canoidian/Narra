import SwiftUI

// MARK: - HotkeysSection
//
// Two global shortcuts: push-to-talk (hold) and push-to-toggle (tap to
// start, tap to stop with review). Reuses `KeyRecorderView` so the chip
// styling stays consistent across the app.

struct HotkeysSection: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            row(
                label: "Push-to-Talk",
                subtitle: "Hold to record. Release to transcribe.",
                binding: $settings.pushToTalkBinding
            )
            Divider().background(Color.white.opacity(0.08))
            row(
                label: "Push-to-Toggle",
                subtitle: "Tap to start. Tap again to stop and review.",
                binding: $settings.pushToToggleBinding
            )
        }
    }

    private func row(label: String, subtitle: String, binding: Binding<KeyBinding>) -> some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.sans(12, .medium))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(Typography.sans(11))
                    .foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            KeyRecorderView(binding: binding)
                .frame(width: 200, height: 30)
        }
    }
}
