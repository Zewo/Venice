import XCTest
@testable import Venice

public class TickerTests : XCTestCase {
    func testTicker() {
        let ticker = Ticker(period: 10.milliseconds)
        co {
            var last: Double = 0
            for time in ticker.channel {
                XCTAssertTrue(time - last >= Double(0))
                last = time
            }
        }
        nap(for: 100.milliseconds)
        ticker.stop()
        nap(for: 20.milliseconds)
    }
}

extension TickerTests {
    public static var allTests: [(String, (TickerTests) -> () throws -> Void)] {
        return [
            ("testTicker", testTicker),
        ]
    }
}
