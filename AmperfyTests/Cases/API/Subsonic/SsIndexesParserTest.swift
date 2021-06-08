import XCTest
@testable import Amperfy

class SsIndexesParserTest: AbstractSsParserTest {
    
    var musicFolder: MusicFolder!
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "indexes_example_1")
        musicFolder = library.createMusicFolder()
        ssParserDelegate = SsDirectoryParserDelegate(musicFolder: musicFolder, libraryStorage: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator)
    }
    
    override func checkCorrectParsing() {
        let directories = musicFolder.directories.sorted(by: {Int($0.id)! < Int($1.id)!} )
        XCTAssertEqual(directories.count, 4)
        
        XCTAssertEqual(directories[0].id, "1")
        XCTAssertEqual(directories[0].name, "ABBA")
        XCTAssertEqual(directories[1].id, "2")
        XCTAssertEqual(directories[1].name, "Alanis Morisette")
        XCTAssertEqual(directories[2].id, "3")
        XCTAssertEqual(directories[2].name, "Alphaville")
        XCTAssertEqual(directories[3].id, "4")
        XCTAssertEqual(directories[3].name, "Bob Dylan")
        
        let songs = musicFolder.songs.sorted(by: {Int($0.id)! < Int($1.id)!} )
        XCTAssertEqual(songs.count, 2)
        
        var song = songs[0]
        XCTAssertEqual(song.id, "111")
        XCTAssertEqual(song.title, "Dancing Queen")
        XCTAssertNil(song.artist)
        XCTAssertNil(song.album)
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
        XCTAssertNil(song.artist)
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
