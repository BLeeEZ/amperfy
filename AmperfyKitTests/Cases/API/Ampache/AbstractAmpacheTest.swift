import XCTest
@testable import AmperfyKit

class AbstractAmpacheTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var xmlData: Data?
    var xmlErrorData: Data!
    var syncWave: SyncWave!
    var parserDelegate: AmpacheXmlParser?

    override func setUp() {
        cdHelper = CoreDataHelper()
        let context = cdHelper.createInMemoryManagedObjectContext()
        cdHelper.clearContext(context: context)
        library = LibraryStorage(context: context)
        xmlErrorData = getTestFileData(name: "error-4700")
        syncWave = library.createSyncWave()
    }

    override func tearDown() {
    }
    
    func testErrorParsing() {
        guard let parserDelegate = parserDelegate else {
            if Self.typeName != "AbstractAmpacheTest" { XCTFail() }
            return
        }
        let parser = XMLParser(data: xmlErrorData)
        parser.delegate = parserDelegate
        parser.parse()

        guard let error = parserDelegate.error else { XCTFail(); return }
        XCTAssertEqual(error.statusCode, 4700)
        XCTAssertEqual(error.message, "Access Denied")
    }

    func testParsing() {
        guard let data = xmlData, let parserDelegate = parserDelegate else {
            if Self.typeName != "AbstractAmpacheTest" { XCTFail() }
            return
        }
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        parser.parse()
        XCTAssertNil(parserDelegate.error)
        checkCorrectParsing()
    }
    
    func testParsingTwice() {
        guard let data = xmlData else {
            if Self.typeName != "AbstractAmpacheTest" { XCTFail() }
            return
        }
        syncWave = library.createSyncWave() // set isInitialWave to false
        let parser1 = XMLParser(data: data)
        parser1.delegate = parserDelegate
        parser1.parse()
        checkCorrectParsing()
        
        recreateParserDelegate()
        let parser2 = XMLParser(data: data)
        parser2.delegate = parserDelegate
        parser2.parse()
        checkCorrectParsing()
    }
    
    // Override in concrete test class if needed
    func recreateParserDelegate() {
    
    }
    
    // Override in concrete test class
    func checkCorrectParsing() {
        XCTFail()
    }

}
