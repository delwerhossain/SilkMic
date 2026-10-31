import XCTest
@testable import VoiceCore

final class DeepFilterNetDSPTests: XCTestCase {
    func testReadinessIsInitiallyFalseForFreshDSP() {
        let dsp = DeepFilterNetDSP()
        XCTAssertFalse(dsp.isReady)
    }
}
