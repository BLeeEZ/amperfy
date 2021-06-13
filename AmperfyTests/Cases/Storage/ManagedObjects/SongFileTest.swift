import XCTest
@testable import Amperfy

class SongFileTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var testSongFile: SongFile!

    override func setUp() {
        cdHelper = CoreDataHelper()
        library = cdHelper.createSeededStorage()
        testSongFile = library.createSongFile()
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let songFile = library.createSongFile()
        XCTAssertEqual(songFile.info, nil)
        XCTAssertEqual(songFile.data, nil)
    }
    
    func testProperties() {
        let songId = cdHelper.seeder.songs[0].id
        let testData = Artwork.defaultImage.pngData()!
        guard let song = library.getSong(id: songId) else { XCTFail(); return }
        testSongFile.info = song
        testSongFile.data = testData
        XCTAssertEqual(testSongFile.info?.id, songId)
        XCTAssertEqual(testSongFile.data, testData)
        library.saveContext()
        guard let songFetched = library.getSong(id: songId) else { XCTFail(); return }
        guard let songFileFetched = library.getSongFile(forSong: songFetched) else { XCTFail(); return }
        XCTAssertEqual(songFileFetched.info?.id, songId)
        XCTAssertEqual(songFileFetched.data, testData)
    }

}
