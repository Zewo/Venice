import XCTest

public func XCTAssertThrowsError<T, U : Equatable>(
    _ expression: @autoclosure () throws -> T,
    error: U
) {
    XCTAssertThrowsError(expression) { e in
        XCTAssertEqual(e as? U, error)
    }
}
