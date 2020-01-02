import XCTest
@testable import Amperfy

class SongFileTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var storage: LibraryStorage!
    var testSongFile: SongFile!

    override func setUp() {
        cdHelper = CoreDataHelper()
        storage = cdHelper.createSeededStorage()
        testSongFile = storage.createSongFile()
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let songFile = storage.createSongFile()
        XCTAssertEqual(songFile.info, nil)
        XCTAssertEqual(songFile.data, nil)
    }
    
    func testProperties() {
        let songId = cdHelper.seeder.songs[0].id
        let testData = Artwork.defaultImage.pngData()! as NSData
        guard let song = storage.getSong(id: songId) else { XCTFail(); return }
        testSongFile.info = song
        testSongFile.data = testData
        XCTAssertEqual(testSongFile.info?.id, songId)
        XCTAssertEqual(testSongFile.data, testData)
        XCTAssertEqual(song.file?.data, testData)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: songId) else { XCTFail(); return }
        guard let songFileFetched = songFetched.file else { XCTFail(); return }
        XCTAssertEqual(songFileFetched.info?.id, songId)
        XCTAssertEqual(songFileFetched.data, testData)
        XCTAssertEqual(songFetched.file?.data, testData)
    }

}
