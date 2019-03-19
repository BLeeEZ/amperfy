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
            if !syncWave.isInitialWave, let albumId = Int32(attributeDict["id"] ?? "0"), let fetchedAlbum = libraryStorage.getAlbum(id: albumId)  {
                albumBuffer = fetchedAlbum
            } else {
                albumBuffer = libraryStorage.createAlbum()
                albumBuffer?.syncInfo = syncWave
                albumBuffer?.id = Int32(attributeDict["id"] ?? "0") ?? 0
            }
		case "artist":
            if let album = albumBuffer {
                let artistId = Int32(attributeDict["id"] ?? "0") ?? 0
                if let artist = libraryStorage.getArtist(id: artistId) {
                    album.artist = artist
                } else {
                    os_log("Found album id %d with unknown artist %d", log: log, type: .error, album.id, artistId)
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
            albumBuffer?.year = Int16(buffer) ?? 0
        case "art":
            albumBuffer?.artwork?.url = buffer
		default:
			break
		}
        
        buffer = ""
    }

}
