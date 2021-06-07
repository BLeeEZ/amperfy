import Foundation
import UIKit
import CoreData
import os.log

class SsAlbumParserDelegate: SsXmlLibWithArtworkParser {
    
    var guessedArtist: Artist?
    private var albumBuffer: Album?
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        if elementName == "album" {
            guard let albumId = attributeDict["id"] else { return }
            
            if let fetchedAlbum = libraryStorage.getAlbum(id: albumId)  {
                albumBuffer = fetchedAlbum
            } else {
                albumBuffer = libraryStorage.createAlbum()
                albumBuffer?.id = albumId
                albumBuffer?.syncInfo = syncWave
            }
            
            if let attributeAlbumtName = attributeDict["name"] {
                albumBuffer?.name = attributeAlbumtName
            }
            if let attributeCoverArt = attributeDict["coverArt"] {
                albumBuffer?.artwork = parseArtwork(id: attributeCoverArt)
            }
            
            if let attributeYear = attributeDict["year"], let year = Int(attributeYear) {
                albumBuffer?.year = year
            }
            
            if albumBuffer?.artist == nil, let artistId = attributeDict["artistId"] {
                if let guessedArtist = guessedArtist, guessedArtist.id == artistId {
                    albumBuffer?.artist = guessedArtist
                } else if let artist = libraryStorage.getArtist(id: artistId) {
                    albumBuffer?.artist = artist
                }
            }
            if let attributeSongCount = attributeDict["songCount"], let songCount = Int(attributeSongCount) {
                albumBuffer?.songCount = songCount
            }
            
            if albumBuffer?.genre == nil, let genreName = attributeDict["genre"] {
                if let genre = libraryStorage.getGenre(name: genreName) {
                    albumBuffer?.genre = genre
                } else {
                    let genre = libraryStorage.createGenre()
                    genre.name = genreName
                    genre.syncInfo = syncWave
                    os_log("Genre <%s> has been created", log: log, type: .error, genreName)
                    albumBuffer?.genre = genre
                }
            }
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "album":
            parsedCount += 1
            albumBuffer = nil
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}

