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
            guard let attributeId = attributeDict["id"],
                let playlistId = Int32(attributeId),
                let attributePlaylistName = attributeDict["name"] else {
                    return
            }
            playlistHasBeenDetected = true
            playlist.id = playlistId
            playlist.name = attributePlaylistName
        }
        
        if elementName == "entry" {
            guard let attributeId = attributeDict["id"],
                let songEntryId = Int32(attributeId),
                let fetchedSong = libraryStorage.getSong(id: songEntryId) else {
                    return
            }
            
            let playlistEntry = libraryStorage.createPlaylistElement()
            playlistEntry.order = Int32(parsedCount)
            playlistEntry.song = fetchedSong
            playlist.add(entry: playlistEntry)
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
