import XCTest

public func XCTAssertThrowsError<T, U : Equatable>(
    _ expression: @autoclosure () throws -> T,
    error: U
) {
    XCTAssertThrowsError(expression) { e in
        XCTAssertEqual(e as? U, error)
    }
}

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        return [
            testCase(ChannelTests.allTests),
            testCase(CoroutineTests.allTests),
            testCase(TimeTests.allTests),
        ]
    }
#endif