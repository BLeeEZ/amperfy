import XCTest
@testable import Amperfy

class ArtistTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var storage: LibraryStorage!
    var testArtist: Artist!
    let testId = "10089"

    override func setUp() {
        cdHelper = CoreDataHelper()
        storage = cdHelper.createSeededStorage()
        testArtist = storage.createArtist()
        testArtist.id = testId
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let artist = storage.createArtist()
        XCTAssertEqual(artist.id, "")
        XCTAssertEqual(artist.identifier, "Unknown Artist")
        XCTAssertEqual(artist.name, "Unknown Artist")
        XCTAssertEqual(artist.songs.count, 0)
        XCTAssertFalse(artist.hasCachedSongs)
        XCTAssertEqual(artist.albums.count, 0)
        XCTAssertEqual(artist.syncInfo, nil)
        XCTAssertEqual(artist.artwork?.image, Artwork.defaultImage)
        XCTAssertEqual(artist.image, Artwork.defaultImage)
    }
    
    func testName() {
        let testTitle = "Alright"
        testArtist.name = testTitle
        XCTAssertEqual(testArtist.name, testTitle)
        XCTAssertEqual(testArtist.identifier, testTitle)
        storage.saveContext()
        guard let artistFetched = storage.getArtist(id: testId) else { XCTFail(); return }
        XCTAssertEqual(artistFetched.name, testTitle)
        XCTAssertEqual(artistFetched.identifier, testTitle)
    }
    
    func testSongs() {
        guard let artist3Items = storage.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        XCTAssertEqual(artist3Items.songs.count, 3)
        guard let artist2Items = storage.getArtist(id: cdHelper.seeder.artists[1].id) else { XCTFail(); return }
        XCTAssertEqual(artist2Items.songs.count, 2)
    }
    
    func testHasCachedSongs() {
        guard let artistNoCached = storage.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        XCTAssertFalse(artistNoCached.hasCachedSongs)
        guard let artistTwoCached = storage.getArtist(id: cdHelper.seeder.artists[2].id) else { XCTFail(); return }
        XCTAssertTrue(artistTwoCached.hasCachedSongs)
    }

    func testAlbums() {
        guard let artist1Items = storage.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        XCTAssertEqual(artist1Items.albums.count, 1)
        guard let artist2Items = storage.getArtist(id: cdHelper.seeder.artists[2].id) else { XCTFail(); return }
        XCTAssertEqual(artist2Items.albums.count, 2)
    }
    
    func testArtworkAndImage() {
        let testData = Artwork.defaultImage.pngData()!
        let testImg = Artwork.defaultImage
        testArtist.artwork = storage.createArtwork()
        testArtist.artwork?.setImage(fromData: testData)
        XCTAssertEqual(testArtist.artwork?.image, testImg)
        XCTAssertEqual(testArtist.image, testImg)
        storage.saveContext()
        guard let artistFetched = storage.getArtist(id: testId) else { XCTFail(); return }
        XCTAssertEqual(artistFetched.artwork?.image, testImg)
        XCTAssertEqual(artistFetched.image, testImg)
    }

    func testSyncWave() {
        let testWaveId: Int = 987
        let testWave = storage.createSyncWave()
        testWave.id = testWaveId
        testArtist.syncInfo = testWave
        XCTAssertEqual(testArtist.syncInfo?.id, testWaveId)
        storage.saveContext()
        guard let artistFetched = storage.getArtist(id: testId) else { XCTFail(); return }
        XCTAssertEqual(artistFetched.syncInfo?.id, testWaveId)
    }

}
