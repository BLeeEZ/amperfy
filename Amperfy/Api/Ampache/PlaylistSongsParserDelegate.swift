import Foundation
import UIKit
import CoreData

class PlaylistSongsParserDelegate: GenericXmlParser {

    let playlist: Playlist
    let libraryStorage: LibraryStorage
    var playlistItemBuffer: PlaylistItem?

    init(playlist: Playlist, libraryStorage: LibraryStorage) {
        self.playlist = playlist
        self.libraryStorage = libraryStorage
        super.init()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        switch(elementName) {
        case "song":
            if let songId = attributeDict["id"], let fetchedSong = libraryStorage.getSong(id: songId) {
                playlistItemBuffer = libraryStorage.createPlaylistItem()
                playlistItemBuffer?.song = fetchedSong
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "playlisttrack":
            var order = 0
            if let playlistItemOrder = Int(buffer), playlistItemOrder > 0 {
                // Ampache playlist order is one-based -> Amperfy playlist order is zero-based
                order = playlistItemOrder - 1
            }
            playlistItemBuffer?.order = order
        case "song":
            if let item = playlistItemBuffer {
                playlist.add(item: item)
            }
            playlistItemBuffer = nil
        default:
            break
        }
        
        buffer = ""
    }


}
