import Foundation
import UIKit
import CoreData
import os.log

class PodcastParserDelegate: AmpacheXmlLibParser {
    
    var parsedPodcasts: Set<Podcast>
    private var podcastBuffer: Podcast?
    var rating: Int = 0

    override init(library: LibraryStorage, syncWave: SyncWave, parseNotifier: ParsedObjectNotifiable? = nil) {
        parsedPodcasts = Set<Podcast>()
        super.init(library: library, syncWave: syncWave, parseNotifier: parseNotifier)
    }
    
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
            podcastBuffer?.remoteStatus = .available
        default:
            break
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "name":
            podcastBuffer?.title = buffer.html2String
        case "description":
            podcastBuffer?.depiction = buffer.html2String
        case "rating":
            rating = Int(buffer) ?? 0
        case "art":
            podcastBuffer?.artwork = parseArtwork(urlString: buffer)
        case "podcast":
            podcastBuffer?.rating = rating
            rating = 0
            if let parsedPodcast = podcastBuffer {
                parsedPodcasts.insert(parsedPodcast)
            }
            podcastBuffer = nil
            parseNotifier?.notifyParsedObject(ofType: .podcast)
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}
