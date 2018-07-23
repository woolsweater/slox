import XCTest
@testable import LoxLib

/** Base class for Lox tests; performs common setup/teardown. */
class LoxTestCase : XCTestCase
{
    override func tearDown()
    {
        Lox.clearError()
        super.tearDown()
    }
}
