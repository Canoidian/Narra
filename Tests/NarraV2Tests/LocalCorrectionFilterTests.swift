import XCTest
@testable import NarraV2

final class LocalCorrectionFilterTests: XCTestCase {
    func testFillerWordsAreRemovedWhenUsedAsStandaloneFillers() {
        let filter = LocalCorrectionFilter()

        let result = filter.apply(
            PostProcessingRequest(
                rawText: "um, I need a timer",
                segment: TranscriptSegment(text: "um, I need a timer", startTime: 0, endTime: 2)
            )
        )

        XCTAssertEqual(result.refinedText, "I need a timer")
        XCTAssertEqual(result.segments.map(\.text), ["I need a timer"])
    }

    func testLikeIsPreservedWhenUsedSemantically() {
        let filter = LocalCorrectionFilter()

        let result = filter.apply(
            PostProcessingRequest(
                rawText: "I like this",
                segment: TranscriptSegment(text: "I like this", startTime: 0, endTime: 2, confidence: 0.98)
            )
        )

        XCTAssertEqual(result.refinedText, "I like this")
        XCTAssertEqual(result.segments.map(\.text), ["I like this"])
    }

    func testIMeanAndRatherTriggerCorrectionPrefixRemoval() {
        let filter = LocalCorrectionFilter()
        let previous = TranscriptSegment(text: "Book lunch for Tuesday", startTime: 0, endTime: 2)

        let iMeanResult = filter.apply(
            PostProcessingRequest(
                rawText: "I mean, book lunch for Wednesday",
                segment: TranscriptSegment(text: "I mean, book lunch for Wednesday", startTime: 2, endTime: 4),
                context: [previous]
            )
        )
        XCTAssertEqual(iMeanResult.refinedText, "book lunch for Wednesday")
        XCTAssertEqual(iMeanResult.segments.map(\.text), ["book lunch for Wednesday"])

        let ratherResult = filter.apply(
            PostProcessingRequest(
                rawText: "Rather, book lunch for Thursday",
                segment: TranscriptSegment(text: "Rather, book lunch for Thursday", startTime: 2, endTime: 4),
                context: [previous]
            )
        )
        XCTAssertEqual(ratherResult.refinedText, "book lunch for Thursday")
        XCTAssertEqual(ratherResult.segments.map(\.text), ["book lunch for Thursday"])
    }

    func testRestatementDedupesNearDuplicateContextToCleanerVersion() {
        let filter = LocalCorrectionFilter()
        let previous = TranscriptSegment(text: "um set a timer for ten minutes", startTime: 0, endTime: 2)
        let current = TranscriptSegment(text: "set a timer for ten minutes", startTime: 2, endTime: 4)

        let result = filter.apply(
            PostProcessingRequest(
                rawText: current.text,
                segment: current,
                context: [previous]
            )
        )

        XCTAssertEqual(result.refinedText, "set a timer for ten minutes")
        XCTAssertEqual(result.segments.map(\.text), ["set a timer for ten minutes"])
    }
}
