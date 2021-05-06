import Foundation
import UIKit
import CoreData
import os.log

class SsPlaylistSongsParserDelegate: SsSongParserDelegate {
    
    private let playlist: Playlist
    var items: [PlaylistItem]
    public private(set) var playlistHasBeenDetected = false
    
    init(playlist: Playlist, libraryStorage: LibraryStorage, syncWave: SyncWave) {
        self.playlist = playlist
        self.items = playlist.items
        super.init(libraryStorage: libraryStorage, syncWave: syncWave)
    }
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

        if elementName == "playlist" {
            guard let playlistId = attributeDict["id"] else { return }
            playlistHasBeenDetected = true
            if playlist.id != playlistId {
                playlist.id = playlistId
            }
            if let attributePlaylistName = attributeDict["name"] {
                playlist.name = attributePlaylistName
            }
            if let attributeSongCount = attributeDict["songCount"], let songCount = Int(attributeSongCount) {
                playlist.songCount = songCount
            }
        }
        
        if elementName == "entry" {
            let order = Int(parsedCount)
            var item: PlaylistItem?
            
            if order < items.count {
                item = items[order]
            } else {
                item = libraryStorage.createPlaylistItem()
                item?.order = order
                playlist.add(item: item!)
            }
            item?.song = songBuffer
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
        
        switch(elementName) {
        case "playlist":
            if items.count > parsedCount {
                for i in Array(parsedCount...items.count-1) {
                    libraryStorage.deletePlaylistItem(item: items[i])
                }
            }
        default:
            break
        }
        
        buffer = ""
    }
    
}
