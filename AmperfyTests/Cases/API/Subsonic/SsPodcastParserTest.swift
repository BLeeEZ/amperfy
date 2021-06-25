import XCTest
@testable import Amperfy

class SsPodcastParserTest: AbstractSsParserTest {
    
    override func setUp() {
        super.setUp()
        xmlData = getTestFileData(name: "podcasts_example_1")
        ssParserDelegate = SsPodcastParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator, parseNotifier: nil)
    }
    
    override func checkCorrectParsing() {
        let podcasts = library.getPodcasts().sorted(by: {Int($0.id)! < Int($1.id)!} )
        XCTAssertEqual(podcasts.count, 2)
        
        var podcast = podcasts[0]
        XCTAssertEqual(podcast.id, "1")
        XCTAssertEqual(podcast.title, "Dr Karl and the Naked Scientist")
        XCTAssertEqual(podcast.depiction, "Dr Chris Smith aka The Naked Scientist with the latest news from the world of science and Dr Karl answers listeners' science questions.")
        XCTAssertEqual(podcast.artwork?.url, "www-pod-1")
        XCTAssertEqual(podcast.artwork?.type, "")
        XCTAssertEqual(podcast.artwork?.id, "pod-1")

        podcast = podcasts[1]
        XCTAssertEqual(podcast.id, "2")
        XCTAssertEqual(podcast.title, "NRK P1 - Herreavdelingen")
        XCTAssertEqual(podcast.depiction, "Et program der herrene Yan Friis og Finn Bjelke møtes og musikk nytes.")
        XCTAssertEqual(podcast.artwork?.url, "www-pod-2")
        XCTAssertEqual(podcast.artwork?.type, "")
        XCTAssertEqual(podcast.artwork?.id, "pod-2")
    }

}
