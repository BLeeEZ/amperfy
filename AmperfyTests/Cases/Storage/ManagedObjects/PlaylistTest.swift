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
        testPlaylist.removeAllItems()
        for i in 0...4 {
            guard let song = library.getSong(id: cdHelper.seeder.songs[i].id) else { XCTFail(); return }
            testPlaylist.append(playable: song)
        }
    }
    
    func checkTestPlaylistNoChange() {
        for i in 0...4 {
            checkPlaylistIndexEqualSeedIndex(playlistIndex: i, seedIndex: i)
        }
    }
    
    func checkPlaylistIndexEqualSeedIndex(playlistIndex: Int, seedIndex: Int) {
        guard let song = library.getSong(id: cdHelper.seeder.songs[seedIndex].id) else { XCTFail(); return }
        XCTAssertEqual(testPlaylist.playables[playlistIndex].id, song.id)
    }
    
    func testCreation() {
        let playlist = library.createPlaylist()
        XCTAssertEqual(playlist.items.count, 0)
        XCTAssertEqual(playlist.id, "")
        XCTAssertEqual(playlist.lastPlayableIndex, 0)
        XCTAssertFalse(playlist.hasCachedPlayables)
        
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
        playlist.append(playable: song1)
        XCTAssertEqual(playlist.items.count, 1)
        guard let song2 = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        playlist.append(playable: song2)
        XCTAssertEqual(playlist.items.count, 2)
        guard let song3 = library.getSong(id: cdHelper.seeder.songs[2].id) else { XCTFail(); return }
        playlist.append(playable: song3)
        XCTAssertEqual(playlist.items.count, 3)
        
        for (index,entry) in playlist.items.enumerated() {
            XCTAssertEqual(entry.order, index)
            XCTAssertEqual(entry.playable?.id, cdHelper.seeder.songs[index].id)
        }
    }
    
    func testDefaultPlaylist() {
        XCTAssertTrue(defaultPlaylist.hasCachedPlayables)
        XCTAssertEqual(defaultPlaylist.playables.count, 5)
        XCTAssertEqual(defaultPlaylist.items.count, 5)
        XCTAssertEqual(defaultPlaylist.lastPlayableIndex, 4)
        XCTAssertEqual(defaultPlaylist.playables[0].id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[0].playable!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[0].order, 0)
        XCTAssertEqual(defaultPlaylist.playables[1].id, cdHelper.seeder.songs[1].id)
        XCTAssertEqual(defaultPlaylist.items[1].playable!.id, cdHelper.seeder.songs[1].id)
        XCTAssertEqual(defaultPlaylist.items[1].order, 1)
        XCTAssertEqual(defaultPlaylist.playables[2].id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[2].playable!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[2].order, 2)
        XCTAssertEqual(defaultPlaylist.playables[3].id, cdHelper.seeder.songs[4].id)
        XCTAssertEqual(defaultPlaylist.items[3].playable!.id, cdHelper.seeder.songs[4].id)
        XCTAssertEqual(defaultPlaylist.items[3].order, 3)
        XCTAssertEqual(defaultPlaylist.playables[4].id, cdHelper.seeder.songs[3].id)
        XCTAssertEqual(defaultPlaylist.items[4].playable!.id, cdHelper.seeder.songs[3].id)
        XCTAssertEqual(defaultPlaylist.items[4].order, 4)
    }
    
    func testReorderLastToFirst() {
        defaultPlaylist.movePlaylistItem(fromIndex: 2, to: 0)
        XCTAssertEqual(defaultPlaylist.items[0].playable!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[1].playable!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[2].playable!.id, cdHelper.seeder.songs[1].id)
    }
    
    func testReorderSecondToLast() {
        defaultPlaylist.movePlaylistItem(fromIndex: 1, to: 2)
        XCTAssertEqual(defaultPlaylist.items[0].playable!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[1].playable!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[2].playable!.id, cdHelper.seeder.songs[1].id)
    }
    
    func testReorderNoChange() {
        defaultPlaylist.movePlaylistItem(fromIndex: 1, to: 1)
        XCTAssertEqual(defaultPlaylist.items[0].playable!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[1].playable!.id, cdHelper.seeder.songs[1].id)
        XCTAssertEqual(defaultPlaylist.items[2].playable!.id, cdHelper.seeder.songs[2].id)
    }
    
    func testEntryRemoval() {
        defaultPlaylist.remove(at: 1)
        XCTAssertEqual(defaultPlaylist.items.count, cdHelper.seeder.playlists[0].songIds.count - 1)
        XCTAssertEqual(defaultPlaylist.items[0].playable!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[0].order, 0)
        XCTAssertEqual(defaultPlaylist.items[1].playable!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[1].order, 1)
    }
    
    func testRemoveFirstOccurrenceOfSong_Success() {
        guard let song1 = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        defaultPlaylist.append(playable: song1)
        defaultPlaylist.remove(firstOccurrenceOfPlayable: song1)
        XCTAssertEqual(defaultPlaylist.items.count, cdHelper.seeder.playlists[0].songIds.count)
        XCTAssertEqual(defaultPlaylist.items[0].playable!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[0].order, 0)
        XCTAssertEqual(defaultPlaylist.items[1].playable!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[1].order, 1)
        XCTAssertEqual(defaultPlaylist.items[4].playable!.id,song1.id)
        
        defaultPlaylist.remove(firstOccurrenceOfPlayable: song1)
        XCTAssertEqual(defaultPlaylist.items.count, cdHelper.seeder.playlists[0].songIds.count - 1)
        XCTAssertEqual(defaultPlaylist.items[0].playable!.id, cdHelper.seeder.songs[0].id)
        XCTAssertEqual(defaultPlaylist.items[0].order, 0)
        XCTAssertEqual(defaultPlaylist.items[1].playable!.id, cdHelper.seeder.songs[2].id)
        XCTAssertEqual(defaultPlaylist.items[1].order, 1)
        XCTAssertEqual(defaultPlaylist.items[3].playable!.id, cdHelper.seeder.songs[3].id)
        XCTAssertEqual(defaultPlaylist.items[3].order, 3)
    }
    
    func testRemoveFirstOccurrenceOfSong_NoChange() {
        guard let song6 = library.getSong(id: cdHelper.seeder.songs[6].id) else { XCTFail(); return }
        defaultPlaylist.remove(firstOccurrenceOfPlayable: song6)
        testDefaultPlaylist()
    }
    
    func testRemovalAll() {
        defaultPlaylist.removeAllItems()
        XCTAssertEqual(defaultPlaylist.items.count, 0)
    }
    
    func testGetFirstIndex() {
        guard let song0 = library.getSong(id: cdHelper.seeder.songs[1].id) else { XCTFail(); return }
        guard let foundSongIndex0 = defaultPlaylist.getFirstIndex(playable: song0) else { XCTFail(); return }
        XCTAssertEqual(foundSongIndex0, 1)
        XCTAssertEqual(defaultPlaylist.items[foundSongIndex0].playable!.id, song0.id)
        defaultPlaylist.append(playable: song0)
        guard let foundSongIndex1 = defaultPlaylist.getFirstIndex(playable: song0) else { XCTFail(); return }
        XCTAssertEqual(foundSongIndex1, 1)
        XCTAssertEqual(defaultPlaylist.items[foundSongIndex1].playable!.id, song0.id)
        defaultPlaylist.remove(firstOccurrenceOfPlayable: song0)
        guard let foundSongIndex2 = defaultPlaylist.getFirstIndex(playable: song0) else { XCTFail(); return }
        XCTAssertEqual(foundSongIndex2, 4)
        XCTAssertEqual(defaultPlaylist.items[foundSongIndex2].playable!.id, song0.id)
        defaultPlaylist.remove(firstOccurrenceOfPlayable: song0)
        XCTAssertEqual(defaultPlaylist.getFirstIndex(playable: song0), nil)
    }
    
    func testhasCachedSongs() {
        XCTAssertFalse(playlistNoCached.hasCachedPlayables)
        XCTAssertTrue(defaultPlaylist.hasCachedPlayables)
        XCTAssertTrue(playlistThreeCached.hasCachedPlayables)
    }
    
    func testPreviousCachedSongIndex() {
        guard let prev1 = defaultPlaylist.previousCachedItemIndex(downwardsFrom: 4) else { XCTFail(); return }
        XCTAssertEqual(prev1, 3)
        guard let prev2 = defaultPlaylist.previousCachedItemIndex(beginningAt: 3) else { XCTFail(); return }
        XCTAssertEqual(prev2, 3)
        guard let prev3 = defaultPlaylist.previousCachedItemIndex(beginningAt: 4) else { XCTFail(); return }
        XCTAssertEqual(prev3, 3)
        
        XCTAssertEqual(defaultPlaylist.previousCachedItemIndex(downwardsFrom: 3), nil)
        XCTAssertEqual(defaultPlaylist.previousCachedItemIndex(beginningAt: 2), nil)
        
        XCTAssertEqual(playlistNoCached.previousCachedItemIndex(downwardsFrom: 3), nil)
        XCTAssertEqual(playlistNoCached.previousCachedItemIndex(beginningAt: 3), nil)
        
        guard let prev4 = playlistThreeCached.previousCachedItemIndex(beginningAt: 8) else { XCTFail(); return }
        XCTAssertEqual(prev4, 8)
        guard let prev5 = playlistThreeCached.previousCachedItemIndex(beginningAt: 7) else { XCTFail(); return }
        XCTAssertEqual(prev5, 6)
        guard let prev6 = playlistThreeCached.previousCachedItemIndex(beginningAt: 6) else { XCTFail(); return }
        XCTAssertEqual(prev6, 6)
        guard let prev7 = playlistThreeCached.previousCachedItemIndex(beginningAt: 5) else { XCTFail(); return }
        XCTAssertEqual(prev7, 3)
        XCTAssertEqual(playlistThreeCached.previousCachedItemIndex(beginningAt: 2), nil)
    }
    
    func testNextCachedSongIndex() {
        guard let next1 = defaultPlaylist.nextCachedItemIndex(upwardsFrom: 2) else { XCTFail(); return }
        XCTAssertEqual(next1, 3)
        guard let next2 = defaultPlaylist.nextCachedItemIndex(beginningAt: 3) else { XCTFail(); return }
        XCTAssertEqual(next2, 3)
        guard let next3 = defaultPlaylist.nextCachedItemIndex(beginningAt: 0) else { XCTFail(); return }
        XCTAssertEqual(next3, 3)
        guard let next4 = defaultPlaylist.nextCachedItemIndex(upwardsFrom: 0) else { XCTFail(); return }
        XCTAssertEqual(next4, 3)
        guard let next5 = defaultPlaylist.nextCachedItemIndex(beginningAt: 1) else { XCTFail(); return }
        XCTAssertEqual(next5, 3)
        guard let next6 = defaultPlaylist.nextCachedItemIndex(upwardsFrom: 1) else { XCTFail(); return }
        XCTAssertEqual(next6, 3)
        
        XCTAssertEqual(defaultPlaylist.nextCachedItemIndex(upwardsFrom: 3), nil)
        XCTAssertEqual(defaultPlaylist.nextCachedItemIndex(beginningAt: 4), nil)
        
        XCTAssertEqual(playlistNoCached.nextCachedItemIndex(upwardsFrom: 0), nil)
        XCTAssertEqual(playlistNoCached.nextCachedItemIndex(beginningAt: 0), nil)
        
        guard let next7 = playlistThreeCached.nextCachedItemIndex(upwardsFrom: 1) else { XCTFail(); return }
        XCTAssertEqual(next7, 3)
        guard let next8 = playlistThreeCached.nextCachedItemIndex(upwardsFrom: 3) else { XCTFail(); return }
        XCTAssertEqual(next8, 6)
        guard let next9 = playlistThreeCached.nextCachedItemIndex(upwardsFrom: 7) else { XCTFail(); return }
        XCTAssertEqual(next9, 8)
        guard let next10 = playlistThreeCached.nextCachedItemIndex(beginningAt: 8) else { XCTFail(); return }
        XCTAssertEqual(next10, 8)
        
        XCTAssertEqual(playlistThreeCached.nextCachedItemIndex(upwardsFrom: 8), nil)
        XCTAssertEqual(playlistThreeCached.nextCachedItemIndex(beginningAt: 9), nil)
    }
    
    func testMovePlaylistSong_InvalidValues() {
        resetTestPlaylist()
        
        testPlaylist.movePlaylistItem(fromIndex: 0, to: 5)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistItem(fromIndex: 0, to: 20)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistItem(fromIndex: 5, to: 0)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistItem(fromIndex: 20, to: 0)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistItem(fromIndex: -1, to: 2)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistItem(fromIndex: -9, to: 1)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistItem(fromIndex: 1, to: -1)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistItem(fromIndex: 1, to: -20)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistItem(fromIndex: 1, to: 1)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistItem(fromIndex: 4, to: 4)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistItem(fromIndex: -5, to: 30)
        checkTestPlaylistNoChange()
        testPlaylist.movePlaylistItem(fromIndex: 30, to: -9)
        checkTestPlaylistNoChange()
    }

    func testMovePlaylistSong() {
        resetTestPlaylist()
        testPlaylist.movePlaylistItem(fromIndex: 1, to: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 1)

        resetTestPlaylist()
        testPlaylist.movePlaylistItem(fromIndex: 2, to: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)

        resetTestPlaylist()
        testPlaylist.movePlaylistItem(fromIndex: 2, to: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 2)

        resetTestPlaylist()
        testPlaylist.movePlaylistItem(fromIndex: 0, to: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)

        resetTestPlaylist()
        testPlaylist.movePlaylistItem(fromIndex: 4, to: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)

        resetTestPlaylist()
        testPlaylist.movePlaylistItem(fromIndex: 4, to: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)

        resetTestPlaylist()
        testPlaylist.movePlaylistItem(fromIndex: 3, to: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 3)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)

        resetTestPlaylist()
        testPlaylist.movePlaylistItem(fromIndex: 4, to: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
        checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
     }

}
