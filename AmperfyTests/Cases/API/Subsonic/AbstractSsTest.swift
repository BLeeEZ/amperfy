import XCTest
import CoreData
@testable import Amperfy

class MOCK_SubsonicUrlCreator: SubsonicUrlCreator {
    func getArtUrlString(forCoverArtId: String) -> String {
        return "www-" + forCoverArtId
    }
}

class AbstractSsParserTest: XCTestCase {
    
    var context: NSManagedObjectContext!
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var xmlData: Data?
    var xmlErrorData: Data!
    var subsonicUrlCreator: MOCK_SubsonicUrlCreator!
    var syncWave: SyncWave!
    var ssParserDelegate: SsXmlParser?

    override func setUp() {
        cdHelper = CoreDataHelper()
        context = cdHelper.createInMemoryManagedObjectContext()
        cdHelper.clearContext(context: context)
        library = LibraryStorage(context: context)
        xmlErrorData = getTestFileData(name: "error_example_1")
        subsonicUrlCreator = MOCK_SubsonicUrlCreator()
        syncWave = library.createSyncWave()
    }

    override func tearDown() {
    }
    
    func testErrorParsing() {
        guard let parserDelegate = ssParserDelegate else {
            if Self.typeName != "AbstractSsParserTest" { XCTFail() }
            return
        }
        let parser = XMLParser(data: xmlErrorData)
        parser.delegate = ssParserDelegate
        parser.parse()

        guard let error = parserDelegate.error else { XCTFail(); return }
        XCTAssertEqual(error.statusCode, 40)
        XCTAssertEqual(error.message, "Wrong username or password")
    }

    func testParsing() {
        guard let data = xmlData, let parserDelegate = ssParserDelegate else {
            if Self.typeName != "AbstractSsParserTest" { XCTFail() }
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
            if Self.typeName != "AbstractSsParserTest" { XCTFail() }
            return
        }
        syncWave = library.createSyncWave() // set isInitialWave to false
        let parser1 = XMLParser(data: data)
        parser1.delegate = ssParserDelegate
        parser1.parse()
        checkCorrectParsing()
        
        recreateParserDelegate()
        let parser2 = XMLParser(data: data)
        parser2.delegate = ssParserDelegate
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
