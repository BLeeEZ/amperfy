import XCTest
@testable import AmperfyKit

class GenreParserTest: AbstractAmpacheTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "genres")
        recreateParserDelegate()
    }
    
    override func recreateParserDelegate() {
        parserDelegate = GenreParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
    }
    
    override func checkCorrectParsing() {
        XCTAssertEqual(library.genreCount, 2)
        
        guard let genre = library.getGenre(id: "6") else { XCTFail(); return }
        XCTAssertEqual(genre.id, "6")
        XCTAssertEqual(genre.name, "Dance")
        
        guard let genre = library.getGenre(id: "4") else { XCTFail(); return }
        XCTAssertEqual(genre.id, "4")
        XCTAssertEqual(genre.name, "Dark Ambient")
    }

}
