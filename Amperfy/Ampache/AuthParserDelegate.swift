import Foundation
import UIKit
import CoreData

class AuthParserDelegate: AmpacheParser {
    
    var authHandshake: AuthentificationHandshake?
    private var authBuffer = AuthentificationHandshake()
    private let safetyOffsetTimeBeforeSessionExpireInMinutes:TimeInterval = -5.0 * 60.0
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "auth":
            authBuffer.token = buffer
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
        case "tags":
            authBuffer.tagCount = Int(buffer) ?? 0
        case "videos":
            authBuffer.videoCount = Int(buffer) ?? 0
        case "root":
            authHandshake = (!authBuffer.token.isEmpty ? authBuffer : nil)
        default:
            break
        }
        
        buffer = ""
    }
    
}
