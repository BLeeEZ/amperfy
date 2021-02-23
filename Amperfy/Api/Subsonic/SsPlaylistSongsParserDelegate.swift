import Foundation
import UIKit
import CoreData
import os.log

class SsPlaylistSongsParserDelegate: GenericXmlParser {
    
    private let playlist: Playlist
    private let libraryStorage: LibraryStorage
    public private(set) var playlistHasBeenDetected = false
    
    init(playlist: Playlist, libraryStorage: LibraryStorage) {
        self.playlist = playlist
        self.libraryStorage = libraryStorage
        super.init()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""

        if elementName == "playlist" {
            guard let playlistId = attributeDict["id"],
                let attributePlaylistName = attributeDict["name"] else {
                    return
            }
            playlistHasBeenDetected = true
            playlist.id = playlistId
            playlist.name = attributePlaylistName
        }
        
        if elementName == "entry" {
            guard let songEntryId = attributeDict["id"],
                let fetchedSong = libraryStorage.getSong(id: songEntryId) else {
                    return
            }
            
            let playlistItem = libraryStorage.createPlaylistItem()
            playlistItem.order = Int(parsedCount)
            playlistItem.song = fetchedSong
            playlist.add(item: playlistItem)
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "entry":
            parsedCount += 1
        default:
            break
        }
        
        buffer = ""
    }
    
}
