import Foundation
import UIKit
import CoreData

class SsGenreParserDelegate: GenericXmlLibParser {

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		switch(elementName) {
		case "genre":
            let genreName = buffer
            if let _ = libraryStorage.getGenre(name: genreName) {
                // info already synced -> skip
            } else {
                let genre = libraryStorage.createGenre()
                genre.name = buffer
                genre.syncInfo = syncWave
            }
            parsedCount += 1
		default:
			break
		}
        
        buffer = ""
    }

}
