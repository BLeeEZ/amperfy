import XCTest
@testable import AmperfyKit

class ArtworkTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var testArtwork: Artwork!

    override func setUp() {
        cdHelper = CoreDataHelper()
        library = cdHelper.createSeededStorage()
        testArtwork = library.createArtwork()
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let artwork = library.createArtwork()
        XCTAssertEqual(artwork.status.rawValue, ImageStatus.IsDefaultImage.rawValue)
        XCTAssertEqual(artwork.url, "")
        XCTAssertNil(artwork.image)
        XCTAssertEqual(artwork.owners.count, 0)
    }
    
    func testDefaultImage() {
        XCTAssertEqual(UIImage.songArtwork, UIImage.songArtwork)
    }
    
    func testStatus() {
        testArtwork.status = ImageStatus.FetchError
        XCTAssertEqual(testArtwork.status, ImageStatus.FetchError)
        guard let artist1 = library.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        artist1.managedObject.artwork = testArtwork.managedObject
        library.saveContext()
        guard let artistFetched = library.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        XCTAssertEqual(artistFetched.artwork?.status, ImageStatus.FetchError)
        
    }
    
    func testUrl() {
        let testUrl = "www.test.de"
        testArtwork.url = testUrl
        XCTAssertEqual(testArtwork.url, testUrl)
        guard let artist1 = library.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        artist1.managedObject.artwork = testArtwork.managedObject
        library.saveContext()
        guard let artistFetched = library.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        XCTAssertEqual(artistFetched.artwork?.url, testUrl)
    }
    
    func testImageWithCorrectStatus() {
        testArtwork.status = ImageStatus.CustomImage
        let testData = Data(base64Encoded: "Test", options: .ignoreUnknownCharacters)!
        let testImg = UIImage(data: testData)
        testArtwork.setImage(fromData: testData)
        XCTAssertEqual(testArtwork.managedObject.imageData, testData)
        XCTAssertEqual(testArtwork.status, ImageStatus.CustomImage)
        XCTAssertEqual(testArtwork.image, testImg)
    }
    
    func testImageWithWrongStatus() {
        testArtwork.status = ImageStatus.NotChecked
        let testData = Data(base64Encoded: "Test", options: .ignoreUnknownCharacters)!
        testArtwork.setImage(fromData: testData)
        XCTAssertEqual(testArtwork.managedObject.imageData, testData)
        XCTAssertEqual(testArtwork.status, ImageStatus.NotChecked)
        XCTAssertNil(testArtwork.image)
    }
    
    func testOwners() {
        guard let artist1 = library.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        guard let artist2 = library.getArtist(id: cdHelper.seeder.artists[1].id) else { XCTFail(); return }
        XCTAssertEqual(testArtwork.owners.count, 0)
        artist1.managedObject.artwork = testArtwork.managedObject
        XCTAssertEqual(testArtwork.owners.count, 1)
        artist2.managedObject.artwork = testArtwork.managedObject
        XCTAssertEqual(testArtwork.owners.count, 2)
    }

}
