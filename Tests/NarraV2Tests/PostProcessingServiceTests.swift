import XCTest
@testable import NarraV2

final class PostProcessingServiceTests: XCTestCase {
    func testLocalPostProcessingServiceUsesLocalFilter() async throws {
        let service = LocalPostProcessingService()
        let previous = TranscriptSegment(text: "Set a timer for ten minutes", startTime: 0, endTime: 2)
        let current = TranscriptSegment(text: "No wait, set a timer for twenty minutes", startTime: 2, endTime: 4)

        let result = try await service.process(
            PostProcessingRequest(
                rawText: current.text,
                segment: current,
                context: [previous]
            )
        )

        XCTAssertEqual(result.refinedText, "set a timer for twenty minutes")
        XCTAssertEqual(result.segments.map(\.text), ["set a timer for twenty minutes"])
    }

    func testGrokPostProcessingServiceFallsBackWhenRefinementThrows() async throws {
        let service = GrokPostProcessingService(timeout: .seconds(1)) { _, _ in
            struct RefinementError: Error {}
            throw RefinementError()
        }
        let request = PostProcessingRequest(
            rawText: "um, I need a timer",
            segment: TranscriptSegment(text: "um, I need a timer", startTime: 0, endTime: 2)
        )

        let result = try await service.process(request)

        XCTAssertEqual(result.refinedText, "I need a timer")
        XCTAssertEqual(result.segments.map(\.text), ["I need a timer"])
    }

    func testGrokPostProcessingServiceUsesRefinementOutput() async throws {
        let service = GrokPostProcessingService(timeout: .seconds(1)) { _, localResult in
            return localResult.refinedText.uppercased()
        }
        let request = PostProcessingRequest(
            rawText: "um, I need a timer",
            segment: TranscriptSegment(text: "um, I need a timer", startTime: 0, endTime: 2)
        )

        let result = try await service.process(request)

        XCTAssertEqual(result.refinedText, "I NEED A TIMER")
        XCTAssertEqual(result.segments.map(\.text), ["I NEED A TIMER"])
    }
}
