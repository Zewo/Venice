import XCTest
import Venice

public class TimeTests : XCTestCase {
    func testTime() throws {
        XCTAssertEqual(1.millisecond, 1.milliseconds)
        XCTAssertEqual(1000.millisecond, 1.seconds)
        XCTAssertEqual(60000.millisecond, 1.minutes)
        XCTAssertEqual(3600000.millisecond, 1.hours)
    }
}

extension TimeTests {
    public static var allTests: [(String, (TimeTests) -> () throws -> Void)] {
        return [
            ("testTime", testTime),
        ]
    }
}
