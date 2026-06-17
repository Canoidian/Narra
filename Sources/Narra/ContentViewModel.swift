import Foundation
import AVFoundation
import AppKit
import CoreGraphics

@MainActor
final class ContentViewModel: ObservableObject {

    enum UIMode: Equatable {
        case hidden, home, recording, processing, reviewing
    }

    private enum CaptureMode { case pushToTalk, toggle }

    @Published var uiMode: UIMode = .hidden
    @Published var transcriptText = ""
    @Published var lastTranscript = ""
    @Published var statusText = "Ready"
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 40)
    @Published var errorMessage: String?
    @Published var pipelineText: String = ""

    var isRecording: Bool { uiMode == .recording }

    private var currentMode: CaptureMode = .pushToTalk
    private let orchestrator = AppServices.shared.orchestrator
    private let captureManager = AudioCaptureManager()
    private var captureTask: Task<Void, Never>?
    /// Drains the live `chunkStream` through Whisper while recording so
    /// transcription overlaps with speech. Result is the partial segments
    /// collected up to stop time.
    private var streamingTask: Task<[TranscriptSegment], Error>?
    /// Set true as soon as the capture loop sees a level above the speech
    /// threshold. Used to drop empty takes on release.
    private var heardSpeech: Bool = false

    // MARK: - Hotkey entry points

    func startPushToTalk() {
        // Re-pressing the trigger key while a recording is in flight
        // cancels and discards it.
        if uiMode == .recording || uiMode == .processing {
            cancelRecording()
            return
        }
        currentMode = .pushToTalk
        startRecording()
    }

    func stopPushToTalk() {
        guard uiMode == .recording else { return }
        if !heardSpeech {
            cancelRecording()
            return
        }
        finishRecording(autoPaste: true)
    }

    func handleToggleHotkey() {
        switch uiMode {
        case .recording:
            // Second tap stops the take. Drop it if it was silent;
            // otherwise hand off to review.
            if !heardSpeech {
                cancelRecording()
            } else {
                finishRecording(autoPaste: false)
            }
        case .processing:
            cancelRecording()
        case .hidden, .home:
            currentMode = .toggle
            startRecording()
        case .reviewing:
            break
        }
    }

    // MARK: - UI actions

    func showHome() {
        if uiMode == .recording || uiMode == .processing { return }
        uiMode = .home
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideHome() {
        if uiMode == .home { uiMode = .hidden }
        NSApp.setActivationPolicy(.accessory)
    }

    func acceptReview() {
        guard uiMode == .reviewing else { return }
        let text = transcriptText
        uiMode = .hidden
        Task { await Self.pasteToFrontmostApp(text: text) }
    }

    func cancelReview() {
        guard uiMode == .reviewing else { return }
        transcriptText = ""
        uiMode = .hidden
    }

    func pasteLastTranscription() {
        guard !lastTranscript.isEmpty else { return }
        let text = lastTranscript
        Task { await Self.pasteToFrontmostApp(text: text) }
    }

    // MARK: - Recording lifecycle

    private func startRecording() {
        guard uiMode != .recording, uiMode != .processing else { return }
        uiMode = .recording
        statusText = "Recording"
        errorMessage = nil
        heardSpeech = false
        if AppSettings.shared.muteOutputWhenRecording {
            SystemOutput.muteForRecording()
        }
        // Wire the streaming consumer BEFORE start() so the tap's first
        // samples have somewhere to go.
        let chunkStream = captureManager.chunkStream()
        let segmentStream = orchestrator.transcribeStream(chunkStream)
        streamingTask = Task {
            var collected: [TranscriptSegment] = []
            for try await segment in segmentStream {
                collected.append(segment)
            }
            return collected
        }
        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.captureManager.start()
            } catch {
                self.errorMessage = error.localizedDescription
                self.uiMode = .hidden
                self.statusText = "Ready"
                return
            }
            // ponytail: 0.05 RMS clears typical room/fan noise (~0.01-0.03)
            // and trips on normal indoor speech (~0.08+). Flag is read on
            // release (`stopPushToTalk` / `handleToggleHotkey`) to drop
            // empty takes.
            let silenceThreshold: Float = 0.05
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                let level = self.captureManager.lastLevel
                if level > silenceThreshold { self.heardSpeech = true }
                self.audioLevels.removeFirst()
                self.audioLevels.append(min(1.0, level * 3))
            }
        }
    }

    /// Aborts the active recording (or in-flight processing) and returns to
    /// the idle state. Drops any captured audio and restores muted output.
    private func cancelRecording() {
        captureTask?.cancel()
        captureTask = nil
        _ = captureManager.stop()
        streamingTask?.cancel()
        streamingTask = nil
        SystemOutput.restore()
        audioLevels = Array(repeating: 0, count: 40)
        statusText = "Ready"
        uiMode = .hidden
    }

    private func finishRecording(autoPaste: Bool) {
        captureTask?.cancel()
        captureTask = nil
        uiMode = .processing
        statusText = "Transcribing..."
        audioLevels = Array(repeating: 0, count: 40)
        SystemOutput.restore()

        let pendingStream = streamingTask
        streamingTask = nil
        Task {
            // Stops the engine and finishes the chunk stream (tail emitted
            // through it). The returned chunk is unused while streaming —
            // the rolling buffer overlaps with already-emitted windows.
            _ = captureManager.stop()
            do {
                let level = AppSettings.shared.cleanupLevel
                let segments = (try await pendingStream?.value) ?? []
                let combinedText = segments
                    .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                if combinedText.isEmpty {
                    statusText = "Ready"
                    uiMode = .hidden
                    return
                }
                let start = segments.first?.startTime ?? Date()
                let end = segments.last?.endTime ?? start
                let conf = segments.map { $0.confidence }.min() ?? 1.0
                let segment = TranscriptSegment(
                    text: combinedText,
                    startTime: start,
                    endTime: end,
                    confidence: conf
                )
                // Short utterances (1-2 words) don't need an LLM cleanup
                // pass — there's nothing to condense or de-filler. Skip
                // the round-trip and paste raw Whisper output.
                let wordCount = combinedText.split(whereSeparator: { $0.isWhitespace }).count
                let processed: ProcessedTranscript
                if wordCount <= 2 {
                    processed = ProcessedTranscript(
                        text: combinedText,
                        startTime: start,
                        endTime: end,
                        confidence: conf,
                        usedCloud: false
                    )
                } else {
                    processed = try await orchestrator.processWithFallback(segment, level: level)
                }
                transcriptText = processed.text
                lastTranscript = processed.text
                pipelineText = "Whisper (local) · \(processed.usedCloud ? "Groq" : "Local cleanup")"
                statusText = "Ready"
                if autoPaste {
                    uiMode = .hidden
                    await Self.pasteToFrontmostApp(text: processed.text)
                } else {
                    uiMode = .reviewing
                }
            } catch {
                errorMessage = error.localizedDescription
                statusText = "Ready"
                uiMode = .hidden
            }
        }
    }

    // MARK: - Paste helper

    /// Pastes `text` into the frontmost app via synthetic Cmd+V, then restores
    /// whatever was on the clipboard before. Needs Accessibility permission
    /// for the keystroke; the clipboard half always succeeds so the user can
    /// paste manually if the keystroke is blocked.
    private static func pasteToFrontmostApp(text: String) async {
        let pb = NSPasteboard.general
        // Snapshot existing items so we can put them back.
        let saved: [NSPasteboardItem] = (pb.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }

        pb.clearContents()
        pb.setString(text, forType: .string)

        // Give the OS time to retire our key window and restore the
        // previous frontmost app, so Cmd+V lands in the right process.
        // ponytail: 80ms covers normal cases on macOS 14+; bump back to
        // 200ms if users report mis-targeted pastes.
        try? await Task.sleep(nanoseconds: 80_000_000)
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // Restore the user's prior clipboard. uiMode is already .hidden at
        // this point so this delay does not affect perceived speed.
        // ponytail: 300ms covers fast targets; raise if restore lands
        // before the destination app finishes reading the pasteboard.
        try? await Task.sleep(nanoseconds: 300_000_000)
        pb.clearContents()
        if !saved.isEmpty {
            pb.writeObjects(saved)
        }
    }
}

// MARK: - System output muting

/// Mutes the system default output via `osascript`. ponytail: Core Audio's
/// per-device volume property is unsupported on AirPods / many BT outputs;
/// `set volume output muted` is the one path that works on every device
/// because AppleScript's StandardAdditions routes through the same control
/// the menu-bar volume icon uses.
@MainActor
private enum SystemOutput {
    private static var didMute = false

    static func muteForRecording() {
        guard !didMute else { return }
        run("set volume output muted true")
        didMute = true
    }

    static func restore() {
        guard didMute else { return }
        run("set volume output muted false")
        didMute = false
    }

    private static func run(_ script: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        try? p.run()
    }
}
