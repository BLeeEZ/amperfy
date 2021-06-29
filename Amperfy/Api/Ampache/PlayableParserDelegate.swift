import Foundation
import UIKit
import CoreData
import os.log

class PlayableParserDelegate: AmpacheXmlLibParser {

    var playableBuffer: AbstractPlayable?
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "title":
            playableBuffer?.title = buffer
        case "track":
            playableBuffer?.track = Int(buffer) ?? 0
        case "url":
            playableBuffer?.url = buffer
        case "year":
            playableBuffer?.year = Int(buffer) ?? 0
        case "time":
            playableBuffer?.duration = Int(buffer) ?? 0
        case "art":
            playableBuffer?.artwork = parseArtwork(urlString: buffer)
        case "size":
            playableBuffer?.size = Int(buffer) ?? 0
        case "bitrate":
            playableBuffer?.bitrate = Int(buffer) ?? 0
        case "mime":
            playableBuffer?.contentType = buffer
        case "disk":
            playableBuffer?.disk = buffer
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
