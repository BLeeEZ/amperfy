import XCTest
@testable import Amperfy

class AlbumParserTest: AbstractAmpacheTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "albums")
        recreateParserDelegate()
        createTestArtists()
    }
    
    override func recreateParserDelegate() {
        parserDelegate = AlbumParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
    }
    
    func createTestArtists() {
        var artist = library.createArtist()
        artist.id = "19"
        artist.name = "Various Artists"
        
        artist = library.createArtist()
        artist.id = "91"
        artist.name = "ZZZasdf"
    }
    
    override func checkCorrectParsing() {
        let albums = library.getAlbums().sorted(by: {$0.id < $1.id} )
        XCTAssertEqual(albums.count, 3)
        XCTAssertEqual(library.genreCount, 2)
        
        var album = albums[0]
        XCTAssertEqual(album.id, "12")
        XCTAssertEqual(album.name, "Buried in Nausea")
        XCTAssertEqual(album.artist?.id, "19")
        XCTAssertEqual(album.artist?.name, "Various Artists")
        XCTAssertEqual(album.year, 2012)
        XCTAssertEqual(album.songCount, 9)
        XCTAssertEqual(album.genre?.id, "7")
        XCTAssertEqual(album.genre?.name, "Punk")
        XCTAssertEqual(album.artwork?.url, "https://music.com.au/image.php?object_id=12&object_type=album&auth=eeb9f1b6056246a7d563f479f518bb34")
        
        album = albums[1]
        XCTAssertEqual(album.id, "98")
        XCTAssertEqual(album.name, "Blibb uu")
        XCTAssertEqual(album.artist?.id, "12") // Artist not pre created
        XCTAssertEqual(album.artist?.name, "9958A")
        XCTAssertEqual(album.year, 1974)
        XCTAssertEqual(album.songCount, 1)
        XCTAssertNil(album.genre)
        XCTAssertEqual(album.artwork?.url, "https://music.com.au/image.php?object_id=98&object_type=album&auth=eeb9f1b6056246a7d563f479f518bb34")
        
        album = albums[2]
        XCTAssertEqual(album.id, "99")
        XCTAssertEqual(album.name, "123 GOo")
        XCTAssertEqual(album.artist?.id, "91")
        XCTAssertEqual(album.artist?.name, "ZZZasdf")
        XCTAssertEqual(album.year, 2002)
        XCTAssertEqual(album.songCount, 105)
        XCTAssertEqual(album.genre?.id, "1")
        XCTAssertEqual(album.genre?.name, "Blub")
        XCTAssertEqual(album.artwork?.url, "https://music.com.au/image.php?object_id=99&object_type=album&auth=eeb9f1b6056246a7d563f479f518bb34")
    }

}
