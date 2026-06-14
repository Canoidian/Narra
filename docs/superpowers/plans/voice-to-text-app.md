# NarraV2 — Voice-to-Text App Plan

## Context

Build a native macOS voice-to-text app with an emphasis on intelligent post-processing. The app must gracefully handle self-corrections ("No, wait, I mean..."), restatements, and filler words. It should feature a "liquid glass" UI aesthetic. The primary transcription and processing engine is the Grok API, with a fully offline local LLM fallback for both STT and post-processing.

## Architecture

Native macOS App (Swift + SwiftUI)
- **Frontend:** SwiftUI with a liquid-glass visual theme.
- **Audio:** AVFoundation / AVAudioEngine for real-time microphone capture and buffering.
- **STT Engine:** Grok API (streaming) as primary; local whisper.cpp (Swift bindings) as fallback.
- **LLM Engine:** Grok API for post-processing; local model via MLX Swift as fallback.

## Milestones

### Task 1: Project & UI Skeleton (1-2 files)

- Initialize a new macOS App project in Xcode.
- Implement the base "Liquid Glass" UI:
  - Translucent, frosted material background using VisualEffect or custom Glass view.
  - Subtle blur, depth, and light refraction effects.
  - Floating, borderless window.
- Create the main transcription display, status indicators, and a settings panel.

**Key files:**
- `ContentView.swift`
- `LiquidGlassView.swift`
- `NarraV2App.swift`

**Acceptance criteria:**
- [ ] App compiles and launches as a macOS app
- [ ] Window shows liquid-glass visual effect
- [ ] Transcription display area is visible
- [ ] Status indicator shows "Ready" or similar
- [ ] Settings panel is accessible

---

### Task 2: Audio Capture & Buffering

- Set up `AVAudioEngine` to capture microphone input.
- Implement a rolling audio buffer to manage continuous streams.
- Design a `TranscriptionService` protocol to abstract audio chunking and STT calls.

**Key files:**
- `AudioCaptureManager.swift`
- `TranscriptionService.swift`
- `NarraV2.swift` (protocol update)

**Acceptance criteria:**
- [ ] App captures live microphone audio
- [ ] Rolling buffer stores last N seconds of audio correctly
- [ ] `TranscriptionService` protocol is defined with clear interface
- [ ] No memory leaks during prolonged capture

---

### Task 3: Integrate Grok API (Primary STT & LLM)

- Implement `GrokTranscriptionService` sending audio chunks to Grok's STT endpoint.
- Implement `GrokPostProcessingService` to clean up raw text.
- Prompt engineering to detect self-corrections, restatements, and filler words.
- Streaming the corrected text back to the UI.

**Key files:**
- `GrokTranscriptionService.swift`
- `GrokPostProcessingService.swift`
- `PostProcessingService.swift`

**Acceptance criteria:**
- [ ] Audio chunks are sent to Grok API and transcription is received
- [ ] Post-processed text handles self-corrections gracefully
- [ ] Streaming corrected text updates UI in real time
- [ ] Error handling for API failures (rate limits, timeouts, etc.)

---

### Task 4: Local STT & LLM Fallbacks

- **STT:** Integrate whisper.cpp (via Swift bindings) as `LocalTranscriptionService`.
  - Bundle a lightweight Whisper model (e.g., tiny or base) for fast local fallback.
- **LLM:** Integrate MLX Swift for local post-processing.
  - Bundle a lightweight model (e.g., Phi-3 Mini or a small Mistral variant).
  - Implement `LocalPostProcessingService` that mimics the Grok prompt logic locally.

**Key files:**
- `LocalTranscriptionService.swift`
- `LocalPostProcessingService.swift`

**Acceptance criteria:**
- [ ] Local Whisper runs STT offline without network
- [ ] Local LLM post-processes text with quality comparable to Grok for simple cases
- [ ] Fallback switching happens automatically based on connectivity
- [ ] Both fallbacks can be tested in isolation

---

### Task 5: Smart Post-Processing Logic

- **Buffer Management:** Maintain a transcript buffer of the last N seconds.
- **Correction Detection:** Identify patterns like "No, wait...", "Actually...", "I mean..." to overwrite previous segments.
- **Restatement Handling:** If the user says the same thing differently, merge or select the most coherent version.
- **Filler Removal:** Strip "um", "uh", "like", "you know" based on confidence and context.
- Implement as a pipeline: Raw STT → Local regex/pattern filter → LLM refinement → UI.

**Key files:**
- `PostProcessingService.swift`
- `GrokPostProcessingService.swift`
- `LocalPostProcessingService.swift`

**Acceptance criteria:**
- [ ] Self-correction phrases are detected and corrected in output
- [ ] Filler words are removed or marked
- [ ] Restatements are merged or deduplicated
- [ ] Pipeline executes end-to-end within acceptable latency

---

### Task 6: Polish & Build

- Add accessibility labels and keyboard shortcuts.
- Optimize memory/CPU usage for continuous background listening.
- Test Grok vs. Local fallback switching based on connectivity or user preference.
- Finalize app packaging and notarization prep.

**Key files:**
- `Accessibility.swift` (or integrated into existing views)
- `KeyboardShortcuts.swift`
- Build / archive configuration

**Acceptance criteria:**
- [ ] Keyboard shortcuts work (e.g., `⌘+Shift+R` to start/stop recording)
- [ ] Accessibility labels pass VoiceOver inspection
- [ ] Memory/CPU usage remains stable during long sessions
- [ ] App can be archived / notarized with no errors

## Verification

- Run the app locally, speak common self-correction phrases, and verify the Grok/Local LLM rewrites the output correctly.
- Verify that turning off network connectivity seamlessly triggers the local Whisper and MLX models without crashing.
