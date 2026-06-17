# Narra fix plan — settings, keychain, transcription preload, pill, glass

## Context

After the recent refactor that moved Narra into `.accessory` mode and replaced
the main window with a menu-bar pill, the app has regressed on several user-
visible fronts. Working through them:

- `SettingsLink { … }` does nothing because in `.accessory` mode the Settings
  scene needs `NSApp.activate(...)` plus `@Environment(\.openSettings)`. The
  menu bar has no Settings entry at all.
- An "Allow Always" keychain prompt appears every launch because
  `ServiceOrchestrator.init` calls `GrokAPIKeySource.resolve()` → `KeychainService.load()`
  before the user has done anything.
- Local transcription downloads ~145 MB on first call with zero UI feedback,
  so users think the app is hung.
- The pill is bottom-clipped: the 52pt content frame plus `glassEffect`'s
  outer shadow falls below the visible window frame.
- The Home transcript box and the (still-to-be-created) Settings cards use
  `.quaternary` / stroked rectangles instead of the existing
  `LiquidGlassView` helper.
- `ContentViewModel.pipelineText` is declared but never written, so the user
  has no idea whether Grok or local cleanup ran.

**Precondition (preflight phase below):** the current source references
`CleanupLevel`, `AppSettings`, `KeybindingManager`, and `SettingsView` but
none of them exist in the checkout — `swift build` currently fails. They
must be created before any of the fixes below compile.

## Shape of the change

```
                        ┌─────────────────────────┐
                        │     AppServices         │  ← new singleton
                        │  (orchestrator +        │     replaces per-VM
                        │   engineState)          │     instance
                        └────────┬────────────────┘
                                 │
       ┌──────────────┬──────────┼──────────────┬───────────────┐
       ▼              ▼          ▼              ▼               ▼
 AppDelegate    MenuBarContent  ContentView  ContentVM    SettingsView
 ┌────────────┐ ┌─────────────┐ ┌─────────┐  ┌────────┐   ┌──────────┐
 │ preload()  │ │ Engine: …   │ │ Home/   │  │ record │   │ Grok key │
 │ on launch  │ │ Settings…   │ │ pill    │  │ flow   │   │ + status │
 │            │ │ Mic submenu │ │ glass   │  │ writes │   │ glass    │
 └────────────┘ └─────────────┘ └─────────┘  │ pipe-  │   │ cleanup  │
                                             │ lineTxt│   │ cards    │
                                             └────────┘   └──────────┘
                                 │
                                 ▼
                  ┌─────────────────────────────┐
                  │ TranscriptionEngineState    │  ← new ObservableObject
                  │ isReady / isLoading / error │     observed by AppDelegate,
                  └─────────────────────────────┘     menu bar, home, pill
                                 ▲
                                 │ writes
                  ┌──────────────┴──────────────┐
                  │ LocalTranscriptionService   │
                  │ + preload() async throws    │
                  └─────────────────────────────┘

  Keychain is only touched inside GrokPostProcessingService.process(...).
  GrokAPIKeySource.resolve() is no longer called at launch.
```

## Phase 0 — Preflight (create the missing types so it compiles)

These are tiny skeletons; the fixes below build on them. Keep them deliberately
minimal — no extra behaviour, no extra files.

### `Sources/NarraV2/Services/PostProcessing/CleanupLevel.swift` (new)
```swift
public enum CleanupLevel: String, Sendable, CaseIterable, Codable {
    case none, light, medium, high
}
```
Referenced by `GrokPostProcessingService` (level switch on lines 145–176 of
the existing file), `ServiceOrchestrator.processWithFallback`, and
`ContentViewModel.finishRecording`.

