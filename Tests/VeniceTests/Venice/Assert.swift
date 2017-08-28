import XCTest

public func XCTAssertThrowsError<T, U : Equatable>(_ expression: () throws -> T, error expectedError: U) -> Void {
    do {
        _ = try expression()
    } catch {
        XCTAssertEqual(error as? U, expectedError)
    }
}


public func XCTAssertThrowsNoError<T>(_ expression: () throws -> T) -> Void {
    do {
        _ = try expression()
    } catch {
        XCTFail("Expected no error, caught \(error).")
    }
}
