import Foundation

class SsXmlParser: GenericXmlParser {
    
    var error: ResponseError?

    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        if(elementName == "error") {
            let statusCode = Int(attributeDict["code"] ?? "0") ?? 0
            let message = attributeDict["message"] ?? ""
            error = ResponseError(statusCode: statusCode, message: message)
        }
    }
    
}

class SsNotifiableXmlParser: SsXmlParser {
    
    var parseNotifier: ParsedObjectNotifiable?
    
    init(parseNotifier: ParsedObjectNotifiable? = nil) {
        self.parseNotifier = parseNotifier
    }
    
}

class SsXmlLibParser: SsNotifiableXmlParser {
    
    var libraryStorage: LibraryStorage
    var syncWave: SyncWave
    
    init(libraryStorage: LibraryStorage, syncWave: SyncWave, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.libraryStorage = libraryStorage
        self.syncWave = syncWave
        super.init(parseNotifier: parseNotifier)
    }
    
}

class SsXmlLibWithArtworkParser: SsXmlLibParser {
    
    var subsonicUrlCreator: SubsonicUrlCreator
    
    init(libraryStorage: LibraryStorage, syncWave: SyncWave, subsonicUrlCreator: SubsonicUrlCreator, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.subsonicUrlCreator = subsonicUrlCreator
        super.init(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: parseNotifier)
    }

    func parseArtwork(id: String) -> Artwork? {
        let remoteInfo = ArtworkRemoteInfo(id: id, type: "")
        if let foundArtwork = libraryStorage.getArtwork(remoteInfo: remoteInfo) {
            return foundArtwork
        } else {
            let createdArtwork = libraryStorage.createArtwork()
            createdArtwork.remoteInfo = remoteInfo
            createdArtwork.url = subsonicUrlCreator.getArtUrlString(forCoverArtId: id)
            return createdArtwork
        }
    }

}

