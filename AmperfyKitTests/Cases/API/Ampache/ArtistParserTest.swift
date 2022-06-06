import XCTest
@testable import AmperfyKit

class ArtistParserTest: AbstractAmpacheTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "artists")
        recreateParserDelegate()
    }
    
    override func recreateParserDelegate() {
        parserDelegate = ArtistParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
    }
    
    override func checkCorrectParsing() {
        let artists = library.getArtists()
        XCTAssertEqual(artists.count, 4)
        XCTAssertEqual(library.genreCount, 1)
        
        var artist = artists[0]
        XCTAssertEqual(artist.id, "16")
        XCTAssertEqual(artist.name, "CARNÚN")
        XCTAssertEqual(artist.rating, 3)
        XCTAssertEqual(artist.albumCount, 1)
        XCTAssertEqual(artist.artwork?.url, "https://music.com.au/image.php?object_id=16&object_type=artist&auth=eeb9f1b6056246a7d563f479f518bb34")
        XCTAssertEqual(artist.artwork?.type, "artist")
        XCTAssertEqual(artist.artwork?.id, "16")
        
        artist = artists[1]
        XCTAssertEqual(artist.id, "27")
        XCTAssertEqual(artist.name, "Chi.Otic")
        XCTAssertEqual(artist.rating, 0)
        XCTAssertEqual(artist.albumCount, 0)
        XCTAssertEqual(artist.artwork?.url, "https://music.com.au/image.php?object_id=27&object_type=artist&auth=eeb9f1b6056246a7d563f479f518bb34")
        XCTAssertEqual(artist.artwork?.type, "artist")
        XCTAssertEqual(artist.artwork?.id, "27")
        
        artist = artists[3]
        XCTAssertEqual(artist.id, "13")
        XCTAssertEqual(artist.name, "IOK-1")
        XCTAssertEqual(artist.rating, 5)
        XCTAssertEqual(artist.albumCount, 1)
        XCTAssertEqual(artist.artwork?.url, "https://music.com.au/image.php?object_id=13&object_type=artist&auth=eeb9f1b6056246a7d563f479f518bb34")
        XCTAssertEqual(artist.artwork?.type, "artist")
        XCTAssertEqual(artist.artwork?.id, "13")
        XCTAssertEqual(artist.genre?.id, "4")
        XCTAssertEqual(artist.genre?.name, "Dark Ambient")
    }

}
