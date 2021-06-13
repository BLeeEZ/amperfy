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
            testPlayer.addToPlaylist(song: song)
        }
    }
    
    func checkCorrectDefaultPlaylist() {
        for i in 0...fillCount-1 {
            checkPlaylistIndexEqualSeedIndex(playlistIndex: i, seedIndex: i)
        }
    }
    
    func checkPlaylistIndexEqualSeedIndex(playlistIndex: Int, seedIndex: Int) {
        guard let song = library.getSong(id: cdHelper.seeder.songs[seedIndex].id) else { XCTFail(); return }
        XCTAssertEqual(testPlayer.playlist.songs[playlistIndex].id, song.id)
    }
    
    func testCreation() {
        XCTAssertNotEqual(testNormalPlaylist, testShuffledPlaylist)
        XCTAssertEqual(testPlayer.playlist, testNormalPlaylist)
        XCTAssertEqual(testPlayer.currentSong, nil)
        XCTAssertEqual(testPlayer.currentPlaylistItem, nil)
        XCTAssertFalse(testPlayer.isShuffle)
        XCTAssertEqual(testPlayer.repeatMode, RepeatMode.off)
        XCTAssertEqual(testPlayer.currentSongIndex, 0)
        XCTAssertEqual(testPlayer.previousSongIndex, nil)
        XCTAssertEqual(testPlayer.nextSongIndex, nil)
        XCTAssertEqual(testNormalPlaylist.songs.count, 0)
        XCTAssertEqual(testShuffledPlaylist.songs.count, 0)
    }
    
    func testPlaylist() {
        fillPlayerWithSomeSongs()
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount)
        checkCorrectDefaultPlaylist()
    }
    
    func testCurrentSong() {
        fillPlayerWithSomeSongs()
        
        for i in [3,2,4,1,0] {
            guard let song = library.getSong(id: cdHelper.seeder.songs[i].id) else { XCTFail(); return }
            testPlayer.currentSongIndex = i
            XCTAssertEqual(testPlayer.currentSong?.id, song.id)
            XCTAssertEqual(testPlayer.currentPlaylistItem?.song?.id, song.id)
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
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount)
        testPlayer.isShuffle = false
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount)
        checkCorrectDefaultPlaylist()
        testPlayer.isShuffle = true
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount)
        testPlayer.isShuffle = false
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount)
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
        testPlayer.currentSongIndex = curIndex
        XCTAssertEqual(testPlayer.currentSongIndex, curIndex)
        testPlayer.currentSongIndex = -1
        XCTAssertEqual(testPlayer.currentSongIndex, 0)
        testPlayer.currentSongIndex = -10
        XCTAssertEqual(testPlayer.currentSongIndex, 0)
        testPlayer.currentSongIndex = fillCount-1
        XCTAssertEqual(testPlayer.currentSongIndex, fillCount-1)
        testPlayer.currentSongIndex = fillCount
        XCTAssertEqual(testPlayer.currentSongIndex, 0)
        testPlayer.currentSongIndex = 100
        XCTAssertEqual(testPlayer.currentSongIndex, 0)
    }
    
    func testPreviousSongIndex() {
        fillPlayerWithSomeSongs()
        testPlayer.currentSongIndex = 0
        XCTAssertEqual(testPlayer.previousSongIndex, nil)
        testPlayer.currentSongIndex = 1
        XCTAssertEqual(testPlayer.previousSongIndex, 0)
        testPlayer.currentSongIndex = 4
        XCTAssertEqual(testPlayer.previousSongIndex, 3)
        testPlayer.currentSongIndex = fillCount-1
        XCTAssertEqual(testPlayer.previousSongIndex, fillCount-2)
        testPlayer.removeAllSongs()
        XCTAssertEqual(testPlayer.previousSongIndex, nil)
    }
    
    func testNextSongIndex() {
        fillPlayerWithSomeSongs()
        testPlayer.currentSongIndex = 0
        XCTAssertEqual(testPlayer.nextSongIndex, 1)
        testPlayer.currentSongIndex = 1
        XCTAssertEqual(testPlayer.nextSongIndex, 2)
        testPlayer.currentSongIndex = fillCount-2
        XCTAssertEqual(testPlayer.nextSongIndex, fillCount-1)
        testPlayer.currentSongIndex = fillCount-1
        XCTAssertEqual(testPlayer.nextSongIndex, nil)
        testPlayer.removeAllSongs()
        XCTAssertEqual(testPlayer.nextSongIndex, nil)
    }
    
    func testAddToPlaylist() {
        fillPlayerWithSomeSongs()
        guard let song1 = library.getSong(id: cdHelper.seeder.songs[6].id) else { XCTFail(); return }
        guard let song2 = library.getSong(id: cdHelper.seeder.songs[7].id) else { XCTFail(); return }
        testPlayer.addToPlaylist(song: song1)
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount + 1)
        testPlayer.isShuffle = true
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount + 1)
        testPlayer.addToPlaylist(song: song2)
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount + 2)
        testPlayer.isShuffle = false
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount + 2)
        XCTAssertEqual(testPlayer.playlist.songs[fillCount].id, song1.id)
        XCTAssertEqual(testPlayer.playlist.songs[fillCount + 1].id, song2.id)
    }
    
    func testRemoveAllSongs() {
        fillPlayerWithSomeSongs()
        testPlayer.currentSongIndex = 3
        XCTAssertEqual(testPlayer.currentSongIndex, 3)
        testPlayer.removeAllSongs()
        XCTAssertEqual(testPlayer.currentSongIndex, 0)
        XCTAssertEqual(testPlayer.playlist.songs.count, 0)
        
        guard let song1 = library.getSong(id: cdHelper.seeder.songs[6].id) else { XCTFail(); return }
        guard let song2 = library.getSong(id: cdHelper.seeder.songs[7].id) else { XCTFail(); return }
        testPlayer.addToPlaylist(song: song1)
        testPlayer.addToPlaylist(song: song2)
        testPlayer.removeAllSongs()
        XCTAssertEqual(testPlayer.playlist.songs.count, 0)
    }
    
    func testRemoveSongFromPlaylist() {
        fillPlayerWithSomeSongs()
        testPlayer.currentSongIndex = 1
        testPlayer.removeSongFromPlaylist(at: 2)
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount-1)
        XCTAssertEqual(testPlayer.currentSongIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        
        testPlayer.currentSongIndex = 3
        testPlayer.removeSongFromPlaylist(at: 0)
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount-2)
        XCTAssertEqual(testPlayer.currentSongIndex, 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        
        testPlayer.currentSongIndex = 2
        testPlayer.removeSongFromPlaylist(at: 1)
        XCTAssertEqual(testPlayer.playlist.songs.count, fillCount-3)
        XCTAssertEqual(testPlayer.currentSongIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 4)
        
        testPlayer.removeAllSongs()
        testPlayer.removeSongFromPlaylist(at: 10)
        XCTAssertEqual(testPlayer.playlist.songs.count, 0)
        testPlayer.removeSongFromPlaylist(at: 0)
        XCTAssertEqual(testPlayer.playlist.songs.count, 0)
    }
    
    func testMovePlaylistSong_InvalidValues() {
        fillPlayerWithSomeSongs()
        
        testPlayer.movePlaylistSong(fromIndex: 0, to: 5)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistSong(fromIndex: 0, to: 20)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistSong(fromIndex: 5, to: 0)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistSong(fromIndex: 20, to: 0)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistSong(fromIndex: -1, to: 2)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistSong(fromIndex: -9, to: 1)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistSong(fromIndex: 1, to: -1)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistSong(fromIndex: 1, to: -20)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistSong(fromIndex: 1, to: 1)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistSong(fromIndex: 4, to: 4)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistSong(fromIndex: -5, to: 30)
        checkCorrectDefaultPlaylist()
        testPlayer.movePlaylistSong(fromIndex: 30, to: -9)
        checkCorrectDefaultPlaylist()
    }
    
    func testMovePlaylistSong() {
        fillPlayerWithSomeSongs()
        
        testPlayer.currentSongIndex = 2
        testPlayer.movePlaylistSong(fromIndex: 1, to: 4)
        XCTAssertEqual(testPlayer.currentSongIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 1)
        
        testPlayer.removeAllSongs()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentSongIndex = 1
        testPlayer.movePlaylistSong(fromIndex: 2, to: 3)
        XCTAssertEqual(testPlayer.currentSongIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
        
        testPlayer.removeAllSongs()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentSongIndex = 2
        testPlayer.movePlaylistSong(fromIndex: 2, to: 4)
        XCTAssertEqual(testPlayer.currentSongIndex, 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 2)
        
        testPlayer.removeAllSongs()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentSongIndex = 4
        testPlayer.movePlaylistSong(fromIndex: 0, to: 3)
        XCTAssertEqual(testPlayer.currentSongIndex, 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
        
        testPlayer.removeAllSongs()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentSongIndex = 4
        testPlayer.movePlaylistSong(fromIndex: 4, to: 2)
        XCTAssertEqual(testPlayer.currentSongIndex, 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
        
        testPlayer.removeAllSongs()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentSongIndex = 3
        testPlayer.movePlaylistSong(fromIndex: 4, to: 1)
        XCTAssertEqual(testPlayer.currentSongIndex, 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
        
        testPlayer.removeAllSongs()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentSongIndex = 1
        testPlayer.movePlaylistSong(fromIndex: 3, to: 1)
        XCTAssertEqual(testPlayer.currentSongIndex, 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
        
        testPlayer.removeAllSongs()
        fillPlayerWithSomeSongs()
        
        testPlayer.currentSongIndex = 1
        testPlayer.movePlaylistSong(fromIndex: 4, to: 2)
        XCTAssertEqual(testPlayer.currentSongIndex, 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
    }

}
