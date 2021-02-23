import Foundation
import UIKit
import CoreData
import os.log

class SsSongParserDelegate: GenericXmlLibParser {
    
    private var subsonicUrlCreator: SubsonicUrlCreator
    private var songBuffer: Song?
    
    init(libraryStorage: LibraryStorage, syncWave: SyncWave, subsonicUrlCreator: SubsonicUrlCreator, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.subsonicUrlCreator = subsonicUrlCreator
        super.init(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: parseNotifier)
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        if(elementName == "song") {
            guard let songId = attributeDict["id"],
                let attributeSongTitle = attributeDict["title"],
                let artistId = attributeDict["artistId"],
                let albumId = attributeDict["albumId"] else {
                    return
            }
            
            if !syncWave.isInitialWave, let fetchedSong = libraryStorage.getSong(id: songId)  {
                songBuffer = fetchedSong
            } else {
                songBuffer = libraryStorage.createSong()
            }
            
            songBuffer?.syncInfo = syncWave
            songBuffer?.id = songId
            songBuffer?.title = attributeSongTitle
            songBuffer?.artwork?.url = subsonicUrlCreator.getArtUrlString(forArtistId: albumId)
            
            if let attributeTrack = attributeDict["track"], let track = Int(attributeTrack) {
                songBuffer?.track = track
            }
            
            if let artist = libraryStorage.getArtist(id: artistId) {
                songBuffer?.artist = artist
            } else {
                os_log("Found song id %s with unknown artist id %s", log: log, type: .error, songId, artistId)
            }

            if let album = libraryStorage.getAlbum(id: albumId) {
                songBuffer?.album = album
            } else {
                os_log("Found song id %s with unknown album id %s", log: log, type: .error, songId, albumId)
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "song":
            parsedCount += 1
            parseNotifier?.notifyParsedObject()
            songBuffer = nil
        default:
            break
        }
        
        buffer = ""
    }
    
}
