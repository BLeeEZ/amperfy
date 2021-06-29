import Foundation
import UIKit
import CoreData
import os.log

class SsPlayableParserDelegate: SsXmlLibWithArtworkParser {
    
    var playableBuffer: AbstractPlayable?
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        if elementName == "song" || elementName == "entry" || elementName == "child" || elementName == "episode" {
            guard let isDir = attributeDict["isDir"], let isDirBool = Bool(isDir), isDirBool == false else { return }
            
            if let attributeTitle = attributeDict["title"] {
                playableBuffer?.title = attributeTitle
            }
            if let attributeTrack = attributeDict["track"], let track = Int(attributeTrack) {
                playableBuffer?.track = track
            }
            if let attributeYear = attributeDict["year"], let year = Int(attributeYear) {
                playableBuffer?.year = year
            }
            if let attributeDuration = attributeDict["duration"], let duration = Int(attributeDuration) {
                playableBuffer?.duration = duration
            }
            if let attributeSize = attributeDict["size"], let size = Int(attributeSize) {
                playableBuffer?.size = size
            }
            if let attributeBitrate = attributeDict["bitRate"], let bitrate = Int(attributeBitrate) {
                playableBuffer?.bitrate = bitrate * 1000 // kb per second -> save as byte per second
            }
            if let contentType = attributeDict["contentType"] {
                playableBuffer?.contentType = contentType
            }
            if let disk = attributeDict["discNumber"] {
                playableBuffer?.disk = disk
            }
            if let coverArtId = attributeDict["coverArt"] {
                playableBuffer?.artwork = parseArtwork(id: coverArtId)
            }
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "song" || elementName == "entry" || elementName == "child" || elementName == "episode", playableBuffer != nil {
            playableBuffer = nil
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}
