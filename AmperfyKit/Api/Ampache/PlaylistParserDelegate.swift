import Foundation
import UIKit
import CoreData
import os.log

class PlaylistParserDelegate: AmpacheNotifiableXmlParser {
    
    private var playlist: Playlist?
    private var playlistToValidate: Playlist?
    private let oldPlaylists: Set<Playlist>
    private var parsedPlaylists: Set<Playlist>
    private var library: LibraryStorage
    
    init(library: LibraryStorage, parseNotifier: ParsedObjectNotifiable?, playlistToValidate: Playlist? = nil) {
        self.library = library
        self.playlist = playlistToValidate
        self.playlistToValidate = playlistToValidate
        oldPlaylists = Set(library.getPlaylists())
        parsedPlaylists = Set<Playlist>()
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
            if let parsedPlaylist = playlist {
                parsedPlaylists.insert(parsedPlaylist)
            }
            playlist = nil
            parseNotifier?.notifyParsedObject(ofType: .playlist)
        case "root":
            if playlistToValidate == nil {
                let outdatedPlaylists = oldPlaylists.subtracting(parsedPlaylists)
                outdatedPlaylists.forEach{
                    if $0.id != "" {
                        library.deletePlaylist($0)
                    }
                }
            }
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}
