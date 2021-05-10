import Foundation
import UIKit
import CoreData
import os.log

class GenreParserDelegate: GenericXmlLibParser {

    var genreBuffer: Genre?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""

        if(elementName == "genre") {
            guard let genreId = attributeDict["id"] else {
                os_log("Found genre with no id", log: log, type: .error)
                return
            }
            if !syncWave.isInitialWave, let fetchedGenre = libraryStorage.getGenre(id: genreId)  {
                genreBuffer = fetchedGenre
            } else {
                genreBuffer = libraryStorage.createGenre()
                genreBuffer?.id = genreId
                genreBuffer?.syncInfo = syncWave
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
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
        
        buffer = ""
    }

}
