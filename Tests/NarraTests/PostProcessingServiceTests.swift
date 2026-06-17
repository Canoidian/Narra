import XCTest
@testable import NarraV2

private let t0 = Date(timeIntervalSince1970: 0)
private let t2 = Date(timeIntervalSince1970: 2)
private let t4 = Date(timeIntervalSince1970: 4)

final class PostProcessingServiceTests: XCTestCase {
    func testLocalPostProcessingServiceUsesLocalFilter() async throws {
        let service = LocalPostProcessingService()
        let previous = TranscriptSegment(text: "Set a timer for ten minutes", startTime: t0, endTime: t2)
        let current = TranscriptSegment(text: "No wait, set a timer for twenty minutes", startTime: t2, endTime: t4)

        let result = try await service.process(segment: current)

        XCTAssertEqual(result.text, "set a timer for twenty minutes")
    }

    func testGrokPostProcessingServiceThrowsMissingAPIKeyWhenNoKeyConfigured() async throws {
        let service = GrokPostProcessingService(apiKey: "")
        let segment = TranscriptSegment(text: "um, I need a timer", startTime: t0, endTime: t2)

        do {
            _ = try await service.process(segment: segment)
            XCTFail("Expected missingAPIKey error")
        } catch PostProcessingError.missingAPIKey {
            // expected
        }
    }
}
