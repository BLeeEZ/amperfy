import XCTest
@testable import AmperfyKit

class SsPingParserTest: XCTestCase {
    
    var xmlData: Data!

    override func setUp() {
        xmlData = getTestFileData(name: "ping_example_1")
    }

    override func tearDown() {
    }
    
    func testParsing() {
        let parserDelegate = SsPingParserDelegate()
        let parser = XMLParser(data: xmlData)
        parser.delegate = parserDelegate
        parser.parse()

        XCTAssertNil(parserDelegate.error)
        XCTAssertTrue(parserDelegate.isAuthValid)
        XCTAssertEqual(parserDelegate.serverApiVersion, "1.1.1")
    }

}
