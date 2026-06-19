import SwiftUI

// MARK: - SettingsRoot
//
// Top-level Settings scene. NavigationSplitView with a flat-slab sidebar on
// the left and a single GlassCard-bound detail pane on the right. The
// sidebar items are intentionally NOT glass — glass-on-glass is forbidden
// by the design system. The detail pane's content surface is the glass.

struct SettingsRoot: View {

    // MARK: - Section

    enum Section: String, CaseIterable, Identifiable, Hashable {
        case transcription
        case cloudLLM
        case hotkeys
        case audio
        case general

        var id: String { rawValue }

        var title: String {
            switch self {
            case .transcription: return "Transcription"
            case .cloudLLM:      return "Cloud LLM"
            case .hotkeys:       return "Hotkeys"
            case .audio:         return "Audio"
            case .general:       return "General"
            }
        }

        var symbol: String {
            switch self {
            case .transcription: return "waveform"
            case .cloudLLM:      return "cloud"
            case .hotkeys:       return "keyboard"
            case .audio:         return "mic"
            case .general:       return "gearshape"
            }
        }
    }

    @State private var selected: Section = .transcription

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(Palette.canvas.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(Section.allCases) { section in
                sidebarRow(section)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .frame(minWidth: 200)
        .background(Palette.canvas)
    }

    private func sidebarRow(_ section: Section) -> some View {
        let isSelected = selected == section
        return Button {
            withAnimation(Motion.snappy) { selected = section }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: section.symbol)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? Palette.ink : Palette.muted)
                    .frame(width: 18)
                Text(section.title)
                    .font(Typography.sans(13, isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Palette.ink : Palette.inkSoft)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.05 : 0.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(
                        Color.white.opacity(isSelected ? 0.12 : 0.0),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(selected.title)
                    .font(Typography.serif(22, .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Spacing.xs)

                GlassCard(padding: Spacing.lg, radius: CornerRadius.xl) {
                    switch selected {
                    case .transcription: TranscriptionSection()
                    case .cloudLLM:      CloudLLMSection()
                    case .hotkeys:       HotkeysSection()
                    case .audio:         AudioSection()
                    case .general:       GeneralSection()
                    }
                }
            }
            .padding(Spacing.xxl)
        }
        .background(Palette.canvas)
    }
}
