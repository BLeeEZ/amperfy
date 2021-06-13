import XCTest
@testable import Amperfy

class SsPlaylistsParserTest: AbstractSsParserTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "playlists_example_1")
        ssParserDelegate = SsPlaylistParserDelegate(library: library)
    }
    
    override func checkCorrectParsing() {
        let playlists = library.getPlaylists()
        XCTAssertEqual(playlists.count, 2)
        
        var playlist = playlists[1]
        XCTAssertEqual(playlist.id, "15")
        XCTAssertEqual(playlist.name, "Some random songs")
        XCTAssertEqual(playlist.songCount, 6)
        
        playlist = playlists[0]
        XCTAssertEqual(playlist.id, "16")
        XCTAssertEqual(playlist.name, "More random songs")
        XCTAssertEqual(playlist.songCount, 5)
    }

}
