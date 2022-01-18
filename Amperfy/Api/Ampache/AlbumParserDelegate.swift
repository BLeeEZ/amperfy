import Foundation
import UIKit
import CoreData
import os.log

class AlbumParserDelegate: AmpacheXmlLibParser {
    
    var albumBuffer: Album?
    var artistIdToCreate: String?
    var genreIdToCreate: String?
    var rating: Int = 0
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

 		switch(elementName) {
		case "album":
            guard let albumId = attributeDict["id"] else {
                os_log("Found album with no id", log: log, type: .error)
                return
            }
            if let fetchedAlbum = library.getAlbum(id: albumId)  {
                albumBuffer = fetchedAlbum
            } else {
                albumBuffer = library.createAlbum()
                albumBuffer?.syncInfo = syncWave
                albumBuffer?.id = albumId
            }
		case "artist":
            guard let album = albumBuffer, let artistId = attributeDict["id"] else { return }
            if let artist = library.getArtist(id: artistId) {
                album.artist = artist
            } else {
                artistIdToCreate = artistId
            }
        case "genre":
            if let album = albumBuffer {
                guard let genreId = attributeDict["id"] else { return }
                if let genre = library.getGenre(id: genreId) {
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
        case "artist":
            if let artistId = artistIdToCreate {
                os_log("Artist <%s> with id %s has been created", log: log, type: .error, buffer, artistId)
                let artist = library.createArtist()
                artist.id = artistId
                artist.name = buffer
                artist.syncInfo = syncWave
                albumBuffer?.artist = artist
                artistIdToCreate = nil
            }
		case "name":
            albumBuffer?.name = buffer
		case "album":
            parsedCount += 1
            albumBuffer?.rating = rating
            rating = 0
            parseNotifier?.notifyParsedObject(ofType: .album)
            albumBuffer = nil
        case "rating":
            rating = Int(buffer) ?? 0
		case "year":
            albumBuffer?.year = Int(buffer) ?? 0
        case "songcount":
            albumBuffer?.songCount = Int(buffer) ?? 0
        case "art":
            albumBuffer?.artwork = parseArtwork(urlString: buffer)
        case "genre":
            if let genreId = genreIdToCreate {
                os_log("Genre <%s> with id %s has been created", log: log, type: .error, buffer, genreId)
                let genre = library.createGenre()
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
