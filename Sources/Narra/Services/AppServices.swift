import Foundation

@MainActor
final class AppServices {

    static let shared = AppServices()

    let orchestrator: ServiceOrchestrator
    let engineState: TranscriptionEngineState

    private init() {
        let engineState = TranscriptionEngineState()
        // ponytail: mode read once at launch; ServiceOrchestrator.configuration is `let`,
        // so changing Service Mode in Settings takes effect on next launch.
        let mode = AppSettings.shared.orchestratorMode
        let orchestrator = ServiceOrchestrator(configuration: .init(mode: mode))
        orchestrator.localTranscriber.engineState = engineState
        self.engineState = engineState
        self.orchestrator = orchestrator

        // Warm the Groq TLS connection so the first cleanup call doesn't
        // pay handshake + DNS cost. ponytail: fire-and-forget; ignore
        // errors — the real call will still work cold if this fails.
        Task.detached {
            var req = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
            req.httpMethod = "HEAD"
            req.timeoutInterval = 5
            _ = try? await URLSession.shared.data(for: req)
        }
    }
}
