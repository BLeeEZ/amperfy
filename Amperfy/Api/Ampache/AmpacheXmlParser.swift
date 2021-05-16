import Foundation

class AmpacheXmlParser: GenericXmlParser {
    
    var error: ResponseError?
    private var statusCode: Int = 0
    private var message = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        switch(elementName) {
        case "error":
            statusCode = Int(attributeDict["errorCode"] ?? "0") ?? 0
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "errorMessage":
            message = buffer
        case "error":
            error = ResponseError(statusCode: statusCode, message: message)
        default:
            break
        }
        
        buffer = ""
    }
    
}

class AmpacheNotifiableXmlParser: AmpacheXmlParser {
    
    var parseNotifier: ParsedObjectNotifiable?
    
    init(parseNotifier: ParsedObjectNotifiable? = nil) {
        self.parseNotifier = parseNotifier
    }
    
}

class AmpacheXmlLibParser: AmpacheNotifiableXmlParser {
    
    var libraryStorage: LibraryStorage
    var syncWave: SyncWave
    
    init(libraryStorage: LibraryStorage, syncWave: SyncWave, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.libraryStorage = libraryStorage
        self.syncWave = syncWave
        super.init(parseNotifier: parseNotifier)
    }
    
}
