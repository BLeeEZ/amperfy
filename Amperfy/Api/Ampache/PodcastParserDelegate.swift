import Foundation
import UIKit
import CoreData
import os.log

class PodcastParserDelegate: AmpacheXmlLibParser {
    
    var podcastBuffer: Podcast?
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

        switch(elementName) {
        case "podcast":
            guard let podcastId = attributeDict["id"] else {
                os_log("Error: Podcast could not be parsed -> id is not given", log: log, type: .error)
                return
            }
            if let fetchedPodcast = library.getPodcast(id: podcastId)  {
                podcastBuffer = fetchedPodcast
            } else {
                podcastBuffer = library.createPodcast()
                podcastBuffer?.id = podcastId
            }
        default:
            break
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "name":
            podcastBuffer?.title = buffer
        case "description":
            podcastBuffer?.depiction = buffer
        case "art":
            podcastBuffer?.artwork = parseArtwork(urlString: buffer)
        case "podcast":
            podcastBuffer = nil
            parseNotifier?.notifyParsedObject(ofType: .podcast)
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}
