import XCTest
@testable import AmperfyKit

class ErrorParserTest: XCTestCase {
    
    var xmlData: Data!

    override func setUp() {
        xmlData = getTestFileData(name: "error-4700")
    }
    
    func testParsing() {
        let parserDelegate = AmpacheXmlParser()
        let parser = XMLParser(data: xmlData)
        parser.delegate = parserDelegate
        parser.parse()

        guard let error = parserDelegate.error else { XCTFail(); return }
        XCTAssertEqual(error.statusCode, 4700)
        XCTAssertEqual(error.message, "Access Denied")
    }

}
