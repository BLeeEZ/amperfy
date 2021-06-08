import XCTest
@testable import Amperfy

class ArtistParserTest: AbstractAmpacheTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "artists")
        recreateParserDelegate()
    }
    
    override func recreateParserDelegate() {
        parserDelegate = ArtistParserDelegate(libraryStorage: library, syncWave: syncWave, parseNotifier: nil)
    }
    
    override func checkCorrectParsing() {
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
