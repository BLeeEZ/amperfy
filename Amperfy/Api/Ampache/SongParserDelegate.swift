import Foundation
import UIKit
import CoreData
import os.log

class SongParserDelegate: PlayableParserDelegate {

    var songBuffer: Song?
    var parsedSongs = [Song]()
    var artistIdToCreate: String?
    var albumIdToCreate: String?
    var genreIdToCreate: String?
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        switch(elementName) {
        case "song":
            guard let songId = attributeDict["id"] else {
                os_log("Found song with no id", log: log, type: .error)
                return
            }
            if let fetchedSong = library.getSong(id: songId)  {
                songBuffer = fetchedSong
            } else {
                songBuffer = library.createSong()
                songBuffer?.syncInfo = syncWave
                songBuffer?.id = songId
            }
            playableBuffer = songBuffer
        case "artist":
            guard let song = songBuffer, let artistId = attributeDict["id"] else { return }
            if let artist = library.getArtist(id: artistId) {
                song.artist = artist
            } else {
                artistIdToCreate = artistId
            }
        case "album":
            guard let song = songBuffer, let albumId = attributeDict["id"] else { return }
            if let album = library.getAlbum(id: albumId)  {
                song.album = album
            } else {
                albumIdToCreate = albumId
            }
        case "genre":
            guard let song = songBuffer, let genreId = attributeDict["id"] else { return }
            if let genre = library.getGenre(id: genreId) {
                song.genre = genre
            } else {
                genreIdToCreate = genreId
            }
        default:
            break
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "artist":
            if let artistId = artistIdToCreate {
                os_log("Artist <%s> with id %s has been created", log: log, type: .error, buffer, artistId)
                let artist = library.createArtist()
                artist.id = artistId
                artist.name = buffer
                artist.syncInfo = syncWave
                songBuffer?.artist = artist
                artistIdToCreate = nil
            }
        case "album":
            if let albumId = albumIdToCreate {
                os_log("Album <%s> with id %s has been created", log: log, type: .error, buffer, albumId)
                let album = library.createAlbum()
                album.id = albumId
                album.name = buffer
                album.syncInfo = syncWave
                songBuffer?.album = album
                albumIdToCreate = nil
            }
        case "genre":
            if let genreId = genreIdToCreate {
                os_log("Genre <%s> with id %s has been created", log: log, type: .error, buffer, genreId)
                let genre = library.createGenre()
                genre.id = genreId
                genre.name = buffer
                genre.syncInfo = syncWave
                songBuffer?.genre = genre
                genreIdToCreate = nil
            }
        case "song":
            parsedCount += 1
            parseNotifier?.notifyParsedObject(ofType: .song)
            playableBuffer = nil
            if let song = songBuffer {
                parsedSongs.append(song)
            }
            songBuffer = nil
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
