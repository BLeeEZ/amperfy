import XCTest
@testable import AmperfyKit

class SsMusicFolderParserTest: AbstractSsParserTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "musicFolders_example_1")
        ssParserDelegate = SsMusicFolderParserDelegate(library: library, syncWave: syncWave)
    }
    
    override func checkCorrectParsing() {
        XCTAssertEqual(library.musicFolderCount, 3)
        
        let musicFolders = library.getMusicFolders().sorted(by: {Int($0.id)! < Int($1.id)!} )
        XCTAssertEqual(musicFolders[0].id, "1")
        XCTAssertEqual(musicFolders[0].name, "Music")
        XCTAssertEqual(musicFolders[1].id, "2")
        XCTAssertEqual(musicFolders[1].name, "Movies")
        XCTAssertEqual(musicFolders[2].id, "3")
        XCTAssertEqual(musicFolders[2].name, "Incoming")
    }

}
