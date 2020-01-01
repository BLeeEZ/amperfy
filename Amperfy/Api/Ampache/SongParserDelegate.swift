import Foundation
import UIKit
import CoreData
import os.log

class SongParserDelegate: GenericXmlLibParser {

    var songBuffer: Song?
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        switch(elementName) {
        case "song":
            if !syncWave.isInitialWave, let songId = Int(attributeDict["id"] ?? "0"), let fetchedSong = libraryStorage.getSong(id: songId)  {
                songBuffer = fetchedSong
            } else {
                songBuffer = libraryStorage.createSong()
                songBuffer?.syncInfo = syncWave
                songBuffer?.id = Int(attributeDict["id"] ?? "0") ?? 0
            }
        case "artist":
            if let song = songBuffer {
                let artistId = Int(attributeDict["id"] ?? "0") ?? 0
                if let artist = libraryStorage.getArtist(id: artistId) {
                    song.artist = artist
                } else {
                    os_log("Found song id %d with unknown artist %d", log: log, type: .error, song.id, artistId)
                }
            }
        case "album":
            if let song = songBuffer {
                let albumId = Int(attributeDict["id"] ?? "0") ?? 0
                if let album = libraryStorage.getAlbum(id: albumId)  {
                    song.album = album
                }
                else {
                    os_log("Found song id %d with unknown album %d", log: log, type: .error, songBuffer!.id, albumId)
                }
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "title":
            songBuffer?.title = buffer
        case "track":
            songBuffer?.track = Int(buffer) ?? 0
        case "url":
            songBuffer?.url = buffer
        case "art":
            songBuffer?.artwork?.url = buffer
        case "song":
            if let song = songBuffer, let artwork = song.artwork, let album = song.album {
                libraryStorage.deleteArtwork(artwork: artwork)
                song.artwork = album.artwork
            }
            parsedCount += 1
            parseNotifier?.notifyParsedObject()
            songBuffer = nil
        default:
            break
        }
        
        buffer = ""
    }

}
