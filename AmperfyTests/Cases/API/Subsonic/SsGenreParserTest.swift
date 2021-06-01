import XCTest
@testable import Amperfy

class SsGenreParserTest: AbstractSsParserTest {

    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "genres_example_1")
        ssParserDelegate = SsGenreParserDelegate(libraryStorage: library, syncWave: syncWave, parseNotifier: nil)
    }
    
    override func checkCorrectParsing() {
        XCTAssertEqual(library.genreCount, 7)
        
        guard let genre = library.getGenre(name: "Electronic") else { XCTFail(); return }
        XCTAssertEqual(genre.name, "Electronic")
        guard let genre = library.getGenre(name: "Hard Rock") else { XCTFail(); return }
        XCTAssertEqual(genre.name, "Hard Rock")
        guard let genre = library.getGenre(name: "R&B") else { XCTFail(); return }
        XCTAssertEqual(genre.name, "R&B")
        guard let genre = library.getGenre(name: "Blues") else { XCTFail(); return }
        XCTAssertEqual(genre.name, "Blues")
        guard let genre = library.getGenre(name: "Podcast") else { XCTFail(); return }
        XCTAssertEqual(genre.name, "Podcast")
        guard let genre = library.getGenre(name: "Brit Pop") else { XCTFail(); return }
        XCTAssertEqual(genre.name, "Brit Pop")
        guard let genre = library.getGenre(name: "Live") else { XCTFail(); return }
        XCTAssertEqual(genre.name, "Live")
    }

}
