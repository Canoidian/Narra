import SwiftUI

// MARK: - Glass Bead
//
// 3D liquid-glass capsule. Heavy refraction edges, glossy top dome, bottom
// caustic glow, chromatic fringe, inner fresnel rim. Width is animatable —
// the HUD pops small and stretches open to reveal its contents.

struct GlassBead<Content: View>: View {
    var width: CGFloat
    var height: CGFloat
    @ViewBuilder var content: () -> Content

    init(width: CGFloat,
         height: CGFloat = 44,
         @ViewBuilder content: @escaping () -> Content) {
        self.width = width
        self.height = height
        self.content = content
    }

    var body: some View {
        ZStack {
            base
            if #unavailable(macOS 26.0) {
                // Pre-26 polyfill: hand-rolled refraction stack approximating native Liquid Glass.
                innerTint
                bottomCaustic
                topDome
                sideRefraction
                chromaticFringe
                fresnelRim
                outerHairline
            }
            content()
                .padding(.horizontal, height * 0.28)
                .frame(width: width, height: height)
                .clipShape(Capsule(style: .continuous))
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.65), radius: 30, x: 0, y: 18)
        .shadow(color: .black.opacity(0.35), radius: 6,  x: 0, y: 2)
        .compositingGroup()
    }

    // MARK: - Layers

    @ViewBuilder
    private var base: some View {
        if #available(macOS 26.0, *) {
            Capsule(style: .continuous)
                .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        } else {
            Capsule(style: .continuous).fill(.ultraThinMaterial)
        }
    }

    /// Very faint dark wash to give the glass a 'body' instead of pure transparency.
    private var innerTint: some View {
        Capsule(style: .continuous)
            .fill(Color.black.opacity(0.08))
            .allowsHitTesting(false)
    }

    /// Soft caustic glow welling up from the bottom — pooled refraction.
    private var bottomCaustic: some View {
        Capsule(style: .continuous)
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.40), Color.white.opacity(0.05), .clear],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: height * 1.4
                )
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    /// Glossy top dome highlight — the wet 'mirror' spot.
    private var topDome: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(1.0), Color.white.opacity(0.30), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: max(0, width * 0.84), height: height * 0.46)
            .offset(y: -height * 0.22)
            .blur(radius: 0.4)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .mask(Capsule(style: .continuous))
    }

    /// Thin specular streaks on the left and right curved ends — refractive 'lensing'.
    private var sideRefraction: some View {
        HStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: height * 0.35, height: height * 0.6)
                .blur(radius: 1.2)
                .blendMode(.plusLighter)
                .padding(.leading, height * 0.12)
            Spacer(minLength: 0)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.55)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: height * 0.35, height: height * 0.6)
                .blur(radius: 1.2)
                .blendMode(.plusLighter)
                .padding(.trailing, height * 0.12)
        }
        .allowsHitTesting(false)
        .mask(Capsule(style: .continuous))
    }

    /// Rainbow chromatic aberration on the rim — refraction artifact.
    private var chromaticFringe: some View {
        Capsule(style: .continuous)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(hex: 0xFF7AB3, opacity: 0.75),
                        Color(hex: 0x7AC8FF, opacity: 0.75),
                        Color(hex: 0xFFFFFF, opacity: 0.20),
                        Color(hex: 0xC8FF7A, opacity: 0.55),
                        Color(hex: 0xFFB07A, opacity: 0.55),
                        Color(hex: 0xFF7AB3, opacity: 0.75)
                    ]),
                    center: .center
                ),
                lineWidth: 1.2
            )
            .blur(radius: 0.6)
            .allowsHitTesting(false)
    }

    /// Bright inner rim — fresnel-style glow that reads as glass thickness.
    private var fresnelRim: some View {
        Capsule(style: .continuous)
            .inset(by: 1.5)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.70), Color.white.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1.2
            )
            .blur(radius: 0.3)
            .allowsHitTesting(false)
    }

    private var outerHairline: some View {
        Capsule(style: .continuous)
            .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            .allowsHitTesting(false)
    }
}

// MARK: - Legacy compatibility shims

struct LiquidGlassView<Content: View>: View {
    private let content: Content
    private let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = CornerRadius.xl, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Palette.border, lineWidth: 1)
            )
    }
}

struct LiquidGlassBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
            .fill(Palette.canvas)
    }
}
