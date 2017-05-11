import XCTest
import Venice

public class TimeTests : XCTestCase {
    func testTime() throws {
        XCTAssertEqual(1.millisecond, 1.millisecond)
        XCTAssertEqual(1000.millisecond, 1.second)
        XCTAssertEqual(60000.millisecond, 1.minute)
        XCTAssertEqual(3600000.millisecond, 1.hour)
    }
}

extension TimeTests {
    public static var allTests: [(String, (TimeTests) -> () throws -> Void)] {
        return [
            ("testTime", testTime),
        ]
    }
}
