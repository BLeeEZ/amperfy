import Foundation
import UIKit
import CoreData
import os.log

class ArtistParserDelegate: GenericXmlLibParser {

    var artistBuffer: Artist?
    var genreIdToCreate: String?
    var ampacheUrlCreator: AmpacheUrlCreationable

    init(libraryStorage: LibraryStorage, syncWave: SyncWave, ampacheUrlCreator: AmpacheUrlCreationable, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.ampacheUrlCreator = ampacheUrlCreator
        super.init(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: parseNotifier)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""

        if elementName == "artist" {
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
        if elementName == "genre", let artist = artistBuffer {
            guard let genreId = attributeDict["id"] else { return }
            if let genre = libraryStorage.getGenre(id: genreId) {
                artist.genre = genre
            } else {
                genreIdToCreate = genreId
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		switch(elementName) {
		case "name":
            artistBuffer?.name = buffer
        case "albumcount":
            artistBuffer?.albumCount = Int(buffer) ?? 0
        case "genre":
            if let genreId = genreIdToCreate {
                os_log("Genre <%s> with id %s has been created", log: log, type: .error, buffer, genreId)
                let genre = libraryStorage.createGenre()
                genre.id = genreId
                genre.name = buffer
                genre.syncInfo = syncWave
                artistBuffer?.genre = genre
                genreIdToCreate = nil
            }
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
