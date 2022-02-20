import Foundation
import CoreData
import UIKit

public class Song: AbstractPlayable, Identifyable {

    let managedObject: SongMO

    init(managedObject: SongMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }

    var album: Album? {
        get {
            guard let albumMO = managedObject.album else { return nil }
            return Album(managedObject: albumMO)
        }
        set {
            if managedObject.album != newValue?.managedObject { managedObject.album = newValue?.managedObject }
        }
    }
    var artist: Artist? {
        get {
            guard let artistMO = managedObject.artist else { return nil }
            return Artist(managedObject: artistMO)
        }
        set {
            if managedObject.artist != newValue?.managedObject { managedObject.artist = newValue?.managedObject }
        }
    }
    var genre: Genre? {
        get {
            guard let genreMO = managedObject.genre else { return nil }
            return Genre(managedObject: genreMO) }
        set {
            if managedObject.genre != newValue?.managedObject { managedObject.genre = newValue?.managedObject }
        }
    }
    var syncInfo: SyncWave? {
        get {
            guard let syncInfoMO = managedObject.syncInfo else { return nil }
            return SyncWave(managedObject: syncInfoMO) }
        set {
            if managedObject.syncInfo != newValue?.managedObject { managedObject.syncInfo = newValue?.managedObject }
        }
    }
    var isOrphaned: Bool {
        guard let album = album else { return true }
        return album.isOrphaned
    }

    override var creatorName: String {
        return artist?.name ?? "Unknown Artist"
    }
    
    var detailInfo: String {
        var info = displayString
        info += " ("
        let albumName = album?.name ?? "-"
        info += "album: \(albumName),"
        let genreName = genre?.name ?? "-"
        info += " genre: \(genreName),"
        
        info += " id: \(id),"
        info += " track: \(track),"
        info += " year: \(year),"
        info += " remote duration: \(remoteDuration),"
        let diskInfo =  disk ?? "-"
        info += " disk: \(diskInfo),"
        info += " size: \(size),"
        let contentTypeInfo = contentType ?? "-"
        info += " contentType: \(contentTypeInfo),"
        info += " bitrate: \(bitrate)"
        info += ")"
        return info
    }
    
    override func infoDetails(for api: BackenApiType, type: DetailType) -> [String] {
        var infoContent = [String]()
        if type == .long {
            if track > 0 {
                infoContent.append("Track \(track)")
            }
            infoContent.append("\(duration.asDurationString)")
            if year > 0 {
                infoContent.append("Year \(year)")
            } else if let albumYear = album?.year, albumYear > 0 {
                infoContent.append("Year \(albumYear)")
            }
            if let genre = genre {
                infoContent.append("Genre: \(genre.name)")
            }
        }
        return infoContent
    }
    
    var identifier: String {
        return title
    }

}

extension Array where Element: Song {
    
    func filterCached() -> [Element] {
        return self.filter{ $0.isCached }
    }
    
    func filterCustomArt() -> [Element] {
        return self.filter{ $0.artwork != nil }
    }
    
    var hasCachedSongs: Bool {
        return self.lazy.filter{ $0.isCached }.first != nil
    }
    
    func sortByTrackNumber() -> [Element] {
        return self.sorted{ $0.track < $1.track }
    }

}
