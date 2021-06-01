import XCTest
@testable import Amperfy

class SsDirectoriesExample1ParserTest: AbstractSsParserTest {
    
    var directory: Directory!
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "directory_example_1")
        directory = library.createDirectory()
        ssParserDelegate = SsDirectoryParserDelegate(directory: directory, libraryStorage: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator)
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
        XCTAssertEqual(directory.songs.count, 0)
        let directories = directory.subdirectories.sorted(by: {Int($0.id)! < Int($1.id)!} )
        XCTAssertEqual(directories.count, 2)
        
        XCTAssertEqual(directories[0].id, "11")
        XCTAssertEqual(directories[0].name, "Arrival")
        XCTAssertEqual(directories[0].artwork?.url, "22")
        XCTAssertEqual(directories[1].id, "12")
        XCTAssertEqual(directories[1].name, "Super Trouper")
        XCTAssertEqual(directories[1].artwork?.url, "23")
    }

}
