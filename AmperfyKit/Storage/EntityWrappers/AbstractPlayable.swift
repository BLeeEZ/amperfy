//
//  AbstractPlayable.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 29.06.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import CoreData
import UIKit
import AVFoundation
import PromiseKit

public class AbstractPlayable: AbstractLibraryEntity, Downloadable {
    /*
    Avoid direct access to the PlayableFile.
    Direct access will result in loading the file into memory and
    it sticks there till the song is removed from memory.
    This will result in memory overflow for an array of songs.
    */
    public let playableManagedObject: AbstractPlayableMO

    public init(managedObject: AbstractPlayableMO) {
        self.playableManagedObject = managedObject
        super.init(managedObject: managedObject)
    }

    override public func image(setting: ArtworkDisplayPreference) -> UIImage {
        switch setting {
        case .id3TagOnly:
            return embeddedArtwork?.image ?? defaultImage
        case .serverArtworkOnly:
            return super.image(setting: setting)
        case .preferServerArtwork:
            return artwork?.image ?? embeddedArtwork?.image ?? defaultImage
        case .preferId3Tag:
            return embeddedArtwork?.image ?? artwork?.image ?? defaultImage
        }
    }
    public var embeddedArtwork: EmbeddedArtwork? {
        get {
            guard let embeddedArtworkMO = playableManagedObject.embeddedArtwork else { return nil }
            return EmbeddedArtwork(managedObject: embeddedArtworkMO)
        }
        set {
            if playableManagedObject.embeddedArtwork != newValue?.managedObject { playableManagedObject.embeddedArtwork = newValue?.managedObject }
        }
    }
    public var objectID: NSManagedObjectID {
        return playableManagedObject.objectID
    }
    public var displayString: String {
        return "\(creatorName) - \(title)"
    }
    public var creatorName: String {
        return asSong?.creatorName ?? asPodcastEpisode?.creatorName ?? "Unknown"
    }
    public var title: String {
        get { return playableManagedObject.title ?? "Unknown Title" }
        set {
            if playableManagedObject.title != newValue {
                playableManagedObject.title = newValue
                updateAlphabeticSectionInitial(section: newValue)
            }
        }
    }
    public var track: Int {
        get { return Int(playableManagedObject.track) }
        set {
            guard Int16.isValid(value: newValue), playableManagedObject.track != Int16(newValue) else { return }
            playableManagedObject.track = Int16(newValue)
        }
    }
    public var year: Int {
        get { return Int(playableManagedObject.year) }
        set {
            guard Int16.isValid(value: newValue), playableManagedObject.year != Int16(newValue) else { return }
            playableManagedObject.year = Int16(newValue)
        }
    }
    public var duration: Int {
        get { return Int(playableManagedObject.combinedDuration) }
    }
    public func updateDuration() -> Bool {
        var isUpdated = false
        let combinedDuration = playableManagedObject.playDuration > 0 ? playableManagedObject.playDuration : playableManagedObject.remoteDuration
        if playableManagedObject.combinedDuration != combinedDuration {
            playableManagedObject.combinedDuration = combinedDuration
            isUpdated = true
        }
        return isUpdated
    }
    
    /// duration based on the data from the xml parser
    public var remoteDuration: Int {
        get { return Int(playableManagedObject.remoteDuration) }
        set {
            guard Int16.isValid(value: newValue), playableManagedObject.remoteDuration != Int16(newValue) else { return }
            playableManagedObject.remoteDuration = Int16(newValue)
            if playableManagedObject.playDuration == 0 {
                playableManagedObject.combinedDuration = Int16(newValue)
            }
        }
    }
    /// duration based on the downloaded/streamed file reported by the player
    public var playDuration: Int {
        get { return Int(playableManagedObject.playDuration) }
        set {
            guard Int16.isValid(value: newValue), playableManagedObject.playDuration != Int16(newValue) else { return }
            playableManagedObject.playDuration = Int16(newValue)
            playableManagedObject.combinedDuration = Int16(newValue)
            _ = updateDuration()
            // songs need to update more members
            if let song = asSong {
                _ = song.updateDuration()
            }
        }
    }
    public var playProgress: Int {
        get { return Int(playableManagedObject.playProgress) }
        set {
            guard Int16.isValid(value: newValue), playableManagedObject.playProgress != Int16(newValue) else { return }
            playableManagedObject.playProgress = Int16(newValue)
        }
    }
    public var size: Int {
        get { return Int(playableManagedObject.size) }
        set {
            guard Int32.isValid(value: newValue), playableManagedObject.size != Int32(newValue) else { return }
            playableManagedObject.size = Int32(newValue)
        }
    }
    public var bitrate: Int { // byte per second
        get { return Int(playableManagedObject.bitrate) }
        set {
            guard Int32.isValid(value: newValue), playableManagedObject.bitrate != Int32(newValue) else { return }
            playableManagedObject.bitrate = Int32(newValue)
        }
    }
    public var contentType: String? {
        get { return playableManagedObject.contentType }
        set {
            if playableManagedObject.contentType != newValue { playableManagedObject.contentType = newValue }
        }
    }
    public var iOsCompatibleContentType: String? {
        guard isPlayableOniOS, let originalContenType = contentType else { return nil }
        if originalContenType == "audio/x-flac" {
            return "audio/flac"
        }
        if originalContenType == "audio/m4a" {
            return "audio/mp4"
        }
        return originalContenType
    }
    public var isPlayableOniOS: Bool {
        guard let originalContenType = contentType else { return true }
        if originalContenType == "audio/x-ms-wma" {
            return false
        }
        return true
    }
    public var disk: String? {
        get { return playableManagedObject.disk }
        set {
            if playableManagedObject.disk != newValue { playableManagedObject.disk = newValue }
        }
    }
    public var url: String? {
        get { return playableManagedObject.url }
        set {
            if playableManagedObject.url != newValue { playableManagedObject.url = newValue }
        }
    }

