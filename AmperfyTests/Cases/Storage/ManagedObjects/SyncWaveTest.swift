import XCTest
@testable import Amperfy

class SyncWaveTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var storage: LibraryStorage!
    var testSyncWave: SyncWave!
    let nowDate = Date()

    override func setUp() {
        cdHelper = CoreDataHelper()
        storage = cdHelper.createSeededStorage()
        testSyncWave = storage.createSyncWave()
        checkCreation()
    }

    override func tearDown() {
    }
    
    func checkCreation() {
        XCTAssertEqual(testSyncWave.id, 0)
        XCTAssertEqual(testSyncWave.syncState, SyncState.Artists)
        XCTAssertEqual(testSyncWave.syncIndexToContinue, 0)
        XCTAssertTrue(testSyncWave.isInitialWave)
        XCTAssertFalse(testSyncWave.isDone)
        XCTAssertEqual(testSyncWave.libraryChangeDates.dateOfLastAdd.compare(nowDate), ComparisonResult.orderedDescending)
        XCTAssertEqual(testSyncWave.libraryChangeDates.dateOfLastClean.compare(nowDate), ComparisonResult.orderedDescending)
        XCTAssertEqual(testSyncWave.libraryChangeDates.dateOfLastUpdate.compare(nowDate), ComparisonResult.orderedDescending)
        XCTAssertEqual(testSyncWave.songs.count, 0)
        XCTAssertFalse(testSyncWave.hasCachedSongs)
    }
    
    func testSecondCreation() {
        let syncWave = storage.createSyncWave()
        XCTAssertEqual(syncWave.id, 1)
        XCTAssertEqual(syncWave.syncState, SyncState.Artists)
        XCTAssertEqual(syncWave.syncIndexToContinue, 0)
        XCTAssertFalse(syncWave.isInitialWave)
        XCTAssertFalse(syncWave.isDone)
        XCTAssertEqual(syncWave.libraryChangeDates.dateOfLastAdd.compare(nowDate), ComparisonResult.orderedDescending)
        XCTAssertEqual(syncWave.libraryChangeDates.dateOfLastClean.compare(nowDate), ComparisonResult.orderedDescending)
        XCTAssertEqual(syncWave.libraryChangeDates.dateOfLastUpdate.compare(nowDate), ComparisonResult.orderedDescending)
        XCTAssertEqual(syncWave.songs.count, 0)
        XCTAssertFalse(syncWave.hasCachedSongs)
    }
    
    func testIdAndSongsAnd() {
        let testId = 456
        let testSongId = cdHelper.seeder.songs[0].id
        guard let song = storage.getSong(id: testSongId) else { XCTFail(); return }
        testSyncWave.id = testId
        XCTAssertEqual(testSyncWave.id, testId)
        song.syncInfo = testSyncWave
        XCTAssertEqual(testSyncWave.songs.count, 1)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testSongId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.syncInfo?.id, testId)
        XCTAssertEqual(songFetched.syncInfo?.songs.count, 1)
    }
    
    func testSyncStateAndIsDone() {
        let testSongId = cdHelper.seeder.songs[0].id
        guard let song = storage.getSong(id: testSongId) else { XCTFail(); return }
        song.syncInfo = testSyncWave
        
        testSyncWave.syncState = .Albums
        XCTAssertEqual(testSyncWave.syncState, SyncState.Albums)
        XCTAssertFalse(testSyncWave.isDone)
        testSyncWave.syncState = .Done
        XCTAssertEqual(testSyncWave.syncState, SyncState.Done)
        XCTAssertTrue(testSyncWave.isDone)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testSongId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.syncInfo?.syncState, SyncState.Done)
        XCTAssertTrue(testSyncWave.isDone)
    }
    
    func testSyncIndexToContinue() {
        let testSongId = cdHelper.seeder.songs[0].id
        guard let song = storage.getSong(id: testSongId) else { XCTFail(); return }
        song.syncInfo = testSyncWave
        
        testSyncWave.syncIndexToContinue = 20
        XCTAssertEqual(testSyncWave.syncIndexToContinue, 20)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testSongId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.syncInfo?.syncIndexToContinue, 20)
    }
    
    func testLibraryChangeDatesAndSetMetaData() {
        let testSongId = cdHelper.seeder.songs[0].id
        guard let song = storage.getSong(id: testSongId) else { XCTFail(); return }
        song.syncInfo = testSyncWave
        
        let addDate = Date(timeIntervalSince1970: TimeInterval(integerLiteral: 2000))
        let cleanDate = Date(timeIntervalSince1970: TimeInterval(integerLiteral: 4000))
        let updateDate = Date(timeIntervalSince1970: TimeInterval(integerLiteral: 15000))
        
        let testLibraryChangeDates = LibraryChangeDates()
        testLibraryChangeDates.dateOfLastAdd = addDate
        testLibraryChangeDates.dateOfLastClean = cleanDate
        testLibraryChangeDates.dateOfLastUpdate = updateDate
        testSyncWave.setMetaData(fromLibraryChangeDates: testLibraryChangeDates)
        
        XCTAssertEqual(testSyncWave.libraryChangeDates.dateOfLastAdd.compare(addDate), ComparisonResult.orderedSame)
        XCTAssertEqual(testSyncWave.libraryChangeDates.dateOfLastClean.compare(cleanDate), ComparisonResult.orderedSame)
        XCTAssertEqual(testSyncWave.libraryChangeDates.dateOfLastUpdate.compare(updateDate), ComparisonResult.orderedSame)
        storage.saveContext()
        guard let songFetched = storage.getSong(id: testSongId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.syncInfo?.libraryChangeDates.dateOfLastAdd.compare(addDate), ComparisonResult.orderedSame)
        XCTAssertEqual(songFetched.syncInfo?.libraryChangeDates.dateOfLastClean.compare(cleanDate), ComparisonResult.orderedSame)
        XCTAssertEqual(songFetched.syncInfo?.libraryChangeDates.dateOfLastUpdate.compare(updateDate), ComparisonResult.orderedSame)
    }
    
    func testHasCachedSongs() {
        let testSongNotCachedId = cdHelper.seeder.songs[0].id
        let testSongCachedId = cdHelper.seeder.songs[4].id
        guard let songNotCached = storage.getSong(id: testSongNotCachedId) else { XCTFail(); return }
        guard let songCached = storage.getSong(id: testSongCachedId) else { XCTFail(); return }
        
        songNotCached.syncInfo = testSyncWave
        XCTAssertFalse(testSyncWave.hasCachedSongs)
        storage.saveContext()
        guard let songFetched1 = storage.getSong(id: testSongNotCachedId) else { XCTFail(); return }
        XCTAssertFalse(songFetched1.syncInfo!.hasCachedSongs)
        
        songCached.syncInfo = testSyncWave
        XCTAssertTrue(testSyncWave.hasCachedSongs)
        storage.saveContext()
        guard let songFetched2 = storage.getSong(id: testSongNotCachedId) else { XCTFail(); return }
        XCTAssertTrue(songFetched2.syncInfo!.hasCachedSongs)
    }
    
}
