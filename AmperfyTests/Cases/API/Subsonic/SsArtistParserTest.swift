import XCTest
@testable import Amperfy

class SsArtistParserTest: AbstractSsParserTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "artists_example_1")
        ssParserDelegate = SsArtistParserDelegate(libraryStorage: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator, parseNotifier: nil)
    }
    
    override func checkCorrectParsing() {
        let artists = library.getArtists().sorted(by: {Int($0.id)! < Int($1.id)!})
        XCTAssertEqual(artists.count, 6)

        var artist = artists[0]
        XCTAssertEqual(artist.id, "5421")
        XCTAssertEqual(artist.name, "ABBA")
        XCTAssertEqual(artist.albumCount, 6)
        XCTAssertEqual(artist.artwork?.url, "ar-5421")
        
        artist = artists[1]
        XCTAssertEqual(artist.id, "5432")
        XCTAssertEqual(artist.name, "AC/DC")
        XCTAssertEqual(artist.albumCount, 15)
        XCTAssertEqual(artist.artwork?.url, "ar-5432")
        
        artist = artists[2]
        XCTAssertEqual(artist.id, "5449")
        XCTAssertEqual(artist.name, "A-Ha")
        XCTAssertEqual(artist.albumCount, 4)
        XCTAssertEqual(artist.artwork?.url, "ar-5449")
        
        artist = artists[3]
        XCTAssertEqual(artist.id, "5950")
        XCTAssertEqual(artist.name, "Bob Marley")
        XCTAssertEqual(artist.albumCount, 8)
        XCTAssertEqual(artist.artwork?.url, "ar-5950")
        
        artist = artists[4]
        XCTAssertEqual(artist.id, "5957")
        XCTAssertEqual(artist.name, "Bruce Dickinson")
        XCTAssertEqual(artist.albumCount, 2)
        XCTAssertEqual(artist.artwork?.url, "ar-5957")
        
        artist = artists[5]
        XCTAssertEqual(artist.id, "6633")
        XCTAssertEqual(artist.name, "Aaron Neville")
        XCTAssertEqual(artist.albumCount, 1)
        XCTAssertEqual(artist.artwork?.url, "ar-6633")
    }

}
