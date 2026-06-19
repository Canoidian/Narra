import SwiftUI

// MARK: - CloudLLMSection
//
// ponytail: deferred — post-processing provider chooser lands here later.
//   Today: GrokPostProcessingService + LocalPostProcessingService keep running via
//   the orchestrator without any UI surface. When we wire model choice, mirror
//   TranscriptionProviderRegistry with a PostProcessingProviderRegistry.

struct CloudLLMSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Palette.muted)
                Text("Cloud LLM post-processing")
                    .font(Typography.sans(13, .semibold))
                    .foregroundStyle(Palette.ink)
            }
            Text("Coming soon. Cleanup currently runs with built-in defaults.")
                .font(Typography.sans(11))
                .foregroundStyle(Palette.muted)
        }
    }
}
