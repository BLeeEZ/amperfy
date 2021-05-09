import XCTest
@testable import Amperfy

class UtilitiesTest: XCTestCase {

    func testInt16Valid() {
        XCTAssertTrue(Int16.isValid(value: Int(Int16.max)))
        XCTAssertTrue(Int16.isValid(value: Int(Int16.min)))
        XCTAssertTrue(Int16.isValid(value: Int(0)))
        XCTAssertTrue(Int16.isValid(value: Int(Int16.min)+1))
        XCTAssertTrue(Int16.isValid(value: Int(Int16.max)-1))
    }

    func testInt16Invalid() {
        XCTAssertFalse(Int16.isValid(value: Int(Int16.max)+1))
        XCTAssertFalse(Int16.isValid(value: Int(Int16.min)-1))
        XCTAssertFalse(Int16.isValid(value: Int(Int32.min)))
        XCTAssertFalse(Int16.isValid(value: Int(Int32.max)))
    }
    
    func testInt32Valid() {
        XCTAssertTrue(Int32.isValid(value: Int(Int32.max)))
        XCTAssertTrue(Int32.isValid(value: Int(Int32.min)))
        XCTAssertTrue(Int32.isValid(value: Int(0)))
        XCTAssertTrue(Int32.isValid(value: Int(Int32.min+1)))
        XCTAssertTrue(Int32.isValid(value: Int(Int32.max-1)))
    }

    func testInt32Invalid() {
        XCTAssertFalse(Int32.isValid(value: Int(Int32.max)+1))
        XCTAssertFalse(Int32.isValid(value: Int(Int32.min)-1))
        XCTAssertFalse(Int32.isValid(value: Int(Int64.min)))
        XCTAssertFalse(Int32.isValid(value: Int(Int64.max)))
    }

}
