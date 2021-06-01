import XCTest
@testable import Amperfy

class SsXmlParserTest: XCTestCase {
    
    var xmlData: Data!

    override func setUp() {
        xmlData = getTestFileData(name: "error_example_1")
    }

    override func tearDown() {
    }
    
    func testParsing() {
        let parserDelegate = SsPingParserDelegate()
        let parser = XMLParser(data: xmlData)
        parser.delegate = parserDelegate
        parser.parse()

        guard let error = parserDelegate.error else { XCTFail(); return }
        XCTAssertEqual(error.statusCode, 40)
        XCTAssertEqual(error.message, "Wrong username or password")
    }

}
