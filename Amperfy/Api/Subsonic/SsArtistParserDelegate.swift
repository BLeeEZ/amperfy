import Foundation
import UIKit
import CoreData

class SsArtistParserDelegate: GenericXmlLibParser {

    private var subsonicUrlCreator: SubsonicUrlCreator
    private var artistBuffer: Artist?

    init(libraryStorage: LibraryStorage, syncWave: SyncWave, subsonicUrlCreator: SubsonicUrlCreator, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.subsonicUrlCreator = subsonicUrlCreator
        super.init(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: parseNotifier)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""

        if(elementName == "artist") {
            guard let artistId = attributeDict["id"] else { return }
            
            if !syncWave.isInitialWave, let fetchedArtist = libraryStorage.getArtist(id: artistId)  {
                artistBuffer = fetchedArtist
            } else {
                artistBuffer = libraryStorage.createArtist()
                artistBuffer?.syncInfo = syncWave
                artistBuffer?.id = artistId
                if let attributeArtistName = attributeDict["name"] {
                    artistBuffer?.name = attributeArtistName
                }
                artistBuffer?.artwork?.url = subsonicUrlCreator.getArtUrlString(forArtistId: artistId)
            }
		}    
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		switch(elementName) {
		case "artist":
            parsedCount += 1
            artistBuffer = nil
		default:
			break
		}
        
        buffer = ""
    }

}
