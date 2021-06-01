import XCTest
@testable import Amperfy

class GenreParserTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var xmlData: Data!
    var ampacheUrlCreator: MOCK_AmpacheUrlCreator!
    var syncWave: SyncWave!

    override func setUp() {
        cdHelper = CoreDataHelper()
        let context = cdHelper.createInMemoryManagedObjectContext()
        cdHelper.clearContext(context: context)
        library = LibraryStorage(context: context)
        xmlData = getTestFileData(name: "genres")
        ampacheUrlCreator = MOCK_AmpacheUrlCreator()
        syncWave = library.createSyncWave()
    }

    override func tearDown() {
    }
    
    func testParsing() {
        let parserDelegate = GenreParserDelegate(libraryStorage: library, syncWave: syncWave, parseNotifier: nil)
        let parser = XMLParser(data: xmlData)
        parser.delegate = parserDelegate
        parser.parse()
        XCTAssertNil(parserDelegate.error)
        checkCorrectParsing()
    }
    
    func testParsingTwice() {
        syncWave = library.createSyncWave() // set isInitialWave to false
        let parserDelegate1 = GenreParserDelegate(libraryStorage: library, syncWave: syncWave, parseNotifier: nil)
        let parser1 = XMLParser(data: xmlData)
        parser1.delegate = parserDelegate1
        parser1.parse()
        checkCorrectParsing()
        
        let parserDelegate2 = GenreParserDelegate(libraryStorage: library, syncWave: syncWave, parseNotifier: nil)
        let parser2 = XMLParser(data: xmlData)
        parser2.delegate = parserDelegate2
        parser2.parse()
        checkCorrectParsing()
    }
    
    func checkCorrectParsing() {
        XCTAssertEqual(library.genreCount, 2)
        
        guard let genre = library.getGenre(id: "6") else { XCTFail(); return }
        XCTAssertEqual(genre.id, "6")
        XCTAssertEqual(genre.name, "Dance")
        
        guard let genre = library.getGenre(id: "4") else { XCTFail(); return }
        XCTAssertEqual(genre.id, "4")
        XCTAssertEqual(genre.name, "Dark Ambient")
    }

}
