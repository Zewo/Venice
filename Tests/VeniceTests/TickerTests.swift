import XCTest
@testable import Venice

class TickerTests : XCTestCase {
    func testTicker() {
        let ticker = Ticker(period: 10.milliseconds)
        co {
            for _ in ticker.channel {}
        }
        nap(for: 100.milliseconds)
        ticker.stop()
        nap(for: 20.milliseconds)
    }

	func testTickerResolution() {
		let ticker = Ticker(period: 10.milliseconds)
		co {
			var last: UInt64 = 0
			for time in ticker.channel {
				XCTAssertTrue(time - last >= UInt64(0))
				last = time
			}
		}
		nap(for: 100.milliseconds)
		ticker.stop()
		nap(for: 20.milliseconds)
	}
}

extension TickerTests {
    static var allTests : [(String, (TickerTests) -> () throws -> Void)] {
        return [
            ("testTicker", testTicker),
        ]
    }
}
