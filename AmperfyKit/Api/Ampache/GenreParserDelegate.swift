import Foundation
import UIKit
import CoreData
import os.log

class GenreParserDelegate: AmpacheXmlLibParser {

    var genreBuffer: Genre?

    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

        if(elementName == "genre") {
            guard let genreId = attributeDict["id"] else {
                os_log("Found genre with no id", log: log, type: .error)
                return
            }
            if !syncWave.isInitialWave, let fetchedGenre = library.getGenre(id: genreId)  {
                genreBuffer = fetchedGenre
            } else {
                genreBuffer = library.createGenre()
                genreBuffer?.id = genreId
                genreBuffer?.syncInfo = syncWave
            }
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "name":
            genreBuffer?.name = buffer
        case "genre":
            parsedCount += 1
            parseNotifier?.notifyParsedObject(ofType: .genre)
            genreBuffer = nil
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
