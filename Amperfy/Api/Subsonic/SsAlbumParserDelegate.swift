import Foundation
import UIKit
import CoreData
import os.log

class SsAlbumParserDelegate: GenericXmlLibParser {
    
    private var subsonicUrlCreator: SubsonicUrlCreator
    private var albumBuffer: Album?
    var songCountOfAlbum = 0
    
    init(libraryStorage: LibraryStorage, syncWave: SyncWave, subsonicUrlCreator: SubsonicUrlCreator, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.subsonicUrlCreator = subsonicUrlCreator
        super.init(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: parseNotifier)
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        if(elementName == "album") {
            guard let albumId = attributeDict["id"],
                let attributeAlbumtName = attributeDict["name"],
                let artistId = attributeDict["artistId"],
                let attributeSongCount = attributeDict["songCount"],
                let songCount = Int(attributeSongCount) else {
                    return
            }

            if !syncWave.isInitialWave, let fetchedAlbum = libraryStorage.getAlbum(id: albumId)  {
                albumBuffer = fetchedAlbum
            } else {
                albumBuffer = libraryStorage.createAlbum()
            }
            
            albumBuffer?.syncInfo = syncWave
            albumBuffer?.id = albumId
            albumBuffer?.name = attributeAlbumtName
            albumBuffer?.artwork?.url = subsonicUrlCreator.getArtUrlString(forArtistId: albumId)
            
            if let attributeYear = attributeDict["year"], let year = Int(attributeYear) {
                albumBuffer?.year = year
            }
            
            if let artist = libraryStorage.getArtist(id: artistId) {
                albumBuffer?.artist = artist
            } else {
                os_log("Found album id %s with unknown artist id %s", log: log, type: .error, albumId, artistId)
            }
            
            songCountOfAlbum += songCount
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "album":
            parsedCount += 1
            parseNotifier?.notifyParsedObject()
            albumBuffer = nil
        default:
            break
        }
        
        buffer = ""
    }
    
}

