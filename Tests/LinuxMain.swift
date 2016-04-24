#if os(Linux)

import XCTest
@testable import VeniceTestSuite

XCTMain([
    testCase(VeniceTests.allTests)
])

#endif
