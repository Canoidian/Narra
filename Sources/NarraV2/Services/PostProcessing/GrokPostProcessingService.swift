import Foundation

public struct GrokPostProcessingPayload: Equatable, Sendable {
    public var systemPrompt: String
    public var userPrompt: String
    public var rawText: String
    public var localFilteredText: String
    public var contextText: String
    public var confidence: Double?
    public var segment: TranscriptSegment?

    public init(
        systemPrompt: String,
        userPrompt: String,
        rawText: String,
        localFilteredText: String,
        contextText: String,
        confidence: Double?,
        segment: TranscriptSegment?
    ) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.rawText = rawText
        self.localFilteredText = localFilteredText
        self.contextText = contextText
        self.confidence = confidence
        self.segment = segment
    }
}

public struct GrokPostProcessingService: PostProcessingService {
    public typealias Refinement = @Sendable (_ payload: GrokPostProcessingPayload, _ localResult: PostProcessingResult) async throws -> String

    private let localFilter: LocalCorrectionFilter
    private let timeout: Duration
    private let refinement: Refinement

    public init(
        localFilter: LocalCorrectionFilter = LocalCorrectionFilter(),
        timeout: Duration = .seconds(2),
        refinement: @escaping Refinement
    ) {
        self.localFilter = localFilter
        self.timeout = timeout
        self.refinement = refinement
    }

    public func process(_ request: PostProcessingRequest) async throws -> PostProcessingResult {
        let localResult = localFilter.apply(request)
        let payload = Self.makePayload(request: request, localResult: localResult)

        guard let refinedText = await runWithTimeout(timeout: timeout, operation: { try await refinement(payload, localResult) }) else {
            return localResult
        }

        return Self.replacingResult(localResult, with: refinedText, request: request)
    }

    private static func makePayload(request: PostProcessingRequest, localResult: PostProcessingResult) -> GrokPostProcessingPayload {
        GrokPostProcessingPayload(
            systemPrompt: "Clean up the transcript while preserving meaning and correcting fillers, restatements, and self-corrections.",
            userPrompt: localResult.refinedText,
            rawText: request.rawText,
            localFilteredText: localResult.refinedText,
            contextText: request.context.map(\.text).joined(separator: " "),
            confidence: request.segment?.confidence,
            segment: request.segment
        )
    }

    private static func replacingResult(
        _ localResult: PostProcessingResult,
        with refinedText: String,
        request: PostProcessingRequest
    ) -> PostProcessingResult {
        var segments = localResult.segments

        if let lastIndex = segments.indices.last {
            var lastSegment = segments[lastIndex]
            lastSegment.text = refinedText
            segments[lastIndex] = lastSegment
        } else if let segment = request.segment {
            segments = [
                TranscriptSegment(
                    id: segment.id,
                    text: refinedText,
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    confidence: segment.confidence
                )
            ]
        }

        return PostProcessingResult(refinedText: refinedText, segments: segments)
    }
}
