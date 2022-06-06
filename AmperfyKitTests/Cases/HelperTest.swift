import XCTest
@testable import AmperfyKit

class HelperTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!

    override func setUp() {
        cdHelper = CoreDataHelper()
        library = cdHelper.createSeededStorage()
    }

    override func tearDown() {
    }
    
    func testSeeder() {
        XCTAssertEqual(library.getArtists().count, cdHelper.seeder.artists.count)
        XCTAssertEqual(library.getAlbums().count, cdHelper.seeder.albums.count)
        XCTAssertEqual(library.getSongs().count, cdHelper.seeder.songs.count)
        XCTAssertEqual(library.getPlaylists().count, cdHelper.seeder.playlists.count)
    }

}
