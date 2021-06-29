import XCTest
@testable import Amperfy

class PlayableFileTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var testPlayableFile: PlayableFile!

    override func setUp() {
        cdHelper = CoreDataHelper()
        library = cdHelper.createSeededStorage()
        testPlayableFile = library.createPlayableFile()
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let playableFile = library.createPlayableFile()
        XCTAssertEqual(playableFile.info, nil)
        XCTAssertEqual(playableFile.data, nil)
    }
    
    func testProperties() {
        let songId = cdHelper.seeder.songs[0].id
        let testData = Artwork.defaultImage.pngData()!
        guard let song = library.getSong(id: songId) else { XCTFail(); return }
        testPlayableFile.info = song
        testPlayableFile.data = testData
        XCTAssertEqual(testPlayableFile.info?.id, songId)
        XCTAssertEqual(testPlayableFile.data, testData)
        library.saveContext()
        guard let songFetched = library.getSong(id: songId) else { XCTFail(); return }
        guard let songFileFetched = library.getFile(forPlayable: songFetched) else { XCTFail(); return }
        XCTAssertEqual(songFileFetched.info?.id, songId)
        XCTAssertEqual(songFileFetched.data, testData)
    }

}
