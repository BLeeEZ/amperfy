import Foundation
import UIKit
import CoreData

class AuthParserDelegate: AmpacheXmlParser {
    
    var authHandshake: AuthentificationHandshake?
    var serverApiVersion: String?
    private var authBuffer = AuthentificationHandshake()
    private let safetyOffsetTimeBeforeSessionExpireInMinutes:TimeInterval = -5.0 * 60.0
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "auth":
            authBuffer.token = buffer
        case "api":
            serverApiVersion = buffer
        case "session_expire":
            authBuffer.sessionExpire = buffer.asIso8601Date ?? Date()
            authBuffer.reauthenicateTime = Date(timeInterval: safetyOffsetTimeBeforeSessionExpireInMinutes, since: authBuffer.sessionExpire)
        case "update":
            authBuffer.libraryChangeDates.dateOfLastUpdate = buffer.asIso8601Date ?? Date()
        case "add":
            authBuffer.libraryChangeDates.dateOfLastAdd = buffer.asIso8601Date ?? Date()
        case "clean":
            authBuffer.libraryChangeDates.dateOfLastClean = buffer.asIso8601Date ?? Date()
        case "songs":
            authBuffer.songCount = Int(buffer) ?? 0
        case "artists":
            authBuffer.artistCount = Int(buffer) ?? 0
        case "albums":
            authBuffer.albumCount = Int(buffer) ?? 0
        case "genres":
            authBuffer.genreCount = Int(buffer) ?? 0
        case "playlists":
            authBuffer.playlistCount = Int(buffer) ?? 0
        case "podcasts":
            authBuffer.podcastCount = Int(buffer) ?? 0
        case "videos":
            authBuffer.videoCount = Int(buffer) ?? 0
        case "root":
            authHandshake = (!authBuffer.token.isEmpty ? authBuffer : nil)
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}
