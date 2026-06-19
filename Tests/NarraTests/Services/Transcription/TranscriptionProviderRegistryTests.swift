import XCTest
@testable import Narra

final class TranscriptionProviderRegistryTests: XCTestCase {
    func testWiredAndStubbedProviderStatuses() {
        let byID = Dictionary(
            uniqueKeysWithValues: TranscriptionProviderRegistry.all.map { ($0.id, $0) }
        )

        for id in ProviderID.allCases {
            XCTAssertNotNil(byID[id], "Registry missing entry for \(id.rawValue)")
        }

        XCTAssertEqual(byID[.groq]?.status, .wired)
        XCTAssertEqual(byID[.whisperKit]?.status, .wired)

        for id in [ProviderID.openAI, .whisperCpp, .parakeet] {
            XCTAssertEqual(byID[id]?.status, .stubbed, "\(id.rawValue) should be stubbed")
        }
    }
}
