import Foundation
import UIKit
import CoreData
import os.log

class SsPlaylistParserDelegate: GenericXmlParser {
    
    private var playlist: Playlist?
    private let libraryStorage: LibraryStorage
    
    init(libraryStorage: LibraryStorage) {
        self.libraryStorage = libraryStorage
        super.init()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        if(elementName == "playlist") {
            guard let playlistId = attributeDict["id"],
                let attributePlaylistName = attributeDict["name"] else {
                    return
            }
            
            if playlist != nil {
                playlist?.id = playlistId
            } else if playlistId != "" {
                if let fetchedPlaylist = libraryStorage.getPlaylist(id: playlistId)  {
                    playlist = fetchedPlaylist
                } else {
                    playlist = libraryStorage.createPlaylist()
                    playlist?.id = playlistId
                }
            } else {
                os_log("Error: Playlist could not be parsed -> id is not given", log: log, type: .error)
                return
            }
            
            playlist?.name = attributePlaylistName
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "playlist":
            parsedCount += 1
            playlist = nil
        default:
            break
        }
        
        buffer = ""
    }
    
}
