import XCTest
@testable import Amperfy

class SongParserTest: XCTestCase {
    
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
        xmlData = getTestFileData(name: "songs")
        ampacheUrlCreator = MOCK_AmpacheUrlCreator()
        syncWave = library.createSyncWave()
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
        let parserDelegate = SongParserDelegate(libraryStorage: library, syncWave: syncWave, parseNotifier: nil)
        let parser = XMLParser(data: xmlData)
        parser.delegate = parserDelegate
        parser.parse()
        XCTAssertNil(parserDelegate.error)
        Self.checkCorrectParsing(library: library)
    }
    
    func testParsingTwice() {
        syncWave = library.createSyncWave() // set isInitialWave to false
        let parserDelegate1 = SongParserDelegate(libraryStorage: library, syncWave: syncWave, parseNotifier: nil)
        let parser1 = XMLParser(data: xmlData)
        parser1.delegate = parserDelegate1
        parser1.parse()
        Self.checkCorrectParsing(library: library)
        
        let parserDelegate2 = SongParserDelegate(libraryStorage: library, syncWave: syncWave, parseNotifier: nil)
        let parser2 = XMLParser(data: xmlData)
        parser2.delegate = parserDelegate2
        parser2.parse()
        Self.checkCorrectParsing(library: library)
    }
    
    static func checkCorrectParsing(library: LibraryStorage) {
        let songs = library.getSongs()
        XCTAssertEqual(songs.count, 4)
        XCTAssertEqual(library.genreCount, 4)
        
        var song = songs[0]
        XCTAssertEqual(song.id, "115")
        XCTAssertEqual(song.title, "Are we going Crazy")
        XCTAssertEqual(song.artist?.id, "27")
        XCTAssertEqual(song.artist?.name, "Chi.Otic")
        XCTAssertEqual(song.album?.id, "12")
        XCTAssertEqual(song.album?.name, "Buried in Nausea")
        XCTAssertEqual(song.disk, "1")
        XCTAssertEqual(song.track, 7)
        XCTAssertNil(song.genre)
        XCTAssertEqual(song.duration, 433)
        XCTAssertEqual(song.year, 2012)
        XCTAssertEqual(song.bitrate, 32582)
        XCTAssertEqual(song.contentType, "audio/x-ms-wma")
        XCTAssertEqual(song.url, "https://music.com.au/play/index.php?ssid=cfj3f237d563f479f5223k23189dbb34&type=song&oid=115&uid=4&player=api&name=Chi.Otic%20-%20Are%20we%20going%20Crazy.wma")
        XCTAssertEqual(song.size, 1776580)
        XCTAssertEqual(song.artwork?.url, "")
        
        song = songs[1]
        XCTAssertEqual(song.id, "107")
        XCTAssertEqual(song.title, "Arrest Me")
        XCTAssertEqual(song.artist?.id, "20")
        XCTAssertEqual(song.artist?.name, "R/B")
        XCTAssertEqual(song.album?.id, "12")
        XCTAssertEqual(song.album?.name, "Buried in Nausea")
        XCTAssertEqual(song.disk, "1")
        XCTAssertEqual(song.track, 9)
        XCTAssertEqual(song.genre?.id, "7")
        XCTAssertEqual(song.genre?.name, "Punk")
        XCTAssertEqual(song.duration, 96)
        XCTAssertEqual(song.year, 2012)
        XCTAssertEqual(song.bitrate, 252864)
        XCTAssertEqual(song.contentType, "audio/mp4")
        XCTAssertEqual(song.url, "https://music.com.au/play/index.php?ssid=cfj3f237d563f479f5223k23189dbb34&type=song&oid=107&uid=4&player=api&name=R-B%20-%20Arrest%20Me.m4a")
        XCTAssertEqual(song.size, 3091727)
        XCTAssertEqual(song.artwork?.url, "")
        
        song = songs[2]
        XCTAssertEqual(song.id, "85")
        XCTAssertEqual(song.title, "Beq Ultra Fat")
        XCTAssertEqual(song.artist?.id, "14")
        XCTAssertEqual(song.artist?.name, "Nofi/found.")
        XCTAssertNil(song.album)
        XCTAssertEqual(song.disk, "1")
        XCTAssertEqual(song.track, 4)
        XCTAssertEqual(song.genre?.id, "6")
        XCTAssertEqual(song.genre?.name, "Dance")
        XCTAssertEqual(song.duration, 413)
        XCTAssertEqual(song.year, 0)
        XCTAssertEqual(song.bitrate, 192000)
        XCTAssertEqual(song.contentType, "audio/mpeg")
        XCTAssertEqual(song.url, "https://music.com.au/play/index.php?ssid=cfj3f237d563f479f5223k23189dbb34&type=song&oid=85&uid=4&player=api&name=Nofi-found.%20-%20Beq%20Ultra%20Fat.mp3")
        XCTAssertEqual(song.size, 9935896)
        XCTAssertEqual(song.artwork?.url, "https://music.com.au/image.php?object_id=8&object_type=album&auth=eeb9f1b6056246a7d563f479f518bb34&name=art.jpg")
        
        song = songs[3]
        XCTAssertEqual(song.id, "56")
        XCTAssertEqual(song.title, "Black&BlueSmoke")
        XCTAssertEqual(song.artist?.id, "2")
        XCTAssertEqual(song.artist?.name, "Synthetic")
        XCTAssertEqual(song.album?.id, "2")
        XCTAssertEqual(song.album?.name, "Colorsmoke EP")
        XCTAssertEqual(song.disk, "1")
        XCTAssertEqual(song.track, 1)
        XCTAssertEqual(song.genre?.id, "1")
        XCTAssertEqual(song.genre?.name, "Electronic")
        XCTAssertEqual(song.duration, 500)
        XCTAssertEqual(song.year, 2007)
        XCTAssertEqual(song.bitrate, 64000)
        XCTAssertEqual(song.contentType, "audio/mpeg")
        XCTAssertEqual(song.url, "https://music.com.au/play/index.php?ssid=cfj3f237d563f479f5223k23189dbb34&type=song&oid=56&uid=4&player=api&name=Synthetic%20-%20Black-BlueSmoke.mp3")
        XCTAssertEqual(song.size, 4010069)
        XCTAssertEqual(song.artwork?.url, "")
    }

}
