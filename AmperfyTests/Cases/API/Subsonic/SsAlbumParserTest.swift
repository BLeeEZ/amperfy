import XCTest
@testable import Amperfy

class SsAlbumParserTest: AbstractSsParserTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "artist_example_1")
        ssParserDelegate = SsAlbumParserDelegate(libraryStorage: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator, parseNotifier: nil)
        createTestPartner()
    }
    
    func createTestPartner() {
        let artist = library.createArtist()
        artist.id = "5432"
        artist.name = "AC/DC"
    }
    
    override func checkCorrectParsing() {
        let albums = library.getAlbums().sorted(by: {Int($0.id)! < Int($1.id)!} )
        XCTAssertEqual(albums.count, 15)
        
        var album = albums[1]
        XCTAssertEqual(album.id, "11047")
        XCTAssertEqual(album.name, "Back In Black")
        XCTAssertEqual(album.artist?.id, "5432")
        XCTAssertEqual(album.artist?.name, "AC/DC")
        XCTAssertEqual(album.year, 0)
        XCTAssertEqual(album.songCount, 10)
        XCTAssertNil(album.genre)
        XCTAssertEqual(album.artwork?.url, "www-al-11047")
        XCTAssertEqual(album.artwork?.type, "")
        XCTAssertEqual(album.artwork?.id, "al-11047")
        
        
        album = albums[6]
        XCTAssertEqual(album.id, "11052")
        XCTAssertEqual(album.name, "For Those About To Rock")
        XCTAssertEqual(album.artist?.id, "5432")
        XCTAssertEqual(album.artist?.name, "AC/DC")
        XCTAssertEqual(album.year, 0)
        XCTAssertEqual(album.songCount, 10)
        XCTAssertNil(album.genre)
        XCTAssertEqual(album.artwork?.url, "www-al-11052")
        XCTAssertEqual(album.artwork?.type, "")
        XCTAssertEqual(album.artwork?.id, "al-11052")
        
        album = albums[7]
        XCTAssertEqual(album.id, "11053")
        XCTAssertEqual(album.name, "High Voltage")
        XCTAssertEqual(album.artist?.id, "5432")
        XCTAssertEqual(album.artist?.name, "AC/DC")
        XCTAssertEqual(album.year, 0)
        XCTAssertEqual(album.songCount, 8)
        XCTAssertNil(album.genre)
        XCTAssertEqual(album.artwork?.url, "www-al-11053")
        XCTAssertEqual(album.artwork?.type, "")
        XCTAssertEqual(album.artwork?.id, "al-11053")
        
        album = albums[14]
        XCTAssertEqual(album.id, "11061")
        XCTAssertEqual(album.name, "Who Made Who")
        XCTAssertEqual(album.artist?.id, "5432")
        XCTAssertEqual(album.artist?.name, "AC/DC")
        XCTAssertEqual(album.year, 0)
        XCTAssertEqual(album.songCount, 9)
        XCTAssertNil(album.genre)
        XCTAssertEqual(album.artwork?.url, "www-al-11061")
        XCTAssertEqual(album.artwork?.type, "")
        XCTAssertEqual(album.artwork?.id, "al-11061")
    }

}
