import XCTest
@testable import Amperfy

class SongTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var storage: LibraryStorage!
    var testSong: Song!
    let testId = 2345

    override func setUp() {
        cdHelper = CoreDataHelper()
        storage = cdHelper.createSeededStorage()
        testSong = storage.createSong()
        testSong.id = testId
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let song = storage.createSong()
        XCTAssertEqual(song.id, 0)
        XCTAssertEqual(song.artwork?.image, Artwork.defaultImage)
        XCTAssertEqual(song.title, "Unknown title")
        XCTAssertEqual(song.track, 0)
        XCTAssertEqual(song.url, nil)
        XCTAssertEqual(song.album, nil)
        XCTAssertEqual(song.artist, nil)
        XCTAssertEqual(song.file, nil)
        XCTAssertEqual(song.fileData, nil)
        XCTAssertEqual(song.syncInfo, nil)
        XCTAssertEqual(song.displayString, "Unknown artist - Unknown title")
        XCTAssertEqual(song.identifier, "Unknown title")
        XCTAssertEqual(song.image, Artwork.defaultImage)
        XCTAssertFalse(song.isCached)
    }
    
    func testArtist() {
        guard let artist = storage.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        testSong.artist = artist
        XCTAssertEqual(testSong.artist!.id, artist.id)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.artist!.id, artist.id)
    }
    
    func testAlbum() {
        guard let album = storage.getAlbum(id: cdHelper.seeder.albums[0].id) else { XCTFail(); return }
        testSong.album = album
        XCTAssertEqual(testSong.album!.id, album.id)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.album!.id, album.id)
    }
    
    func testTitle() {
        let testTitle = "Alright"
        testSong.title = testTitle
        XCTAssertEqual(testSong.title, testTitle)
        XCTAssertEqual(testSong.displayString, "Unknown artist - " + testTitle)
        XCTAssertEqual(testSong.identifier, testTitle)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.title, testTitle)
        XCTAssertEqual(songFetched.displayString, "Unknown artist - " + testTitle)
        XCTAssertEqual(songFetched.identifier, testTitle)
    }
    
    func testTrack() {
        let testTrack = 13
        testSong.track = testTrack
        XCTAssertEqual(testSong.track, testTrack)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.track, testTrack)
    }
    
    func testUrl() {
        let testUrl = "www.blub.de"
        testSong.url = testUrl
        XCTAssertEqual(testSong.url, testUrl)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.url, testUrl)
    }
    
    func testCachedSong() {
        let testData = NSData(base64Encoded: "Test", options: .ignoreUnknownCharacters)
        testSong.file = storage.createSongFile()
        testSong.file?.data = testData
        XCTAssertTrue(testSong.isCached)
        XCTAssertEqual(testSong.fileData, testData)
        XCTAssertEqual(testSong.file?.data, testData)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testId) else { XCTFail(); return }
        XCTAssertTrue(songFetched.isCached)
        XCTAssertEqual(songFetched.fileData, testData)
        XCTAssertEqual(songFetched.file?.data, testData)
    }
    
    func testArtworkAndImage() {
        let testData = Artwork.defaultImage.pngData()! as NSData
        let testImg = Artwork.defaultImage
        testSong.artwork = storage.createArtwork()
        testSong.artwork?.setImage(fromData: testData)
        XCTAssertEqual(testSong.artwork?.image, testImg)
        XCTAssertEqual(testSong.image, testImg)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.artwork?.image, testImg)
        XCTAssertEqual(songFetched.image, testImg)
    }
    
    func testSyncWave() {
        let testWaveId: Int = 987
        let testWave = storage.createSyncWave()
        testWave.id = testWaveId
        testSong.syncInfo = testWave
        XCTAssertEqual(testSong.syncInfo?.id, testWaveId)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.syncInfo?.id, testWaveId)
    }

}
