import Foundation
import UIKit
import CoreData
import os.log

class ArtistParserDelegate: GenericXmlLibParser {

    var artistBuffer: Artist?
    var ampacheUrlCreator: AmpacheUrlCreationable

    init(libraryStorage: LibraryStorage, syncWave: SyncWave, ampacheUrlCreator: AmpacheUrlCreationable, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.ampacheUrlCreator = ampacheUrlCreator
        super.init(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: parseNotifier)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""

        if(elementName == "artist") {
            guard let artistId = attributeDict["id"] else {
                os_log("Found artist with no id", log: log, type: .error)
                return
            }
            if !syncWave.isInitialWave, let fetchedArtist = libraryStorage.getArtist(id: artistId)  {
                artistBuffer = fetchedArtist
            } else {
                artistBuffer = libraryStorage.createArtist()
                artistBuffer?.syncInfo = syncWave
                artistBuffer?.id = artistId
                artistBuffer?.artwork?.url = ampacheUrlCreator.getArtUrlString(forArtistId: artistId)
            }
		}    
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		switch(elementName) {
		case "name":
            artistBuffer?.name = buffer
		case "artist":
            parsedCount += 1
            parseNotifier?.notifyParsedObject()
            artistBuffer = nil
		default:
			break
		}
        
        buffer = ""
    }

}
