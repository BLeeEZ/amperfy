import XCTest
@testable import Amperfy

class MOCK_AmpacheUrlCreator: AmpacheUrlCreationable {
    func getArtUrlString(forArtistId: String) -> String {
        return forArtistId
    }
}

class ArtistParserTest: XCTestCase {
    
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
        xmlData = getTestFileData(name: "artists")
        ampacheUrlCreator = MOCK_AmpacheUrlCreator()
        syncWave = library.createSyncWave()
    }

    override func tearDown() {
    }
    
    func testParsing() {
        let parserDelegate = ArtistParserDelegate(libraryStorage: library, syncWave: syncWave, ampacheUrlCreator: ampacheUrlCreator, parseNotifier: nil)
        let parser = XMLParser(data: xmlData)
        parser.delegate = parserDelegate
        parser.parse()
        XCTAssertNil(parserDelegate.error)
        checkCorrectParsing()
    }
    
    func testParsingTwice() {
        syncWave = library.createSyncWave() // set isInitialWave to false
        let parserDelegate1 = ArtistParserDelegate(libraryStorage: library, syncWave: syncWave, ampacheUrlCreator: ampacheUrlCreator, parseNotifier: nil)
        let parser1 = XMLParser(data: xmlData)
        parser1.delegate = parserDelegate1
        parser1.parse()
        checkCorrectParsing()
        
        let parserDelegate2 = ArtistParserDelegate(libraryStorage: library, syncWave: syncWave, ampacheUrlCreator: ampacheUrlCreator, parseNotifier: nil)
        let parser2 = XMLParser(data: xmlData)
        parser2.delegate = parserDelegate2
        parser2.parse()
        checkCorrectParsing()
    }
    
    func checkCorrectParsing() {
        let artists = library.getArtists()
        XCTAssertEqual(artists.count, 4)
        XCTAssertEqual(library.genreCount, 1)
        
        var artist = artists[0]
        XCTAssertEqual(artist.id, "16")
        XCTAssertEqual(artist.name, "CARNÚN")
        XCTAssertEqual(artist.albumCount, 1)
        XCTAssertEqual(artist.artwork?.url, artist.id)
        
        artist = artists[1]
        XCTAssertEqual(artist.id, "27")
        XCTAssertEqual(artist.name, "Chi.Otic")
        XCTAssertEqual(artist.albumCount, 0)
        XCTAssertEqual(artist.artwork?.url, artist.id)
        
        artist = artists[3]
        XCTAssertEqual(artist.id, "13")
        XCTAssertEqual(artist.name, "IOK-1")
        XCTAssertEqual(artist.albumCount, 1)
        XCTAssertEqual(artist.artwork?.url, artist.id)
        XCTAssertEqual(artist.genre?.id, "4")
        XCTAssertEqual(artist.genre?.name, "Dark Ambient")
    }

}
