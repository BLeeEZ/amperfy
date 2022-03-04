import XCTest
@testable import Amperfy

class SongTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var testSong: Song!
    let testId = "2345"

    override func setUp() {
        cdHelper = CoreDataHelper()
        library = cdHelper.createSeededStorage()
        testSong = library.createSong()
        testSong.id = testId
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let song = library.createSong()
        XCTAssertEqual(song.id, "")
        XCTAssertNil(song.artwork)
        XCTAssertEqual(song.title, "Unknown Title")
        XCTAssertEqual(song.track, 0)
        XCTAssertEqual(song.url, nil)
        XCTAssertEqual(song.album, nil)
        XCTAssertEqual(song.artist, nil)
        XCTAssertEqual(song.syncInfo, nil)
        XCTAssertEqual(song.displayString, "Unknown Artist - Unknown Title")
        XCTAssertEqual(song.identifier, "Unknown Title")
        XCTAssertEqual(song.image(setting: .serverArtworkOnly), UIImage.songArtwork)
        XCTAssertFalse(song.isCached)
    }
    
    func testArtist() {
        guard let artist = library.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        testSong.artist = artist
        XCTAssertEqual(testSong.artist!.id, artist.id)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.artist!.id, artist.id)
    }
    
    func testAlbum() {
        guard let album = library.getAlbum(id: cdHelper.seeder.albums[0].id) else { XCTFail(); return }
        testSong.album = album
        XCTAssertEqual(testSong.album!.id, album.id)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.album!.id, album.id)
    }
    
    func testTitle() {
        let testTitle = "Alright"
        testSong.title = testTitle
        XCTAssertEqual(testSong.title, testTitle)
        XCTAssertEqual(testSong.displayString, "Unknown Artist - " + testTitle)
        XCTAssertEqual(testSong.identifier, testTitle)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.title, testTitle)
        XCTAssertEqual(songFetched.displayString, "Unknown Artist - " + testTitle)
        XCTAssertEqual(songFetched.identifier, testTitle)
    }
    
    func testTrack() {
        let testTrack = 13
        testSong.track = testTrack
        XCTAssertEqual(testSong.track, testTrack)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.track, testTrack)
    }
    
    func testUrl() {
        let testUrl = "www.blub.de"
        testSong.url = testUrl
        XCTAssertEqual(testSong.url, testUrl)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.url, testUrl)
    }
    
    func testCachedSong() {
        let testData = Data(base64Encoded: "Test", options: .ignoreUnknownCharacters)
        let playableFile = library.createPlayableFile()
        playableFile.info = testSong
        playableFile.data = testData
        XCTAssertTrue(testSong.isCached)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertTrue(songFetched.isCached)
        guard let songFileFetched = library.getFile(forPlayable: testSong) else { XCTFail(); return }
        XCTAssertEqual(songFileFetched.data, testData)
    }
    
    func testArtworkAndImage() {
        let testData = UIImage.songArtwork.pngData()!
        let testImg = UIImage.songArtwork
        testSong.artwork = library.createArtwork()
        testSong.artwork?.setImage(fromData: testData)
        XCTAssertNil(testSong.artwork?.image)
        XCTAssertEqual(testSong.image(setting: .serverArtworkOnly), testImg)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertNil(songFetched.artwork?.image)
        XCTAssertEqual(songFetched.image(setting: .serverArtworkOnly), testImg)
    }
    
    func testSyncWave() {
        let testWaveId: Int = 987
        let testWave = library.createSyncWave()
        testWave.id = testWaveId
        testSong.syncInfo = testWave
        XCTAssertEqual(testSong.syncInfo?.id, testWaveId)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.syncInfo?.id, testWaveId)
    }
    
    func testRating() {
        testSong.rating = -1
        XCTAssertEqual(testSong.rating, 0)
        testSong.rating = 5
        XCTAssertEqual(testSong.rating, 5)
        testSong.rating = 1
        XCTAssertEqual(testSong.rating, 1)
        testSong.rating = 6
        XCTAssertEqual(testSong.rating, 1)
        testSong.rating = 0
        XCTAssertEqual(testSong.rating, 0)
        testSong.rating = 2
        XCTAssertEqual(testSong.rating, 2)
        testSong.rating = -500
        XCTAssertEqual(testSong.rating, 2)
        testSong.rating = 500
        XCTAssertEqual(testSong.rating, 2)
    }

}
