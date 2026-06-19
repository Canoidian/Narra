import SwiftUI

// MARK: - TranscriptionSection
//
// Provider + model picker for the transcription pipeline. Reads the static
// `TranscriptionProviderRegistry`, persists choice via `AppSettings`, and
// hands the resulting (id, model) tuple to the orchestrator.
//
// Stubbed providers are listed but disabled — they have a registry entry
// for forward UX continuity, but selecting them would route to a service
// that doesn't exist yet.

struct TranscriptionSection: View {
    @ObservedObject private var settings = AppSettings.shared

    @State private var apiKeyDraft: String = ""
    @State private var keyJustSaved: Bool = false

    private var allProviders: [TranscriptionProvider] {
        TranscriptionProviderRegistry.all
    }

    private var selectedProvider: TranscriptionProvider {
        TranscriptionProviderRegistry.provider(settings.selectedProviderID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            providerBlock
            modelBlock
            if selectedProvider.requiresAPIKey {
                apiKeyBlock
            }
        }
        .onAppear { reloadAPIKeyDraft() }
        .onChange(of: settings.selectedProviderID) { _, _ in
            reloadAPIKeyDraft()
            normalizeModelForCurrentProvider()
            pushOrchestratorUpdate()
        }
        .onChange(of: settings.selectedModelID) { _, _ in
            pushOrchestratorUpdate()
        }
    }

    // MARK: - Provider

    private var providerBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EditorialSectionLabel(text: "Provider")
            VStack(spacing: Spacing.xs) {
                ForEach(allProviders) { provider in
                    providerRow(provider)
                }
            }
            HStack(spacing: Spacing.sm) {
                PastelTag(
                    text: selectedProvider.kind == .cloud ? "Cloud" : "Local",
                    bg: selectedProvider.kind == .cloud ? Palette.blueBg : Palette.greenBg,
                    fg: selectedProvider.kind == .cloud ? Palette.blueInk : Palette.greenInk
                )
                Text(selectedProvider.displayName)
                    .font(Typography.sans(11))
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    private func providerRow(_ provider: TranscriptionProvider) -> some View {
        let isSelected = provider.id == settings.selectedProviderID
        let isStubbed = provider.status == .stubbed
        return Button {
            guard !isStubbed else { return }
            settings.selectedProviderID = provider.id
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? Palette.ink : Palette.muted)
                Text(provider.displayName)
                    .font(Typography.sans(12, .medium))
                    .foregroundStyle(isStubbed ? Palette.muted : Palette.ink)
                if isStubbed {
                    Text("(Coming soon)")
                        .font(Typography.sans(11))
                        .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Text(provider.kind == .cloud ? "Cloud" : "Local")
                    .font(Typography.mono(10))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .opacity(isStubbed ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isStubbed)
    }

    // MARK: - Model

    private var modelBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EditorialSectionLabel(text: "Model")
            Picker("", selection: $settings.selectedModelID) {
                ForEach(selectedProvider.models) { model in
                    Text(model.displayName).tag(model.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Palette.ink)
        }
    }

    // MARK: - API Key

    private var apiKeyBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EditorialSectionLabel(text: "API Key")
            Text("Stored in macOS Keychain, scoped to \(selectedProvider.displayName).")
                .font(Typography.sans(11))
                .foregroundStyle(Palette.muted)
            SecureField("Paste API key", text: $apiKeyDraft)
                .textFieldStyle(.plain)
                .font(Typography.mono(12))
                .foregroundStyle(Palette.ink)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .onSubmit { saveKey() }

            HStack(spacing: Spacing.sm) {
                Button(action: saveKey) {
                    Label("Save Key", systemImage: "key.fill")
                        .font(Typography.sans(12, .medium))
                        .foregroundStyle(Palette.canvas)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .fill(Palette.ink)
                        )
                }
                .buttonStyle(.plain)
                .disabled(apiKeyDraft.isEmpty)
                .opacity(apiKeyDraft.isEmpty ? 0.4 : 1)

                Button(action: clearKey) {
                    Label("Clear", systemImage: "trash")
                        .font(Typography.sans(12, .medium))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                if keyJustSaved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Saved")
                    }
                    .font(Typography.sans(11, .semibold))
                    .foregroundStyle(Palette.greenInk)
                    .transition(.opacity)
                }
                Spacer()
            }
            .animation(Motion.microFade, value: keyJustSaved)
        }
    }

    // MARK: - Actions

    private func reloadAPIKeyDraft() {
        if selectedProvider.requiresAPIKey {
            apiKeyDraft = KeychainService.load(for: selectedProvider.id) ?? ""
        } else {
            apiKeyDraft = ""
        }
    }

    private func saveKey() {
        guard !apiKeyDraft.isEmpty else { return }
        try? KeychainService.save(key: apiKeyDraft, for: selectedProvider.id)
        keyJustSaved = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { keyJustSaved = false }
        }
    }

    private func clearKey() {
        KeychainService.delete(for: selectedProvider.id)
        apiKeyDraft = ""
        keyJustSaved = false
    }

    // ponytail: if the current model doesn't belong to the new provider,
    // snap to the provider's default. Cheaper than maintaining last-used
    // per provider in settings.
    private func normalizeModelForCurrentProvider() {
        let validIDs = Set(selectedProvider.models.map(\.id))
        if !validIDs.contains(settings.selectedModelID) {
            settings.selectedModelID = selectedProvider.defaultModelID
        }
    }

    private func pushOrchestratorUpdate() {
        AppServices.shared.orchestrator.setProvider(
            settings.selectedProviderID,
            model: settings.selectedModelID
        )
    }
}
