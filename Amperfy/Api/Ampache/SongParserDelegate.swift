import Foundation
import UIKit
import CoreData
import os.log

class SongParserDelegate: AmpacheXmlLibParser {

    var songBuffer: Song?
    var genreIdToCreate: String?
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        switch(elementName) {
        case "song":
            guard let songId = attributeDict["id"] else {
                os_log("Found song with no id", log: log, type: .error)
                return
            }
            if let fetchedSong = libraryStorage.getSong(id: songId)  {
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
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
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
            songBuffer?.artwork = parseArtwork(urlString: buffer)
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
                os_log("Genre <%s> with id %s has been created", log: log, type: .error, buffer, genreId)
                let genre = libraryStorage.createGenre()
                genre.id = genreId
                genre.name = buffer
                genre.syncInfo = syncWave
                songBuffer?.genre = genre
                genreIdToCreate = nil
            }
        case "song":
            parsedCount += 1
            parseNotifier?.notifyParsedObject(ofType: .song)
            songBuffer = nil
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
