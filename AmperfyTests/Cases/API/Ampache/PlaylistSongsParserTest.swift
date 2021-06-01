import XCTest
@testable import Amperfy

class PlaylistSongsParserTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var xmlData: Data!
    var ampacheUrlCreator: MOCK_AmpacheUrlCreator!
    var syncWave: SyncWave!
    var playlist: Playlist!

    override func setUp() {
        cdHelper = CoreDataHelper()
        let context = cdHelper.createInMemoryManagedObjectContext()
        cdHelper.clearContext(context: context)
        library = LibraryStorage(context: context)
        xmlData = getTestFileData(name: "playlist_songs")
        ampacheUrlCreator = MOCK_AmpacheUrlCreator()
        syncWave = library.createSyncWave()
        playlist = library.createPlaylist()
        createTestArtists()
        createTestAlbums()
    }

    override func tearDown() {
    }
    
    func createTestArtists() {
        var artist = library.createArtist()
        artist.id = "27"
        artist.name = "Chi.Otic"
        
        artist = library.createArtist()
        artist.id = "20"
        artist.name = "R/B"
        
        artist = library.createArtist()
        artist.id = "14"
        artist.name = "Nofi/found."
        
        artist = library.createArtist()
        artist.id = "2"
        artist.name = "Synthetic"
    }
    
    func createTestAlbums() {
        var album = library.createAlbum()
        album.id = "12"
        album.name = "Buried in Nausea"
        
        album = library.createAlbum()
        album.id = "2"
        album.name = "Colorsmoke EP"
    }
    
    func testParsing() {
        let parserDelegate = PlaylistSongsParserDelegate(playlist: playlist, libraryStorage: library, syncWave: syncWave)
        let parser = XMLParser(data: xmlData)
        parser.delegate = parserDelegate
        parser.parse()
        XCTAssertNil(parserDelegate.error)
        checkCorrectParsing()
    }
    
    func testParsingTwice() {
        syncWave = library.createSyncWave() // set isInitialWave to false
        let parserDelegate1 = PlaylistSongsParserDelegate(playlist: playlist, libraryStorage: library, syncWave: syncWave)
        let parser1 = XMLParser(data: xmlData)
        parser1.delegate = parserDelegate1
        parser1.parse()
        checkCorrectParsing()
        
        let parserDelegate2 = PlaylistSongsParserDelegate(playlist: playlist, libraryStorage: library, syncWave: syncWave)
        let parser2 = XMLParser(data: xmlData)
        parser2.delegate = parserDelegate2
        parser2.parse()
        checkCorrectParsing()
    }
    
    func checkCorrectParsing() {
        SongParserTest.checkCorrectParsing(library: library)
        
        XCTAssertEqual(playlist.songCount, 4)
        XCTAssertEqual(playlist.songs[0].id, "56")
        XCTAssertEqual(playlist.songs[1].id, "107")
        XCTAssertEqual(playlist.songs[2].id, "115")
        XCTAssertEqual(playlist.songs[3].id, "85")
    }

}
