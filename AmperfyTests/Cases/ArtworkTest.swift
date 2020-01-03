import XCTest
@testable import Amperfy

class ArtworkTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var storage: LibraryStorage!
    var testArtwork: Artwork!

    override func setUp() {
        cdHelper = CoreDataHelper()
        storage = cdHelper.createSeededStorage()
        testArtwork = storage.createArtwork()
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let artwork = storage.createArtwork()
        XCTAssertEqual(artwork.status.rawValue, ImageStatus.IsDefaultImage.rawValue)
        XCTAssertEqual(artwork.url, "")
        XCTAssertEqual(artwork.image, Artwork.defaultImage)
        XCTAssertEqual(artwork.owners.count, 0)
    }
    
    func testDefaultImage() {
        XCTAssertEqual(Artwork.defaultImage, UIImage(named: "song"))
    }
    
    func testStatus() {
        testArtwork.status = ImageStatus.FetchError
        XCTAssertEqual(testArtwork.status, ImageStatus.FetchError)
        guard let artist1 = storage.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        artist1.managedObject.artwork = testArtwork.managedObject
        storage.saveContext()
        guard let artistFetched = storage.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        XCTAssertEqual(artistFetched.artwork?.status, ImageStatus.FetchError)
        
    }
    
    func testUrl() {
        let testUrl = "www.test.de"
        testArtwork.url = testUrl
        XCTAssertEqual(testArtwork.url, testUrl)
        guard let artist1 = storage.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        artist1.managedObject.artwork = testArtwork.managedObject
        storage.saveContext()
        guard let artistFetched = storage.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
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
        XCTAssertEqual(testArtwork.image, Artwork.defaultImage)
    }
    
    func testOwners() {
        guard let artist1 = storage.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        guard let artist2 = storage.getArtist(id: cdHelper.seeder.artists[1].id) else { XCTFail(); return }
        XCTAssertEqual(testArtwork.owners.count, 0)
        artist1.managedObject.artwork = testArtwork.managedObject
        XCTAssertEqual(testArtwork.owners.count, 1)
        artist2.managedObject.artwork = testArtwork.managedObject
        XCTAssertEqual(testArtwork.owners.count, 2)
    }

}
