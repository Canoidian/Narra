import SwiftUI

// MARK: - Glass Card
//
// Flat sibling of `GlassBead` for non-HUD surfaces (home panel, settings tabs,
// section cards). Same dark-glass language, but rectangular and without the
// dramatic caustic/refraction layers that only make sense on a capsule.

struct GlassCard<Content: View>: View {
    var padding: CGFloat = Spacing.xxl
    var radius: CGFloat = CornerRadius.xl
    var selected: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            base
            if #unavailable(macOS 26.0) {
                // Pre-26 polyfill — native Liquid Glass already supplies sheen + edge.
                topSheen
                border
            }
            content().padding(padding)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(selected ? Color.white.opacity(0.55) : Color.clear, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var base: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.black.opacity(0.20))
        }
    }

    private var topSheen: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}

/// Backwards-compatible alias from the editorial-light era.
typealias EditorialCard = GlassCard

// MARK: - Editorial section header

struct EditorialSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Typography.sans(11, .semibold))
            .tracking(0.8)
            .foregroundStyle(Palette.muted)
    }
}

// MARK: - Pastel chip

struct PastelTag: View {
    let text: String
    let bg: Color
    let fg: Color
    var body: some View {
        Text(text.uppercased())
            .font(Typography.sans(10, .semibold))
            .tracking(0.6)
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(bg))
    }
}
