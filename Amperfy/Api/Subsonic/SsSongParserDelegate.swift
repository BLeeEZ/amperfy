import Foundation
import UIKit
import CoreData
import os.log

class SsSongParserDelegate: GenericXmlLibParser {
    
    private var subsonicUrlCreator: SubsonicUrlCreator
    private var songBuffer: Song?
    var guessedArtist: Artist?
    var guessedAlbum: Album?
    
    init(libraryStorage: LibraryStorage, syncWave: SyncWave, subsonicUrlCreator: SubsonicUrlCreator, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.subsonicUrlCreator = subsonicUrlCreator
        super.init(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: parseNotifier)
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        if elementName == "song" {
            guard let songId = attributeDict["id"] else { return }
            
            if let fetchedSong = libraryStorage.getSong(id: songId)  {
                songBuffer = fetchedSong
            } else {
                songBuffer = libraryStorage.createSong()
                songBuffer?.id = songId
                songBuffer?.syncInfo = syncWave
                
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
            }

            if songBuffer?.artist == nil, let artistId = attributeDict["artistId"] {
                if let guessedArtist = guessedArtist, guessedArtist.id == artistId {
                    songBuffer?.artist = guessedArtist
                } else if let artist = libraryStorage.getArtist(id: artistId) {
                    songBuffer?.artist = artist
                }
            }

            if songBuffer?.album == nil, let albumId = attributeDict["albumId"] {
                if let guessedAlbum = guessedAlbum, guessedAlbum.id == albumId {
                    songBuffer?.album = guessedAlbum
                } else if let album = libraryStorage.getAlbum(id: albumId) {
                    songBuffer?.album = album
                    songBuffer?.artwork?.url = subsonicUrlCreator.getArtUrlString(forArtistId: albumId)
                }
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "song":
            parsedCount += 1
            songBuffer = nil
        default:
            break
        }
        
        buffer = ""
    }
    
}
