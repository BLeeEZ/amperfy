import XCTest
@testable import Amperfy

class SsSongExample2ParserTest: AbstractSsParserTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "album_example_2")
        ssParserDelegate = SsSongParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator, parseNotifier: nil)
        createTestPartner()
    }

    func createTestPartner() {
        let artist = library.createArtist()
        artist.id = "5432"
        artist.name = "AC/DC"
        
        let album = library.createAlbum()
        album.id = "11053"
        album.name = "High Voltage"
        album.artwork?.url = "al-11053"
    }
    
    override func checkCorrectParsing() {
        let songs = library.getSongs().sorted(by: {$0.id > $1.id} )
        XCTAssertEqual(songs.count, 2)
        
        var song = songs[0]
        XCTAssertEqual(song.id, "71463")
        XCTAssertEqual(song.title, "The Jack")
        XCTAssertEqual(song.artist?.id, "5432")
        XCTAssertEqual(song.artist?.name, "AC/DC")
        XCTAssertNil(song.album)
        XCTAssertNil(song.disk)
        XCTAssertEqual(song.track, 0)
        XCTAssertNil(song.genre)
        XCTAssertEqual(song.duration, 352)
        XCTAssertEqual(song.year, 0)
        XCTAssertEqual(song.bitrate, 128000)
        XCTAssertEqual(song.contentType, "audio/mpeg")
        XCTAssertNil(song.url)
        XCTAssertEqual(song.size, 5624132)
        XCTAssertEqual(song.artwork?.url, "www-71381")
        XCTAssertEqual(song.artwork?.type, "")
        XCTAssertEqual(song.artwork?.id, "71381")
        let song1Artwork = song.artwork
        
        song = songs[1]
        XCTAssertEqual(song.id, "71458")
        XCTAssertEqual(song.title, "It's A Long Way To The Top")
        XCTAssertEqual(song.artist?.id, "5432")
        XCTAssertEqual(song.artist?.name, "AC/DC")
        XCTAssertNil(song.album)
        XCTAssertNil(song.disk)
        XCTAssertEqual(song.track, 0)
        XCTAssertEqual(song.genre?.id, "")
        XCTAssertEqual(song.genre?.name, "Rock")
        XCTAssertEqual(song.duration, 315)
        XCTAssertEqual(song.year, 1976)
        XCTAssertEqual(song.bitrate, 128000)
        XCTAssertEqual(song.contentType, "audio/mpeg")
        XCTAssertNil(song.url)
        XCTAssertEqual(song.size, 5037357)
        XCTAssertEqual(song.artwork?.url, "www-71381")
        XCTAssertEqual(song.artwork?.type, "")
        XCTAssertEqual(song.artwork?.id, "71381")
        XCTAssertEqual(song.artwork, song1Artwork)
    }

}
