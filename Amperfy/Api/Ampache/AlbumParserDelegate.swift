import Foundation
import UIKit
import CoreData
import os.log

class AlbumParserDelegate: GenericXmlLibParser {
    
    var albumBuffer: Album?
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
 		switch(elementName) {
		case "album":
            guard let albumId = attributeDict["id"] else {
                os_log("Found album with no id", log: log, type: .error)
                return
            }
            if !syncWave.isInitialWave, let fetchedAlbum = libraryStorage.getAlbum(id: albumId)  {
                albumBuffer = fetchedAlbum
            } else {
                albumBuffer = libraryStorage.createAlbum()
                albumBuffer?.syncInfo = syncWave
                albumBuffer?.id = albumId
            }
		case "artist":
            if let album = albumBuffer {
                guard let artistId = attributeDict["id"] else {
                    os_log("Found album id %d with no artist id. Album name: %s", log: log, type: .error, album.id, album.name)
                    return
                }
                if let artist = libraryStorage.getArtist(id: artistId) {
                    album.artist = artist
                } else {
                    os_log("Found album id %d with unknown artist %d. Album name: %s", log: log, type: .error, album.id, artistId, album.name)
                }
            }
		default:
			break
		}
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		switch(elementName) {
		case "name":
            albumBuffer?.name = buffer
		case "album":
            parsedCount += 1
			parseNotifier?.notifyParsedObject()
            albumBuffer = nil
		case "year":
            albumBuffer?.year = Int(buffer) ?? 0
        case "art":
            albumBuffer?.artwork?.url = buffer
		default:
			break
		}
        
        buffer = ""
    }

}
