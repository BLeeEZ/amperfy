import Foundation
import UIKit
import CoreData
import os.log

class PodcastEpisodeParserDelegate: PlayableParserDelegate {

    var podcast: Podcast
    var episodeBuffer: PodcastEpisode?
    var parsedEpisodes = [PodcastEpisode]()

    init(podcast: Podcast, library: LibraryStorage, syncWave: SyncWave) {
        self.podcast = podcast
        super.init(library: library, syncWave: syncWave, parseNotifier: nil)
    }
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        switch(elementName) {
        case "podcast_episode":
            guard let episodeId = attributeDict["id"] else {
                os_log("Found podcast episode with no id", log: log, type: .error)
                return
            }
            if let fetchedEpisode = library.getPodcastEpisode(id: episodeId)  {
                episodeBuffer = fetchedEpisode
            } else {
                episodeBuffer = library.createPodcastEpisode()
                episodeBuffer?.id = episodeId
            }
            playableBuffer = episodeBuffer
            episodeBuffer?.podcast = podcast
        default:
            break
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "description":
            episodeBuffer?.depiction = buffer.html2String
        case "pubdate":
            if buffer.contains("/") { //"3/27/21, 3:30 AM"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "M-d-yy, h:mm a"
                dateFormatter.timeZone = NSTimeZone(name: "UTC")! as TimeZone
                episodeBuffer?.publishDate = dateFormatter.date(from: buffer) ?? Date(timeIntervalSince1970: TimeInterval())
            } else if buffer.count >= 21 { //"2011-02-03T14:46:43"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                dateFormatter.timeZone = NSTimeZone(name: "UTC")! as TimeZone
                let dateWithoutTimeZoneString = String(buffer[..<buffer.index(buffer.startIndex, offsetBy: 19)])
                episodeBuffer?.publishDate = dateFormatter.date(from: dateWithoutTimeZoneString) ?? Date(timeIntervalSince1970: TimeInterval())
            } else {
                os_log("Pubdate <%s> could not be parsed of podcast episode", log: log, type: .error, buffer)
            }
        case "state":
            episodeBuffer?.remoteStatus = PodcastEpisodeRemoteStatus.create(from: buffer)
        case "filelength":
            episodeBuffer?.remoteDuration = buffer.asDurationInSeconds ?? 0
        case "filesize":
            episodeBuffer?.size = buffer.asByteCount ?? 0
        case "art":
            episodeBuffer?.artwork = parseArtwork(urlString: buffer)
        case "podcast_episode":
            parsedCount += 1
            playableBuffer = nil
            if let episode = episodeBuffer {
                episode.title = episode.title.html2String
                parsedEpisodes.append(episode)
            }
            episodeBuffer = nil
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
