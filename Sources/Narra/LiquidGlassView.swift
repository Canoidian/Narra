import SwiftUI

// MARK: - Liquid Glass Background

/// Full-window background using native macOS 26 glass on supported systems,
/// falling back to a frosted material simulation on earlier versions.
struct LiquidGlassBackground: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Rectangle()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 8)
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.50), .white.opacity(0.10), .white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        }
    }
}

// MARK: - Liquid Glass Container

/// Wraps content in a native glass surface (macOS 26+) or material fallback.
struct LiquidGlassView<Content: View>: View {
    private let content: Content
    private let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            content
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                )
        }
    }
}
