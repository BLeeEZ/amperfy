import XCTest
@testable import AmperfyKit

class SsDirectoriesExample2ParserTest: AbstractSsParserTest {
    
    var directory: Directory!
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "directory_example_2")
        directory = library.createDirectory()
        ssParserDelegate = SsDirectoryParserDelegate(directory: directory, library: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator)
        createTestPartner()
    }
    
    func createTestPartner() {
        let artist = library.createArtist()
        artist.id = "5432"
        artist.name = "ABBA"
        
        let album = library.createAlbum()
        album.id = "11053"
        album.name = "Arrival"
        album.artwork?.url = "al-11053"
    }
    
    override func checkCorrectParsing() {
        XCTAssertEqual(directory.subdirectories.count, 0)
        let songs = directory.songs.sorted(by: {Int($0.id)! < Int($1.id)!} )
        XCTAssertEqual(songs.count, 2)
        
        var song = songs[0]
        XCTAssertEqual(song.id, "111")
        XCTAssertEqual(song.title, "Dancing Queen")
        XCTAssertEqual(song.artist?.id, "5432")
        XCTAssertEqual(song.artist?.name, "ABBA")
        XCTAssertEqual(song.album?.id, "11053")
        XCTAssertEqual(song.album?.name, "Arrival")
        XCTAssertNil(song.disk)
        XCTAssertEqual(song.track, 7)
        XCTAssertEqual(song.genre?.id, "")
        XCTAssertEqual(song.genre?.name, "Pop")
        XCTAssertEqual(song.duration, 146)
        XCTAssertEqual(song.year, 1978)
        XCTAssertEqual(song.bitrate, 128000)
        XCTAssertEqual(song.contentType, "audio/mpeg")
        XCTAssertNil(song.url)
        XCTAssertEqual(song.size, 8421341)
        XCTAssertEqual(song.artwork?.url, "www-24")
        XCTAssertEqual(song.artwork?.type, "")
        XCTAssertEqual(song.artwork?.id, "24")
        
        song = songs[1]
        XCTAssertEqual(song.id, "112")
        XCTAssertEqual(song.title, "Money, Money, Money")
        XCTAssertEqual(song.artist?.name, "ABBA")
        XCTAssertNil(song.album)
        XCTAssertNil(song.disk)
        XCTAssertEqual(song.track, 7)
        XCTAssertEqual(song.genre?.id, "")
        XCTAssertEqual(song.genre?.name, "Pop")
        XCTAssertEqual(song.duration, 208)
        XCTAssertEqual(song.year, 1978)
        XCTAssertEqual(song.bitrate, 128000)
        XCTAssertEqual(song.contentType, "audio/flac")
        XCTAssertNil(song.url)
        XCTAssertEqual(song.size, 4910028)
        XCTAssertEqual(song.artwork?.url, "www-25")
        XCTAssertEqual(song.artwork?.type, "")
        XCTAssertEqual(song.artwork?.id, "25")
    }

}
