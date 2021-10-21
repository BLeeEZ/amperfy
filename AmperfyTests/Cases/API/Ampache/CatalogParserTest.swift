import XCTest
@testable import Amperfy

class CatalogParserTest: AbstractAmpacheTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "catalogs")
        recreateParserDelegate()
    }
    
    override func recreateParserDelegate() {
        parserDelegate = CatalogParserDelegate(library: library, syncWave: syncWave)
    }
    
    override func checkCorrectParsing() {
        XCTAssertEqual(library.musicFolderCount, 4)
        
        let musicFolders = library.getMusicFolders().sorted(by: {Int($0.id)! < Int($1.id)!} )
        XCTAssertEqual(musicFolders[0].id, "1")
        XCTAssertEqual(musicFolders[0].name, "music")
        XCTAssertEqual(musicFolders[1].id, "2")
        XCTAssertEqual(musicFolders[1].name, "video")
        XCTAssertEqual(musicFolders[2].id, "3")
        XCTAssertEqual(musicFolders[2].name, "podcast")
        XCTAssertEqual(musicFolders[3].id, "4")
        XCTAssertEqual(musicFolders[3].name, "upload")
    }

}
