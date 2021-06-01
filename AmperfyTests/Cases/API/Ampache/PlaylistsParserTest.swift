import XCTest
@testable import Amperfy

class PlaylistsParserTest: XCTestCase {
    
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
        xmlData = getTestFileData(name: "playlists")
        ampacheUrlCreator = MOCK_AmpacheUrlCreator()
        syncWave = library.createSyncWave()
    }

    override func tearDown() {
    }
    
    func testParsing() {
        let parserDelegate = PlaylistParserDelegate(libraryStorage: library, parseNotifier: nil)
        let parser = XMLParser(data: xmlData)
        parser.delegate = parserDelegate
        parser.parse()
        XCTAssertNil(parserDelegate.error)
        checkCorrectParsing()
    }
    
    func testParsingTwice() {
        syncWave = library.createSyncWave() // set isInitialWave to false
        let parserDelegate1 = PlaylistParserDelegate(libraryStorage: library, parseNotifier: nil)
        let parser1 = XMLParser(data: xmlData)
        parser1.delegate = parserDelegate1
        parser1.parse()
        checkCorrectParsing()
        
        let parserDelegate2 = PlaylistParserDelegate(libraryStorage: library, parseNotifier: nil)
        let parser2 = XMLParser(data: xmlData)
        parser2.delegate = parserDelegate2
        parser2.parse()
        checkCorrectParsing()
    }
    
    func checkCorrectParsing() {
        let playlists = library.getPlaylists()
        XCTAssertEqual(playlists.count, 4)
        
        var playlist = playlists[0]
        XCTAssertEqual(playlist.id, "smart_21")
        XCTAssertEqual(playlist.name, "admin - 02/23/2021 14:36:44")
        XCTAssertEqual(playlist.songCount, 5000)
        
        playlist = playlists[1]
        XCTAssertEqual(playlist.id, "smart_14")
        XCTAssertEqual(playlist.name, "Album 1*")
        XCTAssertEqual(playlist.songCount, 2)
        
        playlist = playlists[2]
        XCTAssertEqual(playlist.id, "3")
        XCTAssertEqual(playlist.name, "random - admin - private")
        XCTAssertEqual(playlist.songCount, 43)
        
        playlist = playlists[3]
        XCTAssertEqual(playlist.id, "2")
        XCTAssertEqual(playlist.name, "random - admin - public")
        XCTAssertEqual(playlist.songCount, 43)
    }

}
