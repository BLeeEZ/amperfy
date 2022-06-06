import Foundation
import UIKit
import CoreData

class SsGenreParserDelegate: SsXmlLibParser {
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		switch(elementName) {
		case "genre":
            let genreName = buffer
            if let _ = library.getGenre(name: genreName) {
                // info already synced -> skip
            } else {
                let genre = library.createGenre()
                genre.name = buffer
                genre.syncInfo = syncWave
            }
            parsedCount += 1
		default:
			break
		}
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
