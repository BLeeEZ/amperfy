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
    }

}
