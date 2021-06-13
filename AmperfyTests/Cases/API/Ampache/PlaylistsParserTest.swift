import XCTest
@testable import Amperfy

class PlaylistsParserTest: AbstractAmpacheTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "playlists")
        recreateParserDelegate()
    }
    
    override func recreateParserDelegate() {
        parserDelegate = PlaylistParserDelegate(library: library, parseNotifier: nil)
    }
    
    override func checkCorrectParsing() {
        let playlists = library.getPlaylists()
        XCTAssertEqual(playlists.count, 4)
        
        var playlist = playlists[0]
        XCTAssertEqual(playlist.id, "smart_21")
        XCTAssertEqual(playlist.name, "admin - 02/23/2021 14:36:44")
        XCTAssertEqual(playlist.songCount, 5000)
        
        playlist = playlists[1]
        XCTAssertEqual(playlist.id, "smart_14")
        XCTAssertEqual(playlist.name, "Album 1*")
        XCTAssertEqual(playlist.songCount, 2)
        
        playlist = playlists[2]
        XCTAssertEqual(playlist.id, "3")
        XCTAssertEqual(playlist.name, "random - admin - private")
        XCTAssertEqual(playlist.songCount, 43)
        
        playlist = playlists[3]
        XCTAssertEqual(playlist.id, "2")
        XCTAssertEqual(playlist.name, "random - admin - public")
        XCTAssertEqual(playlist.songCount, 43)
    }

}
