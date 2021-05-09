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

        if elementName == "artist" {
            guard let artistId = attributeDict["id"] else { return }
            
            if let fetchedArtist = libraryStorage.getArtist(id: artistId)  {
                artistBuffer = fetchedArtist
            } else {
                artistBuffer = libraryStorage.createArtist()
                artistBuffer?.id = artistId
                artistBuffer?.syncInfo = syncWave
            }
            if let attributeAlbumCount = attributeDict["albumCount"], let albumCount = Int(attributeAlbumCount) {
                artistBuffer?.albumCount = albumCount
            }

            if let attributeArtistName = attributeDict["name"] {
                artistBuffer?.name = attributeArtistName
            }
            if let artistArtwork = artistBuffer?.artwork, artistArtwork.url.isEmpty {
                artistArtwork.url = subsonicUrlCreator.getArtUrlString(forArtistId: artistId)
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