### `Sources/NarraV2/AppSettings.swift` (new)
`ObservableObject` singleton backed by `UserDefaults`:
- `static let shared = AppSettings()`
- `@Published var cleanupLevel: CleanupLevel` (default `.medium`)
- `@Published var orchestratorMode: ServiceOrchestrator.Mode` (default `.automatic`)
- `var grokAPIKeyStatus: Bool { GrokAPIKeySource.resolve() != nil }` (read-only convenience for the Settings status row — see step 8). This is the **only** caller of `resolve()` that runs outside of an actual transcription, and it is gated behind user action (opening Settings), so it does not fire at launch.
- Persists each `@Published` write to `UserDefaults.standard` via a small `didSet`.

### `Sources/NarraV2/KeybindingManager.swift` (new)
Wrap the global fn-key listener referenced by `ContentView.task` (lines 26–30):
- `static let shared = KeybindingManager()`
- `var onPushToTalkStart, onPushToTalkStop, onPushToToggle: (() -> Void)?`
- `var hasInputMonitoringAccess: Bool { IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted }`
- `func start()`: install a `CGEvent` tap on `.flagsChanged` / `.keyDown`; detect `NX_DEVICELCMDKEYMASK` for fn-down/up (drives `onPushToTalkStart/Stop`) and fn+space (drives `onPushToToggle`).

### `Sources/NarraV2/SettingsView.swift` (new)
Three-tab `TabView`, each in a `Form`:
- **General** — picker for `AppSettings.shared.orchestratorMode`; `SecureField` for the Grok API key bound to a local `@State` that calls `KeychainService.save(key:)` on submit; status row reading `AppSettings.shared.grokAPIKeyStatus` ("Connected ✓" / "Not Set").
- **Cleanup** — `ForEach(CleanupLevel.allCases)` rendering a card per level with title + one-line description; selection writes `AppSettings.shared.cleanupLevel`.
- **About** — version, license, link to repo.
- Frame `.frame(width: 480, height: 360)` so it sizes correctly under
  `Settings { … }`.

## Phase 1 — Fixes

### 1. Defer the keychain read (no more launch prompt)

**`Services/KeychainService.swift`** — add `kSecAttrAccessible:
kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to the `addQuery` dictionary in
`save(key:)` (between lines 20–22). No other changes needed; `load()` does
not require the flag. The existing `SecItemDelete` on lines 9–14 already
handles re-keying older items.

**`Services/PostProcessing/GrokPostProcessingService.swift`** — stop
resolving the key in `init` (line 50 — `apiKey ?? GrokAPIKeySource.resolve() ?? ""`).
Make the stored property optional (`private let injectedKey: String?`) and add:

```swift
private func currentAPIKey() -> String {
    injectedKey ?? GrokAPIKeySource.resolve() ?? ""
}
```

Use `currentAPIKey()` in the empty-check on line 68 and in
`makeRequest(apiKey:…)` on line 78. This pushes the keychain hit to first
`process(...)` call — i.e. only when the user has actually recorded.

**`Services/Orchestrator/ServiceOrchestrator.swift`** — drop the
`apiKey: configuration.apiKey` argument from the `GrokPostProcessingService`
init on line 62 so the orchestrator no longer threads a key it doesn't have.
`Configuration.apiKey` becomes effectively unused; leave the field for
backward compatibility but stop reading it.

### 2. Preload WhisperKit + surface engine readiness

**`Services/Transcription/TranscriptionEngineState.swift`** (new) —
`@MainActor final class TranscriptionEngineState: ObservableObject` with
`@Published var isReady`, `@Published var isLoading`, `@Published var
lastError: String?`. Plain value object, no logic.

**`Services/Transcription/LocalTranscriptionService.swift`** — add:

```swift
public weak var engineState: TranscriptionEngineState?

