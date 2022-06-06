import Foundation
import UIKit
import CoreData
import os.log

class SsPlaylistParserDelegate: SsXmlParser {
    
    private var playlist: Playlist?
    private let oldPlaylists: Set<Playlist>
    private var parsedPlaylists: Set<Playlist>
    private let library: LibraryStorage
    
    init(library: LibraryStorage) {
        self.library = library
        oldPlaylists = Set(library.getPlaylists())
        parsedPlaylists = Set<Playlist>()
        super.init()
    }

    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        if(elementName == "playlist") {
            guard let playlistId = attributeDict["id"],
                let attributePlaylistName = attributeDict["name"] else {
                    return
            }
            
            if playlist != nil {
                playlist?.id = playlistId
            } else if playlistId != "" {
                if let fetchedPlaylist = library.getPlaylist(id: playlistId)  {
                    playlist = fetchedPlaylist
                } else {
                    playlist = library.createPlaylist()
                    playlist?.id = playlistId
                }
            } else {
                os_log("Error: Playlist could not be parsed -> id is not given", log: log, type: .error)
                return
            }
            
            playlist?.name = attributePlaylistName
            
            if let attributeSongCount = attributeDict["songCount"], let songCount = Int(attributeSongCount) {
                playlist?.songCount = songCount
            }
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "playlist":
            parsedCount += 1
            if let parsedPlaylist = playlist {
                parsedPlaylists.insert(parsedPlaylist)
            }
            playlist = nil
        case "playlists":
            let outdatedPlaylists = oldPlaylists.subtracting(parsedPlaylists)
            outdatedPlaylists.forEach{
                if $0.id != "" {
                    library.deletePlaylist($0)
                }
            }
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}
