import XCTest
@testable import VeniceTests

XCTMain([
    testCase(ChannelTests.allTests),
    testCase(CoroutineTests.allTests),
    testCase(TimeTests.allTests),
])
