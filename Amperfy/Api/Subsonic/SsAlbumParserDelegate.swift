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
        
        if(elementName == "album") {
            guard let albumId = attributeDict["id"] else { return }

            if let fetchedAlbum = libraryStorage.getAlbum(id: albumId)  {
                albumBuffer = fetchedAlbum
            } else {
                albumBuffer = libraryStorage.createAlbum()
            }
            
            albumBuffer?.syncInfo = syncWave
            albumBuffer?.id = albumId
            if let attributeAlbumtName = attributeDict["name"] {
                albumBuffer?.name = attributeAlbumtName
            }
            albumBuffer?.artwork?.url = subsonicUrlCreator.getArtUrlString(forArtistId: albumId)
            
            if let attributeYear = attributeDict["year"], let year = Int(attributeYear) {
                albumBuffer?.year = year
            }
            
            if let artistId = attributeDict["artistId"], let artist = libraryStorage.getArtist(id: artistId) {
                albumBuffer?.artist = artist
            } else {
                os_log("Found album id %s with unknown artist", log: log, type: .error, albumId)
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

