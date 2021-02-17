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
            guard let songIdStr = attributeDict["id"] else {
                os_log("Found song with no id", log: log, type: .error)
                return
            }
            guard let songId = Int(songIdStr) else {
                os_log("Found song non integer id: %s", log: log, type: .error, songIdStr)
                return
            }
            if !syncWave.isInitialWave, let fetchedSong = libraryStorage.getSong(id: songId)  {
                songBuffer = fetchedSong
            } else {
                songBuffer = libraryStorage.createSong()
                songBuffer?.syncInfo = syncWave
                songBuffer?.id = Int(attributeDict["id"] ?? "0") ?? 0
            }
        case "artist":
            if let song = songBuffer {
                guard let artistIdStr = attributeDict["id"] else {
                    os_log("Found song id %d with no artist id. Title: %s", log: log, type: .error, song.id, song.title)
                    return
                }
                guard let artistId = Int(artistIdStr) else {
                    os_log("Found song id %d with non integer artist id %s. Title: %s", log: log, type: .error, song.id, artistIdStr, song.title)
                    return
                }
                if let artist = libraryStorage.getArtist(id: artistId) {
                    song.artist = artist
                } else {
                    os_log("Found song id %d with unknown artist %d. Title: %s", log: log, type: .error, song.id, artistId, song.title)
                }
            }
        case "album":
            if let song = songBuffer {
                guard let albumIdStr = attributeDict["id"] else {
                    os_log("Found song id %d with no album id. Title: %s", log: log, type: .error, songBuffer!.id, song.title)
                    return
                }
                guard let albumId = Int(albumIdStr) else {
                    os_log("Found song id %d with non integer album id %s. Title: %s", log: log, type: .error, songBuffer!.id, albumIdStr, song.title)
                    return
                }
                if let album = libraryStorage.getAlbum(id: albumId)  {
                    song.album = album
                } else {
                    os_log("Found song id %d with unknown album %d. Title: %s", log: log, type: .error, songBuffer!.id, albumId, song.title)
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
