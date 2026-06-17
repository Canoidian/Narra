#!/usr/bin/env swift
// Renders the procedural app icon to a 1024x1024 PNG.
// Usage: swift tools/render_icon.swift
// Output: Sources/Narra/Resources/AppIcon.png

import SwiftUI
import AppKit

struct IconView: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            let r = s * 0.225
            ZStack {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(Color(red: 0.078, green: 0.075, blue: 0.060))
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(RadialGradient(colors: [Color.white.opacity(0.04), .clear],
                                         center: .center, startRadius: 0, endRadius: s * 0.55))
                ZStack {
                    Capsule(style: .continuous).fill(Color.white.opacity(0.08))
                    Capsule(style: .continuous)
                        .fill(RadialGradient(colors: [Color.white.opacity(0.30), .clear],
                                             center: .bottom, startRadius: 0, endRadius: s * 0.18))
                        .blendMode(.plusLighter)
                    Ellipse()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.80), Color.white.opacity(0.10)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: s * 0.48, height: s * 0.10)
                        .offset(y: -s * 0.075)
                        .blendMode(.plusLighter)
                        .mask(Capsule(style: .continuous))
                    WaveformMark()
                        .stroke(Color.white.opacity(0.88),
                                style: StrokeStyle(lineWidth: s * 0.018, lineCap: .round, lineJoin: .round))
                        .frame(width: s * 0.42, height: s * 0.12)
                        .shadow(color: Color.white.opacity(0.4), radius: s * 0.015)
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: s * 0.0035)
                }
                .frame(width: s * 0.64, height: s * 0.32)
                .shadow(color: .black.opacity(0.5), radius: s * 0.04, y: s * 0.015)
            }
        }
    }
}

struct WaveformMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height, mid = rect.midY
        let bars: [CGFloat] = [0.30, 0.55, 0.85, 1.00, 0.85, 0.55, 0.30]
        let gap = w / CGFloat(bars.count * 2 - 1)
        for (i, mag) in bars.enumerated() {
            let x = rect.minX + CGFloat(i * 2) * gap + gap / 2
            let half = mag * h * 0.5
            p.move(to: CGPoint(x: x, y: mid - half))
            p.addLine(to: CGPoint(x: x, y: mid + half))
        }
        return p
    }
}

@MainActor
func render() {
    let size: CGFloat = 1024
    let renderer = ImageRenderer(content: IconView().frame(width: size, height: size))
    renderer.scale = 1
    guard let cg = renderer.cgImage else { fputs("render failed\n", stderr); exit(1) }
    let rep = NSBitmapImageRep(cgImage: cg)
    rep.size = NSSize(width: size, height: size)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("png encode failed\n", stderr); exit(1)
    }
    let url = URL(fileURLWithPath: "Sources/Narra/Resources/AppIcon.png")
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    try! data.write(to: url)
    print("wrote \(url.path)")
}

DispatchQueue.main.async { render(); exit(0) }
RunLoop.main.run()
