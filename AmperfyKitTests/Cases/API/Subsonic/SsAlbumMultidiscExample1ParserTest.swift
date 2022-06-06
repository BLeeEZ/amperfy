import XCTest
@testable import AmperfyKit

class SsAlbumMultidiscExample1ParserTest: AbstractSsParserTest {
    
    let albumId = "e209ff7a279e487ea2f37a4a3e7ed563"
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "album_multidisc_example_1")
        ssParserDelegate = SsSongParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator, parseNotifier: nil)
        createTestAlbum()
    }

    func createTestAlbum() {
        let album = library.createAlbum()
        album.id = albumId
        album.name = "The Analog Botany Collection"
        album.artwork?.url = "al-11053"
    }
    
    override func checkCorrectParsing() {
        let fetchRequest = SongMO.trackNumberSortedFetchRequest
        let album = library.getAlbum(id: albumId)!
        fetchRequest.predicate = library.getFetchPredicate(forAlbum: album)
        
        let songsMO = try? context.fetch(fetchRequest)
        guard let songsMO = songsMO else { XCTFail(); return }
        XCTAssertEqual(songsMO.count, 27)
        
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?.compactMap{ Song(managedObject: $0) }
        guard let songs = songs else { XCTFail(); return }

        var song = songs[0]
        XCTAssertEqual(2, song.track)
        XCTAssertEqual("1", song.disk)
        song = songs[1]
        XCTAssertEqual(3, song.track)
        XCTAssertEqual("1", song.disk)
        song = songs[2]
        XCTAssertEqual(4, song.track)
        XCTAssertEqual("1", song.disk)
        song = songs[3]
        XCTAssertEqual(1, song.track)
        XCTAssertEqual("2", song.disk)
        song = songs[4]
        XCTAssertEqual(3, song.track)
        XCTAssertEqual("2", song.disk)
        song = songs[5]
        XCTAssertEqual(5, song.track)
        XCTAssertEqual("2", song.disk)
        song = songs[6]
        XCTAssertEqual(2, song.track)
        XCTAssertEqual("3", song.disk)
    }

}
