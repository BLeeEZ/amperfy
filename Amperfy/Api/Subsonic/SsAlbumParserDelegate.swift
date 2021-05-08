import Foundation
import UIKit
import CoreData
import os.log

class SsAlbumParserDelegate: GenericXmlLibParser {
    
    private var subsonicUrlCreator: SubsonicUrlCreator
    private var albumBuffer: Album?
    
    init(libraryStorage: LibraryStorage, syncWave: SyncWave, subsonicUrlCreator: SubsonicUrlCreator, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.subsonicUrlCreator = subsonicUrlCreator
        super.init(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: parseNotifier)
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        if elementName == "album" {
            guard let albumId = attributeDict["id"] else { return }
            var isAlbumCreated = false
            
            if let fetchedAlbum = libraryStorage.getAlbum(id: albumId)  {
                albumBuffer = fetchedAlbum
            } else {
                albumBuffer = libraryStorage.createAlbum()
                albumBuffer?.id = albumId
                albumBuffer?.syncInfo = syncWave
                isAlbumCreated = true
            }
            
            if isAlbumCreated || isLibraryVersionResync {
                if let attributeAlbumtName = attributeDict["name"] {
                    albumBuffer?.name = attributeAlbumtName
                }
                if let albumArtwork = albumBuffer?.artwork, albumArtwork.url.isEmpty {
                    albumArtwork.url = subsonicUrlCreator.getArtUrlString(forArtistId: albumId)
                }
                
                if let attributeYear = attributeDict["year"], let year = Int(attributeYear) {
                    albumBuffer?.year = year
                }
            }
            
            if albumBuffer?.artist == nil, let artistId = attributeDict["artistId"], let artist = libraryStorage.getArtist(id: artistId) {
                albumBuffer?.artist = artist
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
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "album":
            parsedCount += 1
            albumBuffer = nil
        default:
            break
        }
        
        buffer = ""
    }
    
}

