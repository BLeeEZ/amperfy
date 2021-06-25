import Foundation
import UIKit
import CoreData
import os.log

class SsPodcastEpisodeParserDelegate: SsSongParserDelegate {
    
    var podcast: Podcast
    var episodeBuffer: PodcastEpisode?
    
    init(podcast: Podcast, library: LibraryStorage, syncWave: SyncWave, subsonicUrlCreator: SubsonicUrlCreator) {
        self.podcast = podcast
        super.init(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicUrlCreator)
    }
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        if elementName == "episode" {
            guard let episodeId = attributeDict["id"] else {
                os_log("Found podcast episode with no id", log: log, type: .error)
                return
            }
            if let fetchedEpisode = library.getPodcastEpisode(id: episodeId)  {
                episodeBuffer = fetchedEpisode
            } else {
                episodeBuffer = library.createPodcastEpisode()
                episodeBuffer?.id = episodeId
                songBuffer = library.createSong()
                songBuffer?.syncInfo = syncWave
                episodeBuffer?.playInfo = songBuffer
            }
            episodeBuffer?.podcast = podcast

            if let description = attributeDict["description"] {
                episodeBuffer?.depiction = description
            }
            if let publishDate = attributeDict["publishDate"], publishDate.count >= 19 {
                //"2011-02-03T14:46:43"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                dateFormatter.timeZone = NSTimeZone(name: "UTC")! as TimeZone
                let dateWithoutTimeZoneString = String(publishDate[..<publishDate.index(publishDate.startIndex, offsetBy: 19)])
                episodeBuffer?.publishDate = dateFormatter.date(from: dateWithoutTimeZoneString) ?? Date(timeIntervalSince1970: TimeInterval())
            }
            if let status = attributeDict["status"] {
                episodeBuffer?.remoteStatus = PodcastEpisodeRemoteStatus.create(from: status)
            }
            if let streamId = attributeDict["streamId"] {
                episodeBuffer?.streamId = streamId
            }
            if let coverArtId = attributeDict["coverArt"] {
                episodeBuffer?.artwork = parseArtwork(id: coverArtId)
            }
        }
        
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
        
        if elementName == "episode", episodeBuffer != nil {
            episodeBuffer = nil
        }
    }
    
}
