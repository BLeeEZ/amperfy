import Foundation
import UIKit
import CoreData
import os.log

class SsSongParserDelegate: SsPlayableParserDelegate {
    
    var songBuffer: Song?
    var parsedSongs = [Song]()
    var guessedArtist: Artist?
    var guessedAlbum: Album?
    var guessedGenre: Genre?
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        if elementName == "song" || elementName == "entry" || elementName == "child" || elementName == "episode" {
            guard let songId = attributeDict["id"] else { return }
            guard let isDir = attributeDict["isDir"], let isDirBool = Bool(isDir), isDirBool == false else { return }
            
            if let fetchedSong = library.getSong(id: songId)  {
                songBuffer = fetchedSong
                songBuffer?.remoteStatus = .available
            } else {
                songBuffer = library.createSong()
                songBuffer?.id = songId
                songBuffer?.syncInfo = syncWave
            }
            playableBuffer = songBuffer

            if let artistId = attributeDict["artistId"] {
                if let guessedArtist = guessedArtist, guessedArtist.id == artistId {
                    songBuffer?.artist = guessedArtist
                    songBuffer?.artist?.remoteStatus = .available
                } else if let artist = library.getArtist(id: artistId) {
                    songBuffer?.artist = artist
                    songBuffer?.artist?.remoteStatus = .available
                } else if let artistName = attributeDict["artist"] {
                    let artist = library.createArtist()
                    artist.id = artistId
                    artist.name = artistName
                    artist.syncInfo = syncWave
                    os_log("Artist <%s> with id %s has been created", log: log, type: .error, artistName, artistId)
                    songBuffer?.artist = artist
                }
            } else if let songBuffer = songBuffer, let artistName = attributeDict["artist"] {
                if let existingLocalArtist = library.getArtistLocal(name: artistName) {
                    songBuffer.artist = existingLocalArtist
                } else {
                    let artist = library.createArtist()
                    artist.name = artistName
                    artist.syncInfo = syncWave
                    songBuffer.artist = artist
                    os_log("Local Artist <%s> has been created (no id)", log: log, type: .error, artistName)
                }
            }

            if let albumId = attributeDict["albumId"] {
                if let guessedAlbum = guessedAlbum, guessedAlbum.id == albumId {
                    songBuffer?.album = guessedAlbum
                    songBuffer?.album?.remoteStatus = .available
                } else if let album = library.getAlbum(id: albumId) {
                    songBuffer?.album = album
                    songBuffer?.album?.remoteStatus = .available
                } else if let albumName = attributeDict["album"] {
                    let album = library.createAlbum()
                    album.id = albumId
                    album.name = albumName
                    album.syncInfo = syncWave
                    os_log("Album <%s> with id %s has been created", log: log, type: .error, albumName, albumId)
                    songBuffer?.album = album
                }
            }
            
            if let genreName = attributeDict["genre"] {
                if let guessedGenre = guessedGenre, guessedGenre.name == genreName {
                    songBuffer?.genre = guessedGenre
                } else if let genre = library.getGenre(name: genreName) {
                    songBuffer?.genre = genre
                } else {
                    let genre = library.createGenre()
                    genre.name = genreName
                    genre.syncInfo = syncWave
                    os_log("Genre <%s> has been created", log: log, type: .error, genreName)
                    songBuffer?.genre = genre
                }
            }
        }
        
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "song" || elementName == "entry" || elementName == "child" || elementName == "episode", songBuffer != nil {
            parsedCount += 1
            playableBuffer = nil
            if let song = songBuffer {
                parsedSongs.append(song)
            }
            songBuffer = nil
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}
