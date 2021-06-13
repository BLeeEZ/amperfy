import Foundation
import UIKit
import CoreData
import os.log

class PlaylistParserDelegate: AmpacheNotifiableXmlParser {
    
    var playlist: Playlist?
    var library: LibraryStorage
    
    init(library: LibraryStorage, parseNotifier: ParsedObjectNotifiable?) {
        self.library = library
        super.init(parseNotifier: parseNotifier)
    }
    
    private func resetPlaylistInCaseOfError() {
        if playlist != nil {
            os_log("Error: Playlist has been removed on server -> local id reset", log: log, type: .error)
            playlist?.id = ""
            playlist = nil
        }
    }
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

        switch(elementName) {
        case "playlist":
            guard let playlistId = attributeDict["id"] else {
                os_log("Error: Playlist could not be parsed -> id is not given", log: log, type: .error)
                resetPlaylistInCaseOfError()
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
            }
        default:
            break
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "name":
            playlist?.name = buffer
        case "items":
            playlist?.songCount = Int(buffer) ?? 0
        case "playlist":
            playlist = nil
            parseNotifier?.notifyParsedObject(ofType: .playlist)
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}
