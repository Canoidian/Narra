import SwiftUI

// MARK: - Liquid Glass Background

/// A translucent, frosted material background that simulates liquid glass
/// using ultra-thin material, subtle blur, and refractive border highlights.
struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            // Base frosted material
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)

            // Subtle colour tint for depth
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.12),
                            .white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 8)

            // Light-refraction border highlight
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.50),
                            .white.opacity(0.10),
                            .white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Liquid Glass Container

/// A generic container that wraps content in the liquid-glass background.
struct LiquidGlassView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(LiquidGlassBackground())
    }
}