    public var isCached: Bool {
        if playableManagedObject.file != nil {
            return true
        }
        return false
    }

    public var recentlyAddedIndex: Int {
        get { return Int(playableManagedObject.recentlyAddedIndex) }
        set {
            guard Int16.isValid(value: newValue), playableManagedObject.recentlyAddedIndex != Int16(newValue) else { return }
            playableManagedObject.recentlyAddedIndex = Int16(newValue)
        }
    }
    
    public func markAsNotRecentAnymore() {
        playableManagedObject.recentlyAddedIndex = 0
    }
    
    public var isSong: Bool {
        return playableManagedObject is SongMO
    }
    public var asSong: Song? {
        guard self.isSong, let playableSong = playableManagedObject as? SongMO else { return nil }
        return Song(managedObject: playableSong)
    }
    public var isPodcastEpisode: Bool {
        return playableManagedObject is PodcastEpisodeMO
    }
    public var asPodcastEpisode: PodcastEpisode? {
        guard self.isPodcastEpisode, let playablePodcastEpisode = playableManagedObject as? PodcastEpisodeMO else { return nil }
        return PodcastEpisode(managedObject: playablePodcastEpisode)
    }
    public func infoDetails(for api: BackenApiType, details: DetailInfoType) -> [String] {
        var infoContent = [String]()
        if details.type == .long {
            if year > 0 {
                infoContent.append("Year \(year)")
            }
            if duration > 0 {
                infoContent.append("\(duration.asDurationString)")
            }
            if bitrate > 0 {
                infoContent.append("Bitrate \(bitrate)")
            }
        }
        return infoContent
    }
    override public var defaultImage: UIImage {
        return isPodcastEpisode ? UIImage.podcastEpisodeArtwork : UIImage.songArtwork
    }
    
    override public func playedViaContext() {
        // keep empty to ignore context based play
    }
    
    public func countPlayed() {
        lastTimePlayed = Date()
        playCount += 1
    }

}

extension AbstractPlayable: PlayableContainable  {
    public var name: String { return title }
    public var subtitle: String? { return creatorName }
    public var subsubtitle: String? { return asSong?.album?.name }
    public var playables: [AbstractPlayable] {
        return [self]
    }
    public var playContextType: PlayerMode { return isSong ? .music : .podcast }
    public func fetchFromServer(storage: PersistentStorage, librarySyncer: LibrarySyncer, playableDownloadManager: DownloadManageable) -> Promise<Void> {
        guard let song = asSong else { return Promise.value }
        return librarySyncer.sync(song: song)
    }
    public var isRateable: Bool { return isSong }
    public var isFavoritable: Bool { return isSong }
    public func remoteToggleFavorite(syncer: LibrarySyncer) -> Promise<Void> {
        guard let song = asSong else { return Promise.value}
        guard let context = song.managedObject.managedObjectContext else { return Promise<Void>(error: BackendError.persistentSaveFailed) }
        isFavorite.toggle()
        let library = LibraryStorage(context: context)
        library.saveContext()
        return syncer.setFavorite(song: song, isFavorite: isFavorite)
    }
    public var isDownloadAvailable: Bool { return asPodcastEpisode?.isAvailableToUser ?? true }
    public var artworkCollection: ArtworkCollection {
        return ArtworkCollection(defaultImage: defaultImage, singleImageEntity: self)
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
    
    public func filterCached() -> [Element] {
        return self.filter{ $0.isCached }
    }
    
    public func filterCached(dependigOn isFilterActive: Bool) -> [Element] {
        return isFilterActive ? self.filter{ $0.isCached } : self
    }
    
    public func filterCustomArt() -> [Element] {
        return self.filter{ $0.artwork != nil }
    }
    
    public var hasCachedItems: Bool {
        return self.lazy.filter{ $0.isCached }.first != nil
    }
    
    public var isCachedCompletely: Bool {
        return filterCached().count == count
    }
    
    public func sortById() -> [Element] {
        return self.sorted{ $0.id < $1.id }
    }
    
    public func sortByTitle() -> [Element] {
        return self.sortById().sorted{ $0.title < $1.title }
    }
    
    public func sortByTrackNumber() -> [Element] {
        return self.sortById().sorted{ $0.track < $1.track }
    }
    
    public func filterSongs() -> [Element] {
        return self.filter{ $0.isSong }
    }

}
