import Foundation
import UIKit
import CoreData

class PlaylistSongsParserDelegate: GenericXmlParser {

    let playlist: Playlist
    let libraryStorage: LibraryStorage
    var playlistElementBuffer: PlaylistElement?

    init(playlist: Playlist, libraryStorage: LibraryStorage) {
        self.playlist = playlist
        self.libraryStorage = libraryStorage
        super.init()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        switch(elementName) {
        case "song":
            if let songId = Int32(attributeDict["id"] ?? "0"), let fetchedSong = libraryStorage.getSong(id: songId) {
                playlistElementBuffer = libraryStorage.createPlaylistElement()
                playlistElementBuffer?.song = fetchedSong
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "playlisttrack":
            playlistElementBuffer?.order = Int32(buffer) ?? 0
        case "song":
            if let entry = playlistElementBuffer {
                playlist.add(entry: entry)
            }
            playlistElementBuffer = nil
        default:
            break
        }
        
        buffer = ""
    }


}
