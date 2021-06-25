import Foundation
import UIKit
import CoreData
import os.log

class PodcastEpisodeParserDelegate: SongParserDelegate {

    var podcast: Podcast
    var episodeBuffer: PodcastEpisode?

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
                songBuffer = library.createSong()
                songBuffer?.syncInfo = syncWave
                episodeBuffer?.playInfo = songBuffer
            }
            episodeBuffer?.podcast = podcast
        default:
            break
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "description":
            episodeBuffer?.depiction = buffer
        case "pubdate":
            //"3/27/21, 3:30 AM"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M-d-yy, h:mm a"
            dateFormatter.timeZone = NSTimeZone(name: "UTC")! as TimeZone
            episodeBuffer?.publishDate = dateFormatter.date(from: buffer) ?? Date(timeIntervalSince1970: TimeInterval())
        case "state":
            episodeBuffer?.remoteStatus = PodcastEpisodeRemoteStatus.create(from: buffer)
        case "filelength":
            songBuffer?.duration = buffer.asDurationInSeconds ?? 0
        case "filesize":
            songBuffer?.size = buffer.asByteCount ?? 0
        case "art":
            episodeBuffer?.artwork = parseArtwork(urlString: buffer)
        case "podcast_episode":
            parsedCount += 1
            songBuffer = nil
            episodeBuffer = nil
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
