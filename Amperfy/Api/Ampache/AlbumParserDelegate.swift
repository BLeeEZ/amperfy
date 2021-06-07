import Foundation
import UIKit
import CoreData
import os.log

class AlbumParserDelegate: AmpacheXmlLibParser {
    
    var albumBuffer: Album?
    var genreIdToCreate: String?
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

 		switch(elementName) {
		case "album":
            guard let albumId = attributeDict["id"] else {
                os_log("Found album with no id", log: log, type: .error)
                return
            }
            if let fetchedAlbum = libraryStorage.getAlbum(id: albumId)  {
                albumBuffer = fetchedAlbum
            } else {
                albumBuffer = libraryStorage.createAlbum()
                albumBuffer?.syncInfo = syncWave
                albumBuffer?.id = albumId
            }
		case "artist":
            if let album = albumBuffer {
                guard let artistId = attributeDict["id"] else {
                    os_log("Found album id %s with no artist id. Album name: %s", log: log, type: .error, album.id, album.name)
                    return
                }
                if let artist = libraryStorage.getArtist(id: artistId) {
                    album.artist = artist
                } else {
                    os_log("Found album id %s with unknown artist %s. Album name: %s", log: log, type: .error, album.id, artistId, album.name)
                }
            }
        case "genre":
            if let album = albumBuffer {
                guard let genreId = attributeDict["id"] else { return }
                if let genre = libraryStorage.getGenre(id: genreId) {
                    album.genre = genre
                } else {
                    genreIdToCreate = genreId
                }
            }
		default:
			break
		}
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		switch(elementName) {
		case "name":
            albumBuffer?.name = buffer
		case "album":
            parsedCount += 1
            parseNotifier?.notifyParsedObject(ofType: .album)
            albumBuffer = nil
		case "year":
            albumBuffer?.year = Int(buffer) ?? 0
        case "songcount":
            albumBuffer?.songCount = Int(buffer) ?? 0
        case "art":
            albumBuffer?.artwork = parseArtwork(urlString: buffer)
        case "genre":
            if let genreId = genreIdToCreate {
                os_log("Genre <%s> with id %s has been created", log: log, type: .error, buffer, genreId)
                let genre = libraryStorage.createGenre()
                genre.id = genreId
                genre.name = buffer
                genre.syncInfo = syncWave
                albumBuffer?.genre = genre
                genreIdToCreate = nil
            }
		default:
			break
		}
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
