import Foundation
import CoreData
import UIKit

enum PodcastEpisodeRemoteStatus: Int {
    /*
     Subsonic:
     <xs:simpleType name="PodcastStatus">
         <xs:restriction base="xs:string">
             <xs:enumeration value="new"/>
             <xs:enumeration value="downloading"/>
             <xs:enumeration value="completed"/>
             <xs:enumeration value="error"/>
             <xs:enumeration value="deleted"/>
             <xs:enumeration value="skipped"/>
         </xs:restriction>
     </xs:simpleType>

     Ampache:
     pending -> mapped to downloading
     completed
     */
    case undefined = 0
    case new = 1
    case downloading = 2
    case completed = 3
    case error = 4
    case deleted = 5
    case skipped = 6
    
    static func create(from text: String) -> PodcastEpisodeRemoteStatus {
        switch text {
        case "new": return .new
        case "downloading": return .downloading
        case "completed": return .completed
        case "error": return .error
        case "deleted": return .deleted
        case "skipped": return .skipped
            
        case "Pending": return .downloading
        case "Completed": return .completed
        default: return .undefined
        }
    }
}

enum PodcastEpisodeUserStatus {
    case syncingOnServer
    case availableOnServer
    case cached
    
    var description : String {
        switch self {
        case .syncingOnServer: return "Server syncing"
        case .availableOnServer: return "Available"
        case .cached: return "Cached"
        }
    }
}

public class PodcastEpisode: AbstractPlayable {

    let managedObject: PodcastEpisodeMO

    init(managedObject: PodcastEpisodeMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    override var creatorName: String {
        return podcast?.title ?? "Unknown Podcast"
    }

    var depiction: String? {
        get { return managedObject.depiction }
        set {
            if managedObject.depiction != newValue { managedObject.depiction = newValue }
        }
    }
    var publishDate: Date {
        get { return managedObject.publishDate ?? Date() }
        set { if managedObject.publishDate != newValue { managedObject.publishDate = newValue } }
    }
    var remoteStatus: PodcastEpisodeRemoteStatus {
        get { return PodcastEpisodeRemoteStatus(rawValue: Int(managedObject.status)) ?? .undefined }
        set { if managedObject.status != newValue.rawValue { managedObject.status = Int16(newValue.rawValue) } }
    }
    var userStatus: PodcastEpisodeUserStatus {
        if isCached {
            return .cached
        } else if remoteStatus == .completed {
            return .availableOnServer
        } else {
            return .syncingOnServer
        }
    }
    var streamId: String? {
        get { return managedObject.streamId }
        set { if managedObject.streamId != newValue { managedObject.streamId = newValue } }
    }
    var podcast: Podcast? {
        get {
            guard let podcastMO = managedObject.podcast else { return nil }
            return Podcast(managedObject: podcastMO)
        }
        set { if managedObject.podcast != newValue?.managedObject { managedObject.podcast = newValue?.managedObject } }
    }
    var detailInfo: String {
        var info = title
        info += " ("
        let podcastName = podcast?.title ?? "-"
        info += "album: \(podcastName),"
        
        info += " id: \(id),"
        info += " track: \(track),"
        info += " year: \(year),"
        info += " remote duration: \(remoteDuration),"
        let diskInfo =  disk ?? "-"
        info += " disk: \(diskInfo),"
        info += " size: \(size),"
        let contentTypeInfo = contentType ?? "-"
        info += " contentType: \(contentTypeInfo),"
        info += " bitrate: \(bitrate),"

        info += " description: \(depiction ?? "-")"
        info += " publishDate: \(publishDate.asIso8601String),"
        info += " remoteStatus: \(remoteStatus)"
        info += ")"
        return info
    }

}

extension Array where Element: PodcastEpisode {
    
    func sortByPublishDate() -> [Element] {
        return self.sorted{ $0.publishDate.compare($1.publishDate) == .orderedDescending }
    }

}
