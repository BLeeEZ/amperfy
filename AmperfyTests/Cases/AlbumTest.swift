import XCTest
@testable import Amperfy

class AlbumTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var storage: LibraryStorage!
    var testAlbum: Album!
    let testId = 23489

    override func setUp() {
        cdHelper = CoreDataHelper()
        storage = cdHelper.createSeededStorage()
        testAlbum = storage.createAlbum()
        testAlbum.id = testId
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let album = storage.createAlbum()
        XCTAssertEqual(album.id, 0)
        XCTAssertEqual(album.identifier, "Unknown artist")
        XCTAssertEqual(album.name, "Unknown artist")
        XCTAssertEqual(album.year, 0)
        XCTAssertEqual(album.artist, nil)
        XCTAssertEqual(album.syncInfo, nil)
        XCTAssertEqual(album.songs.count, 0)
        XCTAssertEqual(album.artwork?.image, Artwork.defaultImage)
        XCTAssertEqual(album.image, Artwork.defaultImage)
        XCTAssertFalse(album.hasCachedSongs)
        XCTAssertFalse(album.isOrphaned)
    }
    
    func testArtist() {
        guard let artist = storage.getArtist(id: Int32(cdHelper.seeder.artists[0].id)) else { XCTFail(); return }
        testAlbum.artist = artist
        XCTAssertEqual(testAlbum.artist!.id, artist.id)
        storage.saveContext()
        guard let albumFetched = storage.getAlbum(id: testId) else { XCTFail(); return }
        XCTAssertEqual(albumFetched.artist!.id, artist.id)
    }
    
    func testTitle() {
        let testTitle = "Alright"
        testAlbum.name = testTitle
        XCTAssertEqual(testAlbum.name, testTitle)
        XCTAssertEqual(testAlbum.identifier, testTitle)
        storage.saveContext()
        guard let albumFetched = storage.getAlbum(id: testId) else { XCTFail(); return }
        XCTAssertEqual(albumFetched.name, testTitle)
        XCTAssertEqual(albumFetched.identifier, testTitle)
    }
    
    func testYear() {
        let testYear = 2001
        testAlbum.year = testYear
        XCTAssertEqual(testAlbum.year, testYear)
        storage.saveContext()
        guard let albumFetched = storage.getAlbum(id: testId) else { XCTFail(); return }
        XCTAssertEqual(albumFetched.year, testYear)
    }
    
    
    func testArtworkAndImage() {
        let testData = Artwork.defaultImage.pngData()! as NSData
        let testImg = Artwork.defaultImage
        testAlbum.artwork = storage.createArtwork()
        testAlbum.artwork?.imageData = testData
        XCTAssertEqual(testAlbum.artwork?.image, testImg)
        XCTAssertEqual(testAlbum.image, testImg)
        storage.saveContext()
        guard let albumFetched = storage.getAlbum(id: testId) else { XCTFail(); return }
        XCTAssertEqual(albumFetched.artwork?.image, testImg)
        XCTAssertEqual(albumFetched.image, testImg)
    }

    func testSyncWave() {
        let testWaveId: Int16 = 987
        let testWave = storage.createSyncWave()
        testWave.id = testWaveId
        testAlbum.syncInfo = testWave
        XCTAssertEqual(testAlbum.syncInfo?.id, testWaveId)
        storage.saveContext()
        guard let albumFetched = storage.getAlbum(id: testId) else { XCTFail(); return }
        XCTAssertEqual(albumFetched.syncInfo?.id, testWaveId)
    }
    
    func testSongs() {
        guard let album3Items = storage.getAlbum(id: cdHelper.seeder.albums[0].id) else { XCTFail(); return }
        XCTAssertEqual(album3Items.songs.count, 3)
        guard let album2Items = storage.getAlbum(id: cdHelper.seeder.albums[2].id) else { XCTFail(); return }
        XCTAssertEqual(album2Items.songs.count, 2)
    }
    
    func testHasCachedSongs() {
        guard let albumNoCached = storage.getAlbum(id: cdHelper.seeder.albums[0].id) else { XCTFail(); return }
        XCTAssertFalse(albumNoCached.hasCachedSongs)
        guard let albumTwoCached = storage.getAlbum(id: cdHelper.seeder.albums[2].id) else { XCTFail(); return }
        XCTAssertTrue(albumTwoCached.hasCachedSongs)
    }
    
    func testIsOrphaned() {
        testAlbum.name = "blub"
        XCTAssertFalse(testAlbum.isOrphaned)
        testAlbum.name = "Unknown Album"
        XCTAssertFalse(testAlbum.isOrphaned)
        testAlbum.name = "Orphaned"
        XCTAssertFalse(testAlbum.isOrphaned)
        testAlbum.name = "Unknown (Orphaned)"
        XCTAssertTrue(testAlbum.isOrphaned)
        testAlbum.name = "blub"
        XCTAssertFalse(testAlbum.isOrphaned)
    }

}
