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
            guard let songId = attributeDict["id"] else { return }
            
            if !syncWave.isInitialWave, let fetchedSong = libraryStorage.getSong(id: songId)  {
                songBuffer = fetchedSong
            } else {
                songBuffer = libraryStorage.createSong()
            }
            
            songBuffer?.syncInfo = syncWave
            songBuffer?.id = songId
            
            if let attributeTitle = attributeDict["title"] {
                songBuffer?.title = attributeTitle
            }
            if let attributeTrack = attributeDict["track"], let track = Int(attributeTrack) {
                songBuffer?.track = track
            }
            if let attributeYear = attributeDict["year"], let year = Int(attributeYear) {
                songBuffer?.year = year
            }
            if let attributeDuration = attributeDict["duration"], let duration = Int(attributeDuration) {
                songBuffer?.duration = duration
            }
            
            if let artistId = attributeDict["artistId"] {
                if let artist = libraryStorage.getArtist(id: artistId) {
                    songBuffer?.artist = artist
                } else {
                    os_log("Found song id %s with unknown artist id %s", log: log, type: .error, songId, artistId)
                }
            } else {
                os_log("Found song id %s has no artist", log: log, type: .error, songId)
            }

            if let albumId = attributeDict["albumId"] {
                if let album = libraryStorage.getAlbum(id: albumId) {
                    songBuffer?.album = album
                    songBuffer?.artwork?.url = subsonicUrlCreator.getArtUrlString(forArtistId: albumId)
                } else {
                    os_log("Found song id %s with unknown album id %s", log: log, type: .error, songId, albumId)
                }
            } else {
                os_log("Found song id %s has no album", log: log, type: .error, songId)
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
