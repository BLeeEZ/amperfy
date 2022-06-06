import XCTest
@testable import AmperfyKit

class AlbumTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var testAlbum: Album!
    let testId = "23489"

    override func setUp() {
        cdHelper = CoreDataHelper()
        library = cdHelper.createSeededStorage()
        testAlbum = library.createAlbum()
        testAlbum.id = testId
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let album = library.createAlbum()
        XCTAssertEqual(album.id, "")
        XCTAssertEqual(album.identifier, "Unknown Album")
        XCTAssertEqual(album.name, "Unknown Album")
        XCTAssertEqual(album.year, 0)
        XCTAssertEqual(album.artist, nil)
        XCTAssertEqual(album.syncInfo, nil)
        XCTAssertEqual(album.songs.count, 0)
        XCTAssertNil(album.artwork)
        XCTAssertEqual(album.image(setting: .serverArtworkOnly), UIImage.albumArtwork)
        XCTAssertFalse(album.playables.hasCachedItems)
        XCTAssertFalse(album.isOrphaned)
    }
    
    func testArtist() {
        guard let artist = library.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        testAlbum.artist = artist
        XCTAssertEqual(testAlbum.artist!.id, artist.id)
        library.saveContext()
        guard let albumFetched = library.getAlbum(id: testId) else { XCTFail(); return }
        XCTAssertEqual(albumFetched.artist!.id, artist.id)
    }
    
    func testTitle() {
        let testTitle = "Alright"
        testAlbum.name = testTitle
        XCTAssertEqual(testAlbum.name, testTitle)
        XCTAssertEqual(testAlbum.identifier, testTitle)
        library.saveContext()
        guard let albumFetched = library.getAlbum(id: testId) else { XCTFail(); return }
        XCTAssertEqual(albumFetched.name, testTitle)
        XCTAssertEqual(albumFetched.identifier, testTitle)
    }
    
    func testYear() {
        let testYear = 2001
        testAlbum.year = testYear
        XCTAssertEqual(testAlbum.year, testYear)
        library.saveContext()
        guard let albumFetched = library.getAlbum(id: testId) else { XCTFail(); return }
        XCTAssertEqual(albumFetched.year, testYear)
    }
    
    
    func testArtworkAndImage() {
        let testData = UIImage.albumArtwork.pngData()!
        let testImg = UIImage.albumArtwork
        testAlbum.artwork = library.createArtwork()
        testAlbum.artwork?.setImage(fromData: testData)
        XCTAssertNil(testAlbum.artwork?.image)
        XCTAssertEqual(testAlbum.image(setting: .serverArtworkOnly), testImg)
        library.saveContext()
        guard let albumFetched = library.getAlbum(id: testId) else { XCTFail(); return }
        XCTAssertNil(albumFetched.artwork?.image)
        XCTAssertEqual(albumFetched.image(setting: .serverArtworkOnly), testImg)
    }

    func testSyncWave() {
        let testWaveId: Int = 987
        let testWave = library.createSyncWave()
        testWave.id = testWaveId
        testAlbum.syncInfo = testWave
        XCTAssertEqual(testAlbum.syncInfo?.id, testWaveId)
        library.saveContext()
        guard let albumFetched = library.getAlbum(id: testId) else { XCTFail(); return }
        XCTAssertEqual(albumFetched.syncInfo?.id, testWaveId)
    }
    
    func testSongs() {
        guard let album3Items = library.getAlbum(id: cdHelper.seeder.albums[0].id) else { XCTFail(); return }
        XCTAssertEqual(album3Items.songs.count, 3)
        guard let album2Items = library.getAlbum(id: cdHelper.seeder.albums[2].id) else { XCTFail(); return }
        XCTAssertEqual(album2Items.songs.count, 2)
    }
    
    func testHasCachedSongs() {
        guard let albumNoCached = library.getAlbum(id: cdHelper.seeder.albums[0].id) else { XCTFail(); return }
        XCTAssertFalse(albumNoCached.playables.hasCachedItems)
        guard let albumTwoCached = library.getAlbum(id: cdHelper.seeder.albums[2].id) else { XCTFail(); return }
        XCTAssertTrue(albumTwoCached.playables.hasCachedItems)
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
