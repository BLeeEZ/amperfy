import Foundation
import UIKit
import CoreData
import os.log

class SsPodcastParserDelegate: SsXmlLibWithArtworkParser {
    
    private var podcastBuffer: Podcast?
    private let oldPodcasts: Set<Podcast>
    private var parsedPodcasts: Set<Podcast>
    
    override init(library: LibraryStorage, syncWave: SyncWave, subsonicUrlCreator: SubsonicUrlCreator, parseNotifier: ParsedObjectNotifiable? = nil) {
        oldPodcasts = Set(library.getPodcasts())
        parsedPodcasts = Set<Podcast>()
        super.init(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator, parseNotifier: parseNotifier)
    }
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        if elementName == "channel" {
            guard let podcastId = attributeDict["id"] else { return }
            guard let attributePodcastStatus = attributeDict["status"], attributePodcastStatus != "error" else { return }
            
            if let fetchedPodcast = library.getPodcast(id: podcastId)  {
                podcastBuffer = fetchedPodcast
            } else {
                podcastBuffer = library.createPodcast()
                podcastBuffer?.id = podcastId
            }
            
            if let attributePodcastTitle = attributeDict["title"] {
                podcastBuffer?.title = attributePodcastTitle
            }
            if let attributeDescription = attributeDict["description"] {
                podcastBuffer?.depiction = attributeDescription
            }
            if let attributeCoverArt = attributeDict["coverArt"] {
                podcastBuffer?.artwork = parseArtwork(id: attributeCoverArt)
            }
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "channel":
            parsedCount += 1
            if let parsedPodcast = podcastBuffer {
                parsedPodcasts.insert(parsedPodcast)
            }
            podcastBuffer = nil
        case "podcasts":
            let outdatedPodcasts = oldPodcasts.subtracting(parsedPodcasts)
            outdatedPodcasts.forEach{ library.deletePodcast($0) }
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}

