import XCTest
@testable import Amperfy

class PlayerDataTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var testPlayer: PlayerData!
    var testNormalPlaylist: Playlist!
    var testShuffledPlaylist: Playlist!
    let fillCount = 5

    override func setUp() {
        cdHelper = CoreDataHelper()
        library = cdHelper.createSeededStorage()
        testPlayer = library.getPlayerData()
        testPlayer.isShuffle = true
        testShuffledPlaylist = testPlayer.playlist
        testPlayer.isShuffle = false
        testNormalPlaylist = testPlayer.playlist
    }

    override func tearDown() {
    }
    
    func fillPlayerWithSomeSongs() {
        for i in 0...fillCount-1 {
            guard let song = library.getSong(id: cdHelper.seeder.songs[i].id) else { XCTFail(); return }
            testPlayer.addToPlaylist(playable: song)
        }
    }
    
    func checkCorrectDefaultPlaylist() {
        for i in 0...fillCount-1 {
            checkPlaylistIndexEqualSeedIndex(playlistIndex: i, seedIndex: i)
        }
    }
    
    func checkPlaylistIndexEqualSeedIndex(playlistIndex: Int, seedIndex: Int) {
        guard let song = library.getSong(id: cdHelper.seeder.songs[seedIndex].id) else { XCTFail(); return }
        XCTAssertEqual(testPlayer.playlist.playables[playlistIndex].id, song.id)
    }
    
    func testCreation() {
        XCTAssertNotEqual(testNormalPlaylist, testShuffledPlaylist)
        XCTAssertEqual(testPlayer.playlist, testNormalPlaylist)
        XCTAssertEqual(testPlayer.currentItem, nil)
        XCTAssertEqual(testPlayer.currentPlaylistItem, nil)
        XCTAssertFalse(testPlayer.isShuffle)
        XCTAssertEqual(testPlayer.repeatMode, RepeatMode.off)
        XCTAssertEqual(testPlayer.currentIndex, 0)
        XCTAssertEqual(testPlayer.previousIndex, nil)
        XCTAssertEqual(testPlayer.nextIndex, nil)
        XCTAssertEqual(testNormalPlaylist.playables.count, 0)
        XCTAssertEqual(testShuffledPlaylist.playables.count, 0)
    }
    
    func testPlaylist() {
        fillPlayerWithSomeSongs()
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount)
        checkCorrectDefaultPlaylist()
    }
    
    func testCurrentSong() {
        fillPlayerWithSomeSongs()
        
        for i in [3,2,4,1,0] {
            guard let song = library.getSong(id: cdHelper.seeder.songs[i].id) else { XCTFail(); return }
            testPlayer.currentIndex = i
            XCTAssertEqual(testPlayer.currentItem?.id, song.id)
            XCTAssertEqual(testPlayer.currentPlaylistItem?.playable?.id, song.id)
            XCTAssertEqual(testPlayer.currentPlaylistItem?.order, i)
        }
    }
    
    func testShuffle() {
        testPlayer.isShuffle = true
        XCTAssertTrue(testPlayer.isShuffle)
        XCTAssertEqual(testPlayer.playlist, testShuffledPlaylist)
        testPlayer.isShuffle = false
        XCTAssertFalse(testPlayer.isShuffle)
        XCTAssertEqual(testPlayer.playlist, testNormalPlaylist)
        testPlayer.isShuffle = true
        XCTAssertEqual(testPlayer.playlist, testShuffledPlaylist)
        
        fillPlayerWithSomeSongs()
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount)
        testPlayer.isShuffle = false
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount)
        checkCorrectDefaultPlaylist()
        testPlayer.isShuffle = true
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount)
        testPlayer.isShuffle = false
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount)
        checkCorrectDefaultPlaylist()
        testPlayer.isShuffle = true
    }
    
    func testRepeat() {
        testPlayer.repeatMode = RepeatMode.all
        XCTAssertEqual(testPlayer.repeatMode, RepeatMode.all)
        testPlayer.repeatMode = RepeatMode.single
        XCTAssertEqual(testPlayer.repeatMode, RepeatMode.single)
        testPlayer.repeatMode = RepeatMode.off
        XCTAssertEqual(testPlayer.repeatMode, RepeatMode.off)
    }
    
    func testCurrentSongIndexSet() {
        fillPlayerWithSomeSongs()
        let curIndex = 2
        testPlayer.currentIndex = curIndex
        XCTAssertEqual(testPlayer.currentIndex, curIndex)
        testPlayer.currentIndex = -1
        XCTAssertEqual(testPlayer.currentIndex, 0)
        testPlayer.currentIndex = -10
        XCTAssertEqual(testPlayer.currentIndex, 0)
        testPlayer.currentIndex = fillCount-1
        XCTAssertEqual(testPlayer.currentIndex, fillCount-1)
        testPlayer.currentIndex = fillCount
        XCTAssertEqual(testPlayer.currentIndex, 0)
        testPlayer.currentIndex = 100
        XCTAssertEqual(testPlayer.currentIndex, 0)
    }
    
    func testPreviousSongIndex() {
        fillPlayerWithSomeSongs()
        testPlayer.currentIndex = 0
        XCTAssertEqual(testPlayer.previousIndex, nil)
        testPlayer.currentIndex = 1
        XCTAssertEqual(testPlayer.previousIndex, 0)
        testPlayer.currentIndex = 4
        XCTAssertEqual(testPlayer.previousIndex, 3)
        testPlayer.currentIndex = fillCount-1
        XCTAssertEqual(testPlayer.previousIndex, fillCount-2)
        testPlayer.removeAllItems()
        XCTAssertEqual(testPlayer.previousIndex, nil)
    }
    
    func testNextSongIndex() {
        fillPlayerWithSomeSongs()
        testPlayer.currentIndex = 0
        XCTAssertEqual(testPlayer.nextIndex, 1)
        testPlayer.currentIndex = 1
        XCTAssertEqual(testPlayer.nextIndex, 2)
        testPlayer.currentIndex = fillCount-2
        XCTAssertEqual(testPlayer.nextIndex, fillCount-1)
        testPlayer.currentIndex = fillCount-1
        XCTAssertEqual(testPlayer.nextIndex, nil)
        testPlayer.removeAllItems()
        XCTAssertEqual(testPlayer.nextIndex, nil)
    }
    
    func testAddToPlaylist() {
        fillPlayerWithSomeSongs()
        guard let song1 = library.getSong(id: cdHelper.seeder.songs[6].id) else { XCTFail(); return }
        guard let song2 = library.getSong(id: cdHelper.seeder.songs[7].id) else { XCTFail(); return }
        testPlayer.addToPlaylist(playable: song1)
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount + 1)
        testPlayer.isShuffle = true
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount + 1)
        testPlayer.addToPlaylist(playable: song2)
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount + 2)
        testPlayer.isShuffle = false
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount + 2)
        XCTAssertEqual(testPlayer.playlist.playables[fillCount].id, song1.id)
        XCTAssertEqual(testPlayer.playlist.playables[fillCount + 1].id, song2.id)
    }
    
    func testRemoveAllSongs() {
        fillPlayerWithSomeSongs()
        testPlayer.currentIndex = 3
        XCTAssertEqual(testPlayer.currentIndex, 3)
        testPlayer.removeAllItems()
        XCTAssertEqual(testPlayer.currentIndex, 0)
        XCTAssertEqual(testPlayer.playlist.playables.count, 0)
        
        guard let song1 = library.getSong(id: cdHelper.seeder.songs[6].id) else { XCTFail(); return }
        guard let song2 = library.getSong(id: cdHelper.seeder.songs[7].id) else { XCTFail(); return }
        testPlayer.addToPlaylist(playable: song1)
        testPlayer.addToPlaylist(playable: song2)
        testPlayer.removeAllItems()
        XCTAssertEqual(testPlayer.playlist.playables.count, 0)
    }
    
    func testRemoveSongFromPlaylist() {
        fillPlayerWithSomeSongs()
        testPlayer.currentIndex = 1
        testPlayer.removeItemFromPlaylist(at: 2)
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount-1)
        XCTAssertEqual(testPlayer.currentIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        
        testPlayer.currentIndex = 3
        testPlayer.removeItemFromPlaylist(at: 0)
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount-2)
        XCTAssertEqual(testPlayer.currentIndex, 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        
        testPlayer.currentIndex = 2
        testPlayer.removeItemFromPlaylist(at: 1)
        XCTAssertEqual(testPlayer.playlist.playables.count, fillCount-3)
        XCTAssertEqual(testPlayer.currentIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 4)
        
        testPlayer.removeAllItems()
        testPlayer.removeItemFromPlaylist(at: 10)
        XCTAssertEqual(testPlayer.playlist.playables.count, 0)
        testPlayer.removeItemFromPlaylist(at: 0)
        XCTAssertEqual(testPlayer.playlist.playables.count, 0)
    }
    
    func testMovePlaylistSong_InvalidValues() {
        fillPlayerWithSomeSongs()
        
        testPlayer.movePlaylistItem(fromIndex: 0, to: 5)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistItem(fromIndex: 0, to: 20)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistItem(fromIndex: 5, to: 0)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistItem(fromIndex: 20, to: 0)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistItem(fromIndex: -1, to: 2)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistItem(fromIndex: -9, to: 1)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistItem(fromIndex: 1, to: -1)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistItem(fromIndex: 1, to: -20)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistItem(fromIndex: 1, to: 1)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistItem(fromIndex: 4, to: 4)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistItem(fromIndex: -5, to: 30)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistItem(fromIndex: 30, to: -9)
        checkCorrectDefaultPlaylist()
    }
    
    func testMovePlaylistSong() {
        fillPlayerWithSomeSongs()
        
        testPlayer.currentIndex = 2
        testPlayer.movePlaylistItem(fromIndex: 1, to: 4)
        XCTAssertEqual(testPlayer.currentIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 1)
        
        testPlayer.removeAllItems()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentIndex = 1
        testPlayer.movePlaylistItem(fromIndex: 2, to: 3)
        XCTAssertEqual(testPlayer.currentIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
        
        testPlayer.removeAllItems()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentIndex = 2
        testPlayer.movePlaylistItem(fromIndex: 2, to: 4)
        XCTAssertEqual(testPlayer.currentIndex, 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 2)
        
        testPlayer.removeAllItems()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentIndex = 4
        testPlayer.movePlaylistItem(fromIndex: 0, to: 3)
        XCTAssertEqual(testPlayer.currentIndex, 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
        
        testPlayer.removeAllItems()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentIndex = 4
        testPlayer.movePlaylistItem(fromIndex: 4, to: 2)
        XCTAssertEqual(testPlayer.currentIndex, 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
        
        testPlayer.removeAllItems()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentIndex = 3
        testPlayer.movePlaylistItem(fromIndex: 4, to: 1)
        XCTAssertEqual(testPlayer.currentIndex, 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
        
        testPlayer.removeAllItems()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentIndex = 1
        testPlayer.movePlaylistItem(fromIndex: 3, to: 1)
        XCTAssertEqual(testPlayer.currentIndex, 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
        
        testPlayer.removeAllItems()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentIndex = 1
        testPlayer.movePlaylistItem(fromIndex: 4, to: 2)
        XCTAssertEqual(testPlayer.currentIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
    }

}
