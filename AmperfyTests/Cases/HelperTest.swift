import XCTest
@testable import Amperfy

class HelperTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var storage: LibraryStorage!

    override func setUp() {
        cdHelper = CoreDataHelper()
        storage = cdHelper.createSeededStorage()
    }

    override func tearDown() {
    }
    
    func testSeeder() {
        XCTAssertEqual(storage.getArtists().count, cdHelper.seeder.artists.count)
        XCTAssertEqual(storage.getAlbums().count, cdHelper.seeder.albums.count)
        XCTAssertEqual(storage.getSongs().count, cdHelper.seeder.songs.count)
        XCTAssertEqual(storage.getPlaylists().count, cdHelper.seeder.playlists.count)
    }

}
