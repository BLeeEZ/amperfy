import XCTest
@testable import Amperfy

class PlayQueueHandlerTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var testQueueHandler: PlayQueueHandler!
    var testPlayer: PlayerData!
    var testNormalPlaylist: Playlist!
    var testShuffledPlaylist: Playlist!
    let fillCount = 5

    override func setUp() {
        cdHelper = CoreDataHelper()
        library = cdHelper.createSeededStorage()
        testPlayer = library.getPlayerData()
        testPlayer.isShuffle = true
        testShuffledPlaylist = testPlayer.contextQueue
        testPlayer.isShuffle = false
        testNormalPlaylist = testPlayer.contextQueue
        testQueueHandler = PlayQueueHandler(playerData: testPlayer)
    }

    override func tearDown() {
    }
    
    func prepareNoWaitingQueuePlaying() {
        testPlayer.removeAllItems()
        fillPlayerWithSomeSongsAndWaitingQueue()
        testPlayer.isUserQueuePlaying = false
    }
    
    func prepareWithWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.isUserQueuePlaying = true
    }
    
    func fillPlayerWithSomeSongs() {
        for i in 0...fillCount-1 {
            guard let song = library.getSong(id: cdHelper.seeder.songs[i].id) else { XCTFail(); return }
            testPlayer.appendContextQueue(playables: [song])
        }
    }
    
    func fillPlayerWithSomeSongsAndWaitingQueue() {
        fillPlayerWithSomeSongs()
        for i in 0...3 {
            guard let song = library.getSong(id: cdHelper.seeder.songs[fillCount+i].id) else { XCTFail(); return }
            testPlayer.appendUserQueue(playables: [song])
        }
    }

    func checkCorrectDefaultPlaylist() {
        for i in 0...fillCount-1 {
            checkPlaylistIndexEqualSeedIndex(playlistIndex: i, seedIndex: i)
        }
    }
    
    func checkPlaylistIndexEqualSeedIndex(playlistIndex: Int, seedIndex: Int) {
        guard let song = library.getSong(id: cdHelper.seeder.songs[seedIndex].id) else { XCTFail(); return }
        XCTAssertEqual(testPlayer.contextQueue.playables[playlistIndex].id, song.id)
    }
    
    func checkQueueItems(queue: [AbstractPlayable], seedIds: [Int]) {
        XCTAssertEqual(queue.count, seedIds.count)
        if queue.count == seedIds.count, queue.count > 0 {
            for i in 0...queue.count-1 {
                guard let song = library.getSong(id: cdHelper.seeder.songs[seedIds[i]].id) else { XCTFail(); return }
                let queueId = queue[i].id
                let songId = song.id
                XCTAssertEqual(queueId, songId)
            }
        }
    }
    
    func checkCurrentlyPlaying(idToBe: Int?) {
        if let idToBe = idToBe {
            guard let song = library.getSong(id: cdHelper.seeder.songs[idToBe].id) else { XCTFail(); return }
            XCTAssertEqual(testQueueHandler.currentlyPlaying?.id, song.id)
        } else {
            XCTAssertNil(testQueueHandler.currentlyPlaying)
        }
    }
    var song9: AbstractPlayable { return library.getSong(id: cdHelper.seeder.songs[9].id)! }
    var songA: AbstractPlayable { return library.getSong(id: cdHelper.seeder.songs[10].id)! }
    var songB: AbstractPlayable { return library.getSong(id: cdHelper.seeder.songs[11].id)! }
    var songC: AbstractPlayable { return library.getSong(id: cdHelper.seeder.songs[12].id)! }
    var songD: AbstractPlayable { return library.getSong(id: cdHelper.seeder.songs[13].id)! }
    var songE: AbstractPlayable { return library.getSong(id: cdHelper.seeder.songs[14].id)! }
    var songF: AbstractPlayable { return library.getSong(id: cdHelper.seeder.songs[15].id)! }
    
    func testCreation() {
        XCTAssertEqual(testQueueHandler.prevQueue, [AbstractPlayable]())
        XCTAssertEqual(testQueueHandler.userQueue, [AbstractPlayable]())
        XCTAssertEqual(testQueueHandler.nextQueue, [AbstractPlayable]())
        XCTAssertEqual(testQueueHandler.currentlyPlaying, nil)
    }
    
    func testAddToWaitingQueueToEmptyPlayerStartsPlaying() {
        guard let song = library.getSong(id: cdHelper.seeder.songs[5].id) else { XCTFail(); return }
        testQueueHandler.insertUserQueue(playables: [song])
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
    }
    
    func testRemoveSongFromPlaylist() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
        XCTAssertEqual(testPlayer.contextQueue.playables.count, fillCount-1)
        XCTAssertEqual(testPlayer.currentIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        
        testPlayer.currentIndex = 3
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
        XCTAssertEqual(testPlayer.contextQueue.playables.count, fillCount-2)
        XCTAssertEqual(testPlayer.currentIndex, 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 1))
        XCTAssertEqual(testPlayer.contextQueue.playables.count, fillCount-3)
        XCTAssertEqual(testPlayer.currentIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 4)
        
        testPlayer.removeAllItems()
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 10))
        XCTAssertEqual(testPlayer.contextQueue.playables.count, 0)
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 10))
        XCTAssertEqual(testPlayer.contextQueue.playables.count, 0)
    }
    
    func testWaitingQueueInsertFirst_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        guard let song = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        testPlayer.currentIndex = 2
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        testPlayer.insertUserQueue(playables: [song])
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [1, 5, 6, 7, 8])
    }
    
    func testWaitingQueueInsertFirst_noWaitingQueuePlaying2() {
        prepareNoWaitingQueuePlaying()
        guard let song = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        testPlayer.currentIndex = 2
        checkCurrentlyPlaying(idToBe: 2)
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [])
        testPlayer.insertUserQueue(playables: [song])
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [1])
    }
    
    func testWaitingQueueInsertFirst_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        guard let song = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        testPlayer.currentIndex = 2
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        testPlayer.insertUserQueue(playables: [song])
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [1, 6, 7, 8])
    }
    
    func testWaitingQueueInsertFirst_withWaitingQueuePlaying2() {
        prepareWithWaitingQueuePlaying()
        guard let song = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        testPlayer.currentIndex = 2
        checkCurrentlyPlaying(idToBe: 5)
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [])
        testPlayer.insertUserQueue(playables: [song])
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [1])
    }
    
    func testWaitingQueueInsertLast_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        guard let song = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        testPlayer.currentIndex = 2
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        testPlayer.appendUserQueue(playables: [song])
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8, 1])
    }
    
    func testWaitingQueueInsertLast_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        guard let song = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        testPlayer.currentIndex = 2
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        testPlayer.appendUserQueue(playables: [song])
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8, 1])
    }
    
    func testMovePlaylistSong_InvalidValues() {
        prepareNoWaitingQueuePlaying()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0), to: PlayerIndex(queueType: .prev, index: 5))
        checkCorrectDefaultPlaylist()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0), to: PlayerIndex(queueType: .prev, index: 20))
        checkCorrectDefaultPlaylist()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 5), to: PlayerIndex(queueType: .prev, index: 0))
        checkCorrectDefaultPlaylist()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 20), to: PlayerIndex(queueType: .prev, index: 0))
        checkCorrectDefaultPlaylist()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 1), to: PlayerIndex(queueType: .next, index: 5))
        checkCorrectDefaultPlaylist()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1), to: PlayerIndex(queueType: .prev, index: 1))
        checkCorrectDefaultPlaylist()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1), to: PlayerIndex(queueType: .prev, index: -1))
        checkCorrectDefaultPlaylist()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 1), to: PlayerIndex(queueType: .prev, index: -20))
        checkCorrectDefaultPlaylist()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1), to: PlayerIndex(queueType: .next, index: 1))
        checkCorrectDefaultPlaylist()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 4), to: PlayerIndex(queueType: .prev, index: 4))
        checkCorrectDefaultPlaylist()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: -1), to: PlayerIndex(queueType: .next, index: 30))
        checkCorrectDefaultPlaylist()
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 30), to: PlayerIndex(queueType: .prev, index: -9))
        checkCorrectDefaultPlaylist()
    }
    
    func testMovePlaylistSong() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1), to: PlayerIndex(queueType: .next, index: 1))
        XCTAssertEqual(testPlayer.currentIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0), to: PlayerIndex(queueType: .next, index: 1))
        XCTAssertEqual(testPlayer.currentIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 3), to: PlayerIndex(queueType: .next, index: 4))
        XCTAssertEqual(testPlayer.currentIndex, 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
        testPlayer.removeAllItems()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 2), to: PlayerIndex(queueType: .next, index: 3))
        XCTAssertEqual(testPlayer.currentIndex, 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0), to: PlayerIndex(queueType: .next, index: 1))
        XCTAssertEqual(testPlayer.currentIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0), to: PlayerIndex(queueType: .prev, index: 2))
        XCTAssertEqual(testPlayer.currentIndex, 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0), to: PlayerIndex(queueType: .prev, index: 1))
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 2), to: PlayerIndex(queueType: .next, index: 0))
        XCTAssertEqual(testPlayer.currentIndex, 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 2)
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 3), to: PlayerIndex(queueType: .prev, index: 0))
        XCTAssertEqual(testPlayer.currentIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
    }
    
    func testQueueCreation_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        testPlayer.currentIndex = 2
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        testPlayer.currentIndex = 3
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        testPlayer.currentIndex = 4
        checkCurrentlyPlaying(idToBe: 4)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
    }
    
    func testQueueCreation_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [0, 1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        testPlayer.currentIndex = 0
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        testPlayer.currentIndex = 2
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        testPlayer.currentIndex = 3
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        testPlayer.currentIndex = 4
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
    }
    
    func testRemovePlayable_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 3))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7])
    }
    
    func testRemovePlayable_noWaitingQueuePlaying_edgeCases() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 1)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 3))
        checkCurrentlyPlaying(idToBe: 4)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
    }
    
    func testRemovePlayable_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 2))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 2))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7])
    }
    
    func testRemovePlayable_withWaitingQueuePlaying_edgeCases() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 4))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 2))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 2))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 1))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 1))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 2))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
    }
    
    func testMove_PrevPrev_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 2))
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 2, 0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 2),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [2, 0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 3),
                                      to: PlayerIndex(queueType: .prev, index: 2))
        checkCurrentlyPlaying(idToBe: 4)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 3, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 3),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 4)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [3, 0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
    }
    
    func testMove_PrevPrev_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 0, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 3))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 2, 3, 0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 3),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [3, 0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 3),
                                      to: PlayerIndex(queueType: .prev, index: 2))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 3, 2, 4])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 4),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [4, 0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
    }
    
    func testMove_NextNext_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 2))
        checkCurrentlyPlaying(idToBe: 1)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4, 2])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 2),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 1)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 2, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 3),
                                      to: PlayerIndex(queueType: .next, index: 2))
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 4, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 3),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
    }
    func testMove_NextNext_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 2))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4, 2])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 2),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 2, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 3),
                                      to: PlayerIndex(queueType: .next, index: 2))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 4, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 4),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 3))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 0, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
    }
    func testMove_WaitWait_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 5, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 5, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 2))
        checkCurrentlyPlaying(idToBe: 1)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 5, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 2),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 1)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7, 5, 6, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 3),
                                      to: PlayerIndex(queueType: .user, index: 2))
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 8, 7])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 3),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [8, 5, 6, 7])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 3),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 4)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [8, 5, 6, 7])
    }
    func testMove_WaitWait_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7, 6, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7, 6, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 2))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7, 8, 6])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 2),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [8, 6, 7])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7, 6, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [0, 1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7, 6, 8])
    }
    
    func testMove_PrevNext_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 0, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 2))
        checkCurrentlyPlaying(idToBe: 1)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 0, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 1])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 4)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
    }
    func testMove_PrevNext_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 0, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 3),
                                      to: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
    }
    func testMove_NextPrev_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 3, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [4, 0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 2))
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 4, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 1)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [3, 0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 1)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 3),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
    }
    func testMove_NextPrev_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 3, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [4, 0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [3, 0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 4))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 3))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 4, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 3),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [4, 0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 3),
                                      to: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 4])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 4),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
    }

    func testMove_WaitNext_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 5, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [6, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 3),
                                      to: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 8])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 4)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [6])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 8])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [8, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 2),
                                      to: PlayerIndex(queueType: .next, index: 4))
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4, 7])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 2),
                                      to: PlayerIndex(queueType: .next, index: 3))
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 7, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 8])
    }
    func testMove_WaitNext_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 6, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [7, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 2),
                                      to: PlayerIndex(queueType: .next, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4, 8])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [7])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [8, 0, 1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .next, index: 5))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [0, 1, 2, 3, 4, 8])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .next, index: 3))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [0, 1, 2, 8, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 2),
                                      to: PlayerIndex(queueType: .next, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [8, 1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7])
    }
    func testMove_WaitPrev_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 5, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [6, 0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 3),
                                      to: PlayerIndex(queueType: .prev, index: 2))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 8])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 4)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [6, 0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [8])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
    }
    func testMove_WaitPrev_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 6, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [7, 0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 2),
                                      to: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 8, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [7, 0, 1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 2),
                                      to: PlayerIndex(queueType: .prev, index: 5))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3, 4, 8])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 4))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3, 7, 4])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 0),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [8])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [0, 1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 1),
                                      to: PlayerIndex(queueType: .prev, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 8, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [7])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .user, index: 2),
                                      to: PlayerIndex(queueType: .prev, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [8, 0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7])
    }

    func testMove_PrevWait_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 0, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [1, 5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 2),
                                      to: PlayerIndex(queueType: .user, index: 2))
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 2, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 4))
        checkCurrentlyPlaying(idToBe: 4)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8, 0])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 1)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [0])
    }
    func testMove_PrevWait_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 0, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0,  2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [1, 6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 2),
                                      to: PlayerIndex(queueType: .user, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 2, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 4),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [4, 6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 4
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 4),
                                      to: PlayerIndex(queueType: .user, index: 3))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8, 4])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [0, 6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .prev, index: 1),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [1])
    }
    func testMove_NextWait_noWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 1))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 3, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 1),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [4, 5, 6, 7, 8])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 2))
        checkCurrentlyPlaying(idToBe: 3)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 4, 7, 8])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 2),
                                      to: PlayerIndex(queueType: .user, index: 4))
        checkCurrentlyPlaying(idToBe: 1)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8, 4])
        
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 1)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [2])

        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 0)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [1, 6, 7, 8])
    }
    func testMove_NextWait_withWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 3, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 1),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [4, 6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 2),
                                      to: PlayerIndex(queueType: .user, index: 1))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [2, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 4, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 0
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 3),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [4, 6, 7, 8])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 3
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 3))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2, 3])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8, 4])

        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [0, 6, 7, 8])
        
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = -1
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
        testQueueHandler.movePlayable(from: PlayerIndex(queueType: .next, index: 0),
                                      to: PlayerIndex(queueType: .user, index: 0))
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [1, 2, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [0])
    }
    
    func testInsertPodcastQueue_playerModeMusic_NoWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())

        testPlayer.insertPodcastQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9])
        
        testPlayer.insertPodcastQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10])

        testPlayer.insertPodcastQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 11, 10])
        
        testPlayer.insertPodcastQueue(playables: [songC])
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 12, 11, 10])
    }
    func testAppendPodcastQueue_playerModeMusic_NoWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2

        testPlayer.appendPodcastQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9])
        
        testPlayer.appendPodcastQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10])
        
        testPlayer.appendPodcastQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10, 11])

        testPlayer.appendPodcastQueue(playables: [songC])
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10, 11, 12])
    }
    func testInsertContextQueue_playerModePodcast_NoWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testPlayer.playerMode = .podcast
        
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])

        testPlayer.insertContextQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 9, 3, 4])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [9, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast

        testPlayer.insertContextQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 10, 9, 3, 4])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [10, 9, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast
        
        testPlayer.insertContextQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 11, 10, 9, 3, 4])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [11, 10, 9, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast
    }
    func testAppendContextQueue_playerModePodcast_NoWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testPlayer.playerMode = .podcast
        
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])

        testPlayer.appendContextQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4, 9])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4, 9])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast

        testPlayer.appendContextQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4, 9, 10])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4, 9, 10])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast
        
        testPlayer.appendContextQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4, 9, 10, 11])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4, 9, 10, 11])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast
    }
    func testInsertUserQueue_playerModePodcast_NoWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testPlayer.playerMode = .podcast
        
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])

        testPlayer.insertUserQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [9, 5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast

        testPlayer.insertUserQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [10, 9, 5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast
        
        testPlayer.insertUserQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [11, 10, 9, 5, 6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast
    }
    func testAppendUserQueue_playerModePodcast_NoWaitingQueuePlaying() {
        prepareNoWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        testPlayer.playerMode = .podcast
        
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])

        testPlayer.appendUserQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8, 9])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast

        testPlayer.appendUserQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8, 9, 10])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast
        
        testPlayer.appendUserQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: nil)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [Int]())
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 2)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [5, 6, 7, 8, 9, 10, 11])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
        testPlayer.playerMode = .podcast
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    func testInsertPodcastQueue_playerModeMusic_WithWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())

        testPlayer.insertPodcastQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9])
        
        testPlayer.insertPodcastQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10])

        testPlayer.insertPodcastQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 11, 10])
        
        testPlayer.insertPodcastQueue(playables: [songC])
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 12, 11, 10])
    }
    func testAppendPodcastQueue_playerModeMusic_WithWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2

        testPlayer.appendPodcastQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9])
        
        testPlayer.appendPodcastQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10])
        
        testPlayer.appendPodcastQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10, 11])

        testPlayer.appendPodcastQueue(playables: [songC])
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10, 11, 12])
    }
    func testInsertContextQueue_playerModePodcast_WithWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        
        testPlayer.playerMode = .podcast
        testPlayer.insertPodcastQueue(playables: [songD, songE, songF])
        testPlayer.currentIndex = 1
        
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())

        testPlayer.insertContextQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [9, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        testPlayer.playerMode = .podcast

        testPlayer.insertContextQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [10, 9, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        testPlayer.playerMode = .podcast
        
        testPlayer.insertContextQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 11, 10, 9, 3, 4])
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [11, 10, 9, 3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        testPlayer.playerMode = .podcast
    }
    func testAppendContextQueue_playerModePodcast_WithWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        
        testPlayer.playerMode = .podcast
        testPlayer.insertPodcastQueue(playables: [songD, songE, songF])
        testPlayer.currentIndex = 1
        
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())

        testPlayer.appendContextQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4, 9])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        testPlayer.playerMode = .podcast

        testPlayer.appendContextQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4, 9, 10])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        testPlayer.playerMode = .podcast
        
        testPlayer.appendContextQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4, 9, 10, 11])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8])
        testPlayer.playerMode = .podcast
    }
    func testInsertUserQueue_playerModePodcast_WithWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        
        testPlayer.playerMode = .podcast
        testPlayer.insertPodcastQueue(playables: [songD, songE, songF])
        testPlayer.currentIndex = 1
        
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())

        testPlayer.insertUserQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [9, 6, 7, 8])
        testPlayer.playerMode = .podcast

        testPlayer.insertUserQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [10, 9, 6, 7, 8])
        testPlayer.playerMode = .podcast
        
        testPlayer.insertUserQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [11, 10, 9, 6, 7, 8])
        testPlayer.playerMode = .podcast
    }
    func testAppendUserQueue_playerModePodcast_WithWaitingQueuePlaying() {
        prepareWithWaitingQueuePlaying()
        testPlayer.currentIndex = 2
        
        testPlayer.playerMode = .podcast
        testPlayer.insertPodcastQueue(playables: [songD, songE, songF])
        testPlayer.currentIndex = 1
        
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())

        testPlayer.appendUserQueue(playables: [song9])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8, 9])
        testPlayer.playerMode = .podcast

        testPlayer.appendUserQueue(playables: [songA])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8, 9, 10])
        testPlayer.playerMode = .podcast
        
        testPlayer.appendUserQueue(playables: [songB])
        checkCurrentlyPlaying(idToBe: 14)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [13])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [15])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [Int]())
        testPlayer.playerMode = .music
        checkCurrentlyPlaying(idToBe: 5)
        checkQueueItems(queue: testQueueHandler.prevQueue, seedIds: [0, 1, 2])
        checkQueueItems(queue: testQueueHandler.nextQueue, seedIds: [3, 4])
        checkQueueItems(queue: testQueueHandler.userQueue, seedIds: [6, 7, 8, 9, 10, 11])
        testPlayer.playerMode = .podcast
    }
}
