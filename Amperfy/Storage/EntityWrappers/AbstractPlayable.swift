import Foundation
import CoreData
import UIKit

public class AbstractPlayable: AbstractLibraryEntity, Downloadable {
    /*
    Avoid direct access to the PlayableFile.
    Direct access will result in loading the file into memory and
    it sticks there till the song is removed from memory.
    This will result in memory overflow for an array of songs.
    */
    let playableManagedObject: AbstractPlayableMO

    init(managedObject: AbstractPlayableMO) {
        self.playableManagedObject = managedObject
        super.init(managedObject: managedObject)
    }

    var objectID: NSManagedObjectID {
        return playableManagedObject.objectID
    }
    var displayString: String {
        return "\(creatorName) - \(title)"
    }
    var creatorName: String {
        return asSong?.creatorName ?? asPodcastEpisode?.creatorName ?? "Unknown"
    }
    var title: String {
        get { return playableManagedObject.title ?? "Unknown Title" }
        set {
            if playableManagedObject.title != newValue { playableManagedObject.title = newValue }
        }
    }
    var track: Int {
        get { return Int(playableManagedObject.track) }
        set {
            guard Int16.isValid(value: newValue), playableManagedObject.track != Int16(newValue) else { return }
            playableManagedObject.track = Int16(newValue)
        }
    }
    var year: Int {
        get { return Int(playableManagedObject.year) }
        set {
            guard Int16.isValid(value: newValue), playableManagedObject.year != Int16(newValue) else { return }
            playableManagedObject.year = Int16(newValue)
        }
    }
    var duration: Int {
        get { return Int(playableManagedObject.duration) }
        set {
            guard Int16.isValid(value: newValue), playableManagedObject.duration != Int16(newValue) else { return }
            playableManagedObject.duration = Int16(newValue)
        }
    }
    var size: Int {
        get { return Int(playableManagedObject.size) }
        set {
            guard Int32.isValid(value: newValue), playableManagedObject.size != Int32(newValue) else { return }
            playableManagedObject.size = Int32(newValue)
        }
    }
    var bitrate: Int { // byte per second
        get { return Int(playableManagedObject.bitrate) }
        set {
            guard Int32.isValid(value: newValue), playableManagedObject.bitrate != Int32(newValue) else { return }
            playableManagedObject.bitrate = Int32(newValue)
        }
    }
    var contentType: String? {
        get { return playableManagedObject.contentType }
        set {
            if playableManagedObject.contentType != newValue { playableManagedObject.contentType = newValue }
        }
    }
    var iOsCompatibleContentType: String? {
        guard isPlayableOniOS, let originalContenType = contentType else { return nil }
        if originalContenType == "audio/x-flac" {
            return "audio/flac"
        }
        return originalContenType
    }
    var isPlayableOniOS: Bool {
        guard let originalContenType = contentType else { return true }
        if originalContenType == "audio/x-ms-wma" {
            return false
        }
        return true
    }
    var disk: String? {
        get { return playableManagedObject.disk }
        set {
            if playableManagedObject.disk != newValue { playableManagedObject.disk = newValue }
        }
    }
    var url: String? {
        get { return playableManagedObject.url }
        set {
            if playableManagedObject.url != newValue { playableManagedObject.url = newValue }
        }
    }

    var isCached: Bool {
        if playableManagedObject.file != nil {
            return true
        }
        return false
    }
    
    var isSong: Bool {
        return playableManagedObject is SongMO
    }
    var asSong: Song? {
        guard self.isSong, let playableSong = playableManagedObject as? SongMO else { return nil }
        return Song(managedObject: playableSong)
    }
    var isPodcastEpisode: Bool {
        return playableManagedObject is PodcastEpisodeMO
    }
    var asPodcastEpisode: PodcastEpisode? {
        guard self.isPodcastEpisode, let playablePodcastEpisode = playableManagedObject as? PodcastEpisodeMO else { return nil }
        return PodcastEpisode(managedObject: playablePodcastEpisode)
    }

}

extension AbstractPlayable: Hashable, Equatable {
    public static func == (lhs: AbstractPlayable, rhs: AbstractPlayable) -> Bool {
        return lhs.playableManagedObject == rhs.playableManagedObject && lhs.playableManagedObject == rhs.playableManagedObject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(playableManagedObject)
    }
}

extension Array where Element: AbstractPlayable {
    
    func filterCached() -> [Element] {
        return self.filter{ $0.isCached }
    }
    
    func filterCustomArt() -> [Element] {
        return self.filter{ $0.artwork != nil }
    }
    
    var hasCachedItems: Bool {
        return self.lazy.filter{ $0.isCached }.first != nil
    }
    
    func sortByTrackNumber() -> [Element] {
        return self.sorted{ $0.track < $1.track }
    }
    
    func filterSongs() -> [Element] {
        return self.filter{ $0.isSong }
    }

}
