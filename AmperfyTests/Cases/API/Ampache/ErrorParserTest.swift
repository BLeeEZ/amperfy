import XCTest
@testable import Amperfy

class ErrorParserTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var xmlData: Data!

    override func setUp() {
        cdHelper = CoreDataHelper()
        let context = cdHelper.createInMemoryManagedObjectContext()
        cdHelper.clearContext(context: context)
        library = LibraryStorage(context: context)
        xmlData = getTestFileData(name: "error-4700")
    }

    override func tearDown() {
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