public func preload() async throws {
    _ = try await loadWhisperKit()
}
```

Update `loadWhisperKit()` (lines 110–121) to write `isLoading = true` at
entry, `isReady = true; isLoading = false` on success, and
`lastError = String(describing: error); isLoading = false` on failure (hop
to `MainActor` for the writes). Calls from any thread are safe because the
state object is `@MainActor`.

### 3. Shared services singleton

**`Services/AppServices.swift`** (new) — `@MainActor final class AppServices`
with `static let shared`, holds `let orchestrator: ServiceOrchestrator` and
`let engineState = TranscriptionEngineState()`. Wires them together in
`init` (`orchestrator.localTranscriber.engineState = engineState`).

**`ContentViewModel.swift`** — replace
`private let orchestrator = ServiceOrchestrator()` on line 26 with
`private let orchestrator = AppServices.shared.orchestrator`. In
`finishRecording` (lines 111–139), after `processed` is assigned, write:

```swift
pipelineText = "Whisper (local) · \(processed.usedCloud ? \"Grok\" : \"Local cleanup\")"
```

Add `usedCloud: Bool = false` to `ProcessedTranscript` (in
`PostProcessingService.swift`) and set it `true` only when Grok returns
successfully — i.e. in `GrokPostProcessingService.process(segments:level:)`
just before the `return ProcessedTranscript(...)` (line 89).

### 4. Launch preload

**`NarraV2App.swift`** — in `AppDelegate.applicationDidFinishLaunching`
(after the existing IO/AX requests), kick off:

```swift
Task { @MainActor in
    try? await AppServices.shared.orchestrator.localTranscriber.preload()
}
```

Reference `AppServices.shared` once so the singleton is created eagerly
(and its monitor starts running).

### 5. Menu bar + Settings entry

**`NarraV2App.swift` `MenuBarContent`** (lines 47–94):

- Add `@ObservedObject private var engineState = AppServices.shared.engineState` and
  `@Environment(\.openSettings) private var openSettings`.
- Top row (disabled): `Text(engineState.isReady ? "Engine: Ready" : (engineState.isLoading ? "Engine: Loading…" : "Engine: Not loaded"))`.
- Replace each `Button("…")` with `Button { … } label: { Label("…", systemImage: "…") }` (`house` / `doc.on.clipboard` / `mic` / `gearshape` / `power`).
- Group with `Divider()`s: `[engine status]`, `[Home, Paste Last]`, `[Microphone submenu]`, `[Settings, Quit]`.
- New Settings item — single button (not `SettingsLink`, which won't activate in `.accessory` mode):

```swift
Button {
    NSApp.activate(ignoringOtherApps: true)
    openSettings()
} label: {
    Label("Settings…", systemImage: "gearshape")
}
.keyboardShortcut(",")
```

**`MenuBarExtra` label** (lines 32–37) — replace the static `Image` with a
view that swaps in a `ProgressView().controlSize(.mini)` while
`engineState.isLoading`:

```swift
} label: {
    if engineState.isLoading { ProgressView().controlSize(.mini) }
    else { Image(systemName: "waveform").symbolRenderingMode(.hierarchical) }
}
```

Promote `engineState` to a top-level `@StateObject` in `NarraV2App` so the
label closure observes it (the `MenuBarContent` body is recomputed but the
label closure is on the scene).

### 6. Pill window — borderless, not clipped

Two coordinated edits:

**`NarraV2App.swift`** — keep `WindowGroup`, but the pill clipping is caused
by the SwiftUI window's content inset under `.hiddenTitleBar`. Change the
window style to `.plain` (macOS 13+ borderless window without inset) and
remove the `defaultSize` so the content frame drives the window frame:

```swift
WindowGroup { ContentView() }
    .windowStyle(.plain)
    .windowResizability(.contentSize)
