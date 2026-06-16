import Foundation

public protocol PostProcessingService: Sendable {
    func process(_ request: PostProcessingRequest) async throws -> PostProcessingResult
}

public struct PostProcessingRequest: Equatable, Sendable {
    public var rawText: String
    public var segment: TranscriptSegment?
    public var context: [TranscriptSegment]

    public init(
        rawText: String,
        segment: TranscriptSegment? = nil,
        context: [TranscriptSegment] = []
    ) {
        self.rawText = rawText
        self.segment = segment
        self.context = context
    }
}

public struct PostProcessingResult: Equatable, Sendable {
    public var refinedText: String
    public var segments: [TranscriptSegment]

    public init(refinedText: String, segments: [TranscriptSegment] = []) {
        self.refinedText = refinedText
        self.segments = segments
    }
}
