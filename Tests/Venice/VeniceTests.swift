import XCTest
@testable import Venice

class VeniceTests: XCTestCase {
    func testReality() {
        XCTAssert(2 + 2 == 4, "Something is severely wrong here.")
    }
}

extension VeniceTests {
    static var allTests : [(String, VeniceTests -> () throws -> Void)] {
        return [
           ("testReality", testReality),
        ]
    }
}