```

**`ContentView.swift` `pillContainer`** (lines 172–184) — reduce
`.padding(.vertical, 10)` to `.padding(.vertical, 6)` and grow the frame to
`width: 296, height: 56` so the `Capsule().glassEffect(...)` shadow has 4 pt
of headroom inside the window. Mirror the new 56 pt height in
`WindowBehavior` (lines 231–235): `let w: CGFloat = 296, h: CGFloat = 56`.

`WindowBehavior` already sets `isOpaque = false`, `backgroundColor = .clear`,
`hasShadow = false` — keep them. With `.windowStyle(.plain)` the OS no
longer reserves a titlebar area, so the pill renders fully.

### 7. Pipeline label inside the pill + glass on Home

**`ContentView.swift` `processingPill`** (lines 60–68) — after the
"Transcribing…" `Text`, append:

```swift
if !viewModel.pipelineText.isEmpty {
    Text(viewModel.pipelineText)
        .font(.caption2)
        .foregroundStyle(.secondary)
}
```

**`ContentView.swift` `homeBody`** (lines 123–138) — replace the
`.background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))` with the
existing helper from `LiquidGlassView.swift`:

```swift
LiquidGlassView(cornerRadius: 12) {
    VStack(alignment: .leading, spacing: 8) {
        Text("Last transcription")...
        ScrollView { ... }.frame(maxHeight: 140)
    }
}
```

(Wrap the existing inner VStack with `LiquidGlassView`; drop the explicit
`.padding(12)` since `LiquidGlassView` adds its own.)

Keep `SettingsLink { … }` on lines 148–150 (it works inside a regular
window scene; it only fails from the menu bar).

### 8. SettingsView cleanup cards use glass

In the Cleanup tab of the new `SettingsView`, render each `CleanupLevel`
card with `LiquidGlassView(cornerRadius: 12)` and overlay a `RoundedRectangle`
stroke in `.tint` when the level is selected. Same helper as Home — single
visual language across the app.

## Intentionally out of scope

- Grok transcription. xAI still returns 404 for `audio/transcriptions`.
  `ServiceOrchestrator.transcribeWithFallback` stays local-only; the
  comment on lines 94–96 remains accurate.
- The MLX local LLM pipeline. `LocalPostProcessingService.runMLX` is still
  a TODO; the regex-only fallback path on lines 85–92 keeps working.
- Test updates. Existing tests target service-level behaviour; none touch
  the new `AppServices` singleton or UI files. Add a tiny test only if the
  `usedCloud` flag changes Grok response parsing semantics — it doesn't.

## Verification

End-to-end, in order, all from `/home/user/repo`:

1. **Build:** `swift build`. Must produce a clean build (preflight types
   should resolve every current `error: cannot find … in scope`).
2. **Launch:** `swift run` (or open `.build/debug/NarraV2`).
   - Console: no keychain prompt appears at launch.
   - Menu bar: `waveform` icon appears, switches to a spinner while the
     WhisperKit model downloads. Click → menu shows `Engine: Loading…` at
     the top.
   - Wait until `Engine: Ready` appears.
3. **Settings reachable:** Menu bar → `Settings…`. The Settings window
   activates and comes forward. Enter Grok key on the General tab; status
   row flips to "Connected ✓". OS shows one standard "Narra wants to save
   item to Keychain" prompt — not the scary "Allow Always" cross-app
   variant.
4. **Pill not clipped:** Hold fn. Pill appears centred at bottom of screen,
   no bottom clipping, no halo. Stop button readable.
5. **Push-to-talk:** Hold fn, speak a short sentence, release.
   - Pill switches to processing; small caption shows
     `Whisper (local) · Grok` (if key set) or `Whisper (local) · Local cleanup`.
   - Pill disappears; cleaned text auto-pastes into the focused field.
6. **fn+Space toggle:** Press fn+Space, speak, press fn+Space again. Pill
   enters review mode. ✓ pastes; ✗ discards.
7. **Home glass:** Menu bar → Home. Window centred, glass background. "Last
   transcription" panel uses `LiquidGlassView`, not flat quaternary. Paste
   Last works.
8. **Microphone submenu:** Change selection; record again. macOS Sound
   preferences input meter responds on the new device.
9. **Glass surfaces:** Visual check — pill, Home transcript box, Settings
   cleanup cards all use the macOS 26 glass material (or the
   `.ultraThinMaterial` fallback on pre-26 OSes).

If any step fails, return to the corresponding section above.
