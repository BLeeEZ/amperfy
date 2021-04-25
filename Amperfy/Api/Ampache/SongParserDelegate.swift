import Foundation
import UIKit
import CoreData
import os.log

class SongParserDelegate: GenericXmlLibParser {

    var songBuffer: Song?
    var genreIdToCreate: String?
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        switch(elementName) {
        case "song":
            guard let songId = attributeDict["id"] else {
                os_log("Found song with no id", log: log, type: .error)
                return
            }
            if !syncWave.isInitialWave, let fetchedSong = libraryStorage.getSong(id: songId)  {
                songBuffer = fetchedSong
            } else {
                songBuffer = libraryStorage.createSong()
                songBuffer?.syncInfo = syncWave
                songBuffer?.id = songId
            }
        case "artist":
            if let song = songBuffer {
                guard let artistId = attributeDict["id"] else {
                    os_log("Found song id %s with no artist id. Title: %s", log: log, type: .error, song.id, song.title)
                    return
                }
                if let artist = libraryStorage.getArtist(id: artistId) {
                    song.artist = artist
                } else {
                    os_log("Found song id %s with unknown artist id %s. Title: %s", log: log, type: .error, song.id, artistId, song.title)
                }
            }
        case "album":
            if let song = songBuffer {
                guard let albumId = attributeDict["id"] else {
                    os_log("Found song id %s with no album id. Title: %s", log: log, type: .error, song.id, song.title)
                    return
                }
                if let album = libraryStorage.getAlbum(id: albumId)  {
                    song.album = album
                } else {
                    os_log("Found song id %s with unknown album id %s. Title: %s", log: log, type: .error, song.id, albumId, song.title)
                }
            }
        case "genre":
            if let song = songBuffer {
                guard let genreId = attributeDict["id"] else { return }
                if let genre = libraryStorage.getGenre(id: genreId) {
                    song.genre = genre
                } else {
                    genreIdToCreate = genreId
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
        case "year":
            songBuffer?.year = Int(buffer) ?? 0
        case "time":
            songBuffer?.duration = Int(buffer) ?? 0
        case "art":
            songBuffer?.artwork?.url = buffer
        case "size":
            songBuffer?.size = Int(buffer) ?? 0
        case "bitrate":
            songBuffer?.bitrate = Int(buffer) ?? 0
        case "mime":
            songBuffer?.contentType = buffer
        case "disk":
            songBuffer?.disk = buffer
        case "genre":
            if let genreId = genreIdToCreate {
                os_log("Genre <%s> with id %s has been created", log: log, type: .error, genreId, buffer)
                let genre = libraryStorage.createGenre()
                genre.id = genreId
                genre.name = buffer
                genre.syncInfo = syncWave
                songBuffer?.genre = genre
                genreIdToCreate = nil
            }
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
