import XCTest
@testable import Amperfy

class PlaylistItemTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var storage: LibraryStorage!

    override func setUp() {
        cdHelper = CoreDataHelper()
        storage = cdHelper.createSeededStorage()
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let item = storage.createPlaylistItem()
        XCTAssertEqual(item.index, 0)
        XCTAssertEqual(item.order, 0)
        XCTAssertEqual(item.song, nil)
        XCTAssertEqual(item.playlist, nil)
        
        guard let song1 = storage.getSong(id: cdHelper.seeder.songs[0].id) else { XCTFail(); return }
        item.song = song1
        XCTAssertEqual(item.song!.id, song1.id)
        guard let playlist = storage.getPlaylist(id: Int32(cdHelper.seeder.playlists[0].id)) else { XCTFail(); return }
        let itemOrder = playlist.songs.count
        item.playlist = playlist
        XCTAssertEqual(item.playlist!.id, playlist.id)
        item.order = itemOrder
        XCTAssertEqual(item.order, itemOrder)
        
        guard let playlistFetched = storage.getPlaylist(id: Int32(cdHelper.seeder.playlists[0].id)) else { XCTFail(); return }
        XCTAssertEqual(playlistFetched.items[itemOrder].song!.id, song1.id)
        XCTAssertEqual(playlistFetched.items[itemOrder].playlist!.id, playlistFetched.id)
        XCTAssertEqual(playlistFetched.items[itemOrder].order, itemOrder)
    }
    
    func testIndexAfterDeletion() {
        let item = storage.createPlaylistItem()
        XCTAssertEqual(item.index, 0)
        storage.deletePlaylistItem(item: item)
        storage.saveContext()
        XCTAssertEqual(item.index, nil)
    }

}
