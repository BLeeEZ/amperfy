import XCTest
@testable import Amperfy

class PlaylistTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var testPlaylist: Playlist!
    var defaultPlaylist: Playlist!
    var playlistThreeCached: Playlist!
    var playlistNoCached: Playlist!

    override func setUp() {
        cdHelper = CoreDataHelper()
        library = cdHelper.createSeededStorage()
        guard let playlist = library.getPlaylist(id: cdHelper.seeder.playlists[0].id) else { XCTFail(); return }
        defaultPlaylist = playlist
        guard let playlistCached = library.getPlaylist(id: cdHelper.seeder.playlists[1].id) else { XCTFail(); return }
        playlistThreeCached = playlistCached
        guard let playlistZeroCached = library.getPlaylist(id: cdHelper.seeder.playlists[2].id) else { XCTFail(); return }
        playlistNoCached = playlistZeroCached
        testPlaylist = library.createPlaylist()
        resetTestPlaylist()
    }

    override func tearDown() {
    }
    
    func resetTestPlaylist() {
        testPlaylist.removeAllSongs()
        for i in 0...4 {
            guard let song = library.getSong(id: cdHelper.seeder.songs[i].id) else { XCTFail(); return }
            testPlaylist.append(song: song)
        }
    }
    
    func checkTestPlaylistNoChange() {
        for i in 0...4 {
            checkPlaylistIndexEqualSeedIndex(playlistIndex: i, seedIndex: i)
        }
    }
    
    func checkPlaylistIndexEqualSeedIndex(playlistIndex: Int, seedIndex: Int) {
        guard let song = library.getSong(id: cdHelper.seeder.songs[seedIndex].id) else { XCTFail(); return }
        XCTAssertEqual(testPlaylist.songs[playlistIndex].id, song.id)
    }
    
    func testCreation() {
        let playlist = library.createPlaylist()
        XCTAssertEqual(playlist.items.count, 0)
        XCTAssertEqual(playlist.id, "")
        XCTAssertEqual(playlist.lastSongIndex, 0)
        XCTAssertFalse(playlist.hasCachedSongs)
        
        let name = "Test 234"
        playlist.name = name
        XCTAssertEqual(playlist.name, name)
        
        let id = "12345"
        playlist.id = id
        XCTAssertEqual(playlist.id, id)
    }
    
    func testFetch() {
        let playlist = library.createPlaylist()
        let id = "12345"
        let name = "Test 234"
        playlist.name = name
        playlist.id = id
        guard let playlistFetched = library.getPlaylist(id: id) else { XCTFail(); return }
        XCTAssertEqual(playlistFetched.name, name)
        XCTAssertEqual(playlistFetched.id, id)
    }

    func testSongAppend() {
        let playlist = library.createPlaylist()
        XCTAssertEqual(playlist.items.count, 0)
        guard let song1 = library.getSong(id: cdHelper.seeder.songs[0].id) else { XCTFail(); return }
        playlist.append(song: song1)
        XCTAssertEqual(playlist.items.count, 1)
        guard let song2 = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        playlist.append(song: song2)
        XCTAssertEqual(playlist.items.count, 2)
        guard let song3 = library.getSong(id: cdHelper.seeder.songs[2].id) else { XCTFail(); return }
        playlist.append(song: song3)
        XCTAssertEqual(playlist.items.count, 3)
        
        for (index,entry) in playlist.items.enumerated() {
            XCTAssertEqual(entry.order, index)
            XCTAssertEqual(entry.song?.id, cdHelper.seeder.songs[index].id)
        }
    }
    
    func testDefaultPlaylist() {
        XCTAssertTrue(defaultPlaylist.hasCachedSongs)
        XCTAssertEqual(defaultPlaylist.songs.count, 5)
        XCTAssertEqual(defaultPlaylist.items.count, 5)
        XCTAssertEqual(defaultPlaylist.lastSongIndex, 4)
        XCTAssertEqual(defaultPlaylist.songs[0].id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[0].song!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[0].order, 0)
        XCTAssertEqual(defaultPlaylist.songs[1].id, cdHelper.seeder.songs[1].id)
        XCTAssertEqual(defaultPlaylist.items[1].song!.id, cdHelper.seeder.songs[1].id)
        XCTAssertEqual(defaultPlaylist.items[1].order, 1)
        XCTAssertEqual(defaultPlaylist.songs[2].id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[2].song!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[2].order, 2)
        XCTAssertEqual(defaultPlaylist.songs[3].id, cdHelper.seeder.songs[4].id)
        XCTAssertEqual(defaultPlaylist.items[3].song!.id, cdHelper.seeder.songs[4].id)
        XCTAssertEqual(defaultPlaylist.items[3].order, 3)
        XCTAssertEqual(defaultPlaylist.songs[4].id, cdHelper.seeder.songs[3].id)
        XCTAssertEqual(defaultPlaylist.items[4].song!.id, cdHelper.seeder.songs[3].id)
        XCTAssertEqual(defaultPlaylist.items[4].order, 4)
    }
    
    func testReorderLastToFirst() {
        defaultPlaylist.movePlaylistSong(fromIndex: 2, to: 0)
        XCTAssertEqual(defaultPlaylist.items[0].song!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[1].song!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[2].song!.id, cdHelper.seeder.songs[1].id)
    }
    
    func testReorderSecondToLast() {
        defaultPlaylist.movePlaylistSong(fromIndex: 1, to: 2)
        XCTAssertEqual(defaultPlaylist.items[0].song!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[1].song!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[2].song!.id, cdHelper.seeder.songs[1].id)
    }
    
    func testReorderNoChange() {
        defaultPlaylist.movePlaylistSong(fromIndex: 1, to: 1)
        XCTAssertEqual(defaultPlaylist.items[0].song!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[1].song!.id, cdHelper.seeder.songs[1].id)
        XCTAssertEqual(defaultPlaylist.items[2].song!.id, cdHelper.seeder.songs[2].id)
    }
    
    func testEntryRemoval() {
        defaultPlaylist.remove(at: 1)
        XCTAssertEqual(defaultPlaylist.items.count, cdHelper.seeder.playlists[0].songIds.count - 1)
        XCTAssertEqual(defaultPlaylist.items[0].song!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[0].order, 0)
        XCTAssertEqual(defaultPlaylist.items[1].song!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[1].order, 1)
    }
    
    func testRemoveFirstOccurrenceOfSong_Success() {
        guard let song1 = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        defaultPlaylist.append(song: song1)
        defaultPlaylist.remove(firstOccurrenceOfSong: song1)
        XCTAssertEqual(defaultPlaylist.items.count, cdHelper.seeder.playlists[0].songIds.count)
        XCTAssertEqual(defaultPlaylist.items[0].song!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[0].order, 0)
        XCTAssertEqual(defaultPlaylist.items[1].song!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[1].order, 1)
        XCTAssertEqual(defaultPlaylist.items[4].song!.id,song1.id)
        
        defaultPlaylist.remove(firstOccurrenceOfSong: song1)
        XCTAssertEqual(defaultPlaylist.items.count, cdHelper.seeder.playlists[0].songIds.count - 1)
        XCTAssertEqual(defaultPlaylist.items[0].song!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[0].order, 0)
        XCTAssertEqual(defaultPlaylist.items[1].song!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[1].order, 1)
        XCTAssertEqual(defaultPlaylist.items[3].song!.id, cdHelper.seeder.songs[3].id)
        XCTAssertEqual(defaultPlaylist.items[3].order, 3)
    }
    
    func testRemoveFirstOccurrenceOfSong_NoChange() {
        guard let song6 = library.getSong(id: cdHelper.seeder.songs[6].id) else { XCTFail(); return }
        defaultPlaylist.remove(firstOccurrenceOfSong: song6)
        testDefaultPlaylist()
    }
    
    func testRemovalAll() {
        defaultPlaylist.removeAllSongs()
        XCTAssertEqual(defaultPlaylist.items.count, 0)
    }
    
    func testGetFirstIndex() {
        guard let song0 = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        guard let foundSongIndex0 = defaultPlaylist.getFirstIndex(song: song0) else { XCTFail(); return }
        XCTAssertEqual(foundSongIndex0, 1)
        XCTAssertEqual(defaultPlaylist.items[foundSongIndex0].song!.id, song0.id)
        defaultPlaylist.append(song: song0)
        guard let foundSongIndex1 = defaultPlaylist.getFirstIndex(song: song0) else { XCTFail(); return }
        XCTAssertEqual(foundSongIndex1, 1)
        XCTAssertEqual(defaultPlaylist.items[foundSongIndex1].song!.id, song0.id)
        defaultPlaylist.remove(firstOccurrenceOfSong: song0)
        guard let foundSongIndex2 = defaultPlaylist.getFirstIndex(song: song0) else { XCTFail(); return }
        XCTAssertEqual(foundSongIndex2, 4)
        XCTAssertEqual(defaultPlaylist.items[foundSongIndex2].song!.id, song0.id)
        defaultPlaylist.remove(firstOccurrenceOfSong: song0)
        XCTAssertEqual(defaultPlaylist.getFirstIndex(song: song0), nil)
    }
    
    func testhasCachedSongs() {
        XCTAssertFalse(playlistNoCached.hasCachedSongs)
        XCTAssertTrue(defaultPlaylist.hasCachedSongs)
        XCTAssertTrue(playlistThreeCached.hasCachedSongs)
    }
    
    func testPreviousCachedSongIndex() {
        guard let prev1 = defaultPlaylist.previousCachedSongIndex(downwardsFrom: 4) else { XCTFail(); return }
        XCTAssertEqual(prev1, 3)
        guard let prev2 = defaultPlaylist.previousCachedSongIndex(beginningAt: 3) else { XCTFail(); return }
        XCTAssertEqual(prev2, 3)
        guard let prev3 = defaultPlaylist.previousCachedSongIndex(beginningAt: 4) else { XCTFail(); return }
        XCTAssertEqual(prev3, 3)
        
        XCTAssertEqual(defaultPlaylist.previousCachedSongIndex(downwardsFrom: 3), nil)
        XCTAssertEqual(defaultPlaylist.previousCachedSongIndex(beginningAt: 2), nil)
        
        XCTAssertEqual(playlistNoCached.previousCachedSongIndex(downwardsFrom: 3), nil)
        XCTAssertEqual(playlistNoCached.previousCachedSongIndex(beginningAt: 3), nil)
        
        guard let prev4 = playlistThreeCached.previousCachedSongIndex(beginningAt: 8) else { XCTFail(); return }
        XCTAssertEqual(prev4, 8)
        guard let prev5 = playlistThreeCached.previousCachedSongIndex(beginningAt: 7) else { XCTFail(); return }
        XCTAssertEqual(prev5, 6)
        guard let prev6 = playlistThreeCached.previousCachedSongIndex(beginningAt: 6) else { XCTFail(); return }
        XCTAssertEqual(prev6, 6)
        guard let prev7 = playlistThreeCached.previousCachedSongIndex(beginningAt: 5) else { XCTFail(); return }
        XCTAssertEqual(prev7, 3)
        XCTAssertEqual(playlistThreeCached.previousCachedSongIndex(beginningAt: 2), nil)
    }
    
    func testNextCachedSongIndex() {
        guard let next1 = defaultPlaylist.nextCachedSongIndex(upwardsFrom: 2) else { XCTFail(); return }
        XCTAssertEqual(next1, 3)
        guard let next2 = defaultPlaylist.nextCachedSongIndex(beginningAt: 3) else { XCTFail(); return }
        XCTAssertEqual(next2, 3)
        guard let next3 = defaultPlaylist.nextCachedSongIndex(beginningAt: 0) else { XCTFail(); return }
        XCTAssertEqual(next3, 3)
        guard let next4 = defaultPlaylist.nextCachedSongIndex(upwardsFrom: 0) else { XCTFail(); return }
        XCTAssertEqual(next4, 3)
        guard let next5 = defaultPlaylist.nextCachedSongIndex(beginningAt: 1) else { XCTFail(); return }
        XCTAssertEqual(next5, 3)
        guard let next6 = defaultPlaylist.nextCachedSongIndex(upwardsFrom: 1) else { XCTFail(); return }
        XCTAssertEqual(next6, 3)
        
        XCTAssertEqual(defaultPlaylist.nextCachedSongIndex(upwardsFrom: 3), nil)
        XCTAssertEqual(defaultPlaylist.nextCachedSongIndex(beginningAt: 4), nil)
        
        XCTAssertEqual(playlistNoCached.nextCachedSongIndex(upwardsFrom: 0), nil)
        XCTAssertEqual(playlistNoCached.nextCachedSongIndex(beginningAt: 0), nil)
        
        guard let next7 = playlistThreeCached.nextCachedSongIndex(upwardsFrom: 1) else { XCTFail(); return }
        XCTAssertEqual(next7, 3)
        guard let next8 = playlistThreeCached.nextCachedSongIndex(upwardsFrom: 3) else { XCTFail(); return }
        XCTAssertEqual(next8, 6)
        guard let next9 = playlistThreeCached.nextCachedSongIndex(upwardsFrom: 7) else { XCTFail(); return }
        XCTAssertEqual(next9, 8)
        guard let next10 = playlistThreeCached.nextCachedSongIndex(beginningAt: 8) else { XCTFail(); return }
        XCTAssertEqual(next10, 8)
        
        XCTAssertEqual(playlistThreeCached.nextCachedSongIndex(upwardsFrom: 8), nil)
        XCTAssertEqual(playlistThreeCached.nextCachedSongIndex(beginningAt: 9), nil)
    }
    
    func testMovePlaylistSong_InvalidValues() {
        resetTestPlaylist()
        
        testPlaylist.movePlaylistSong(fromIndex: 0, to: 5)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistSong(fromIndex: 0, to: 20)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistSong(fromIndex: 5, to: 0)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistSong(fromIndex: 20, to: 0)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistSong(fromIndex: -1, to: 2)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistSong(fromIndex: -9, to: 1)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistSong(fromIndex: 1, to: -1)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistSong(fromIndex: 1, to: -20)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistSong(fromIndex: 1, to: 1)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistSong(fromIndex: 4, to: 4)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistSong(fromIndex: -5, to: 30)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistSong(fromIndex: 30, to: -9)
        checkTestPlaylistNoChange()
    }

    func testMovePlaylistSong() {
        resetTestPlaylist()
        testPlaylist.movePlaylistSong(fromIndex: 1, to: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 1)

        resetTestPlaylist()
        testPlaylist.movePlaylistSong(fromIndex: 2, to: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)

        resetTestPlaylist()
        testPlaylist.movePlaylistSong(fromIndex: 2, to: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 2)

        resetTestPlaylist()
        testPlaylist.movePlaylistSong(fromIndex: 0, to: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)

        resetTestPlaylist()
        testPlaylist.movePlaylistSong(fromIndex: 4, to: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)

        resetTestPlaylist()
        testPlaylist.movePlaylistSong(fromIndex: 4, to: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)

        resetTestPlaylist()
        testPlaylist.movePlaylistSong(fromIndex: 3, to: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)

        resetTestPlaylist()
        testPlaylist.movePlaylistSong(fromIndex: 4, to: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
     }

}
