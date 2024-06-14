//
//  Podcast.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 25.06.21.
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
import PromiseKit

public class Podcast: AbstractLibraryEntity {
    
    public let managedObject: PodcastMO
    
    public init(managedObject: PodcastMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    public var identifier: String {
        return title
    }
    public var title: String {
        get { return managedObject.title ?? "Unknown Podcast" }
        set {
            if managedObject.title != newValue {
                managedObject.title = newValue
                updateAlphabeticSectionInitial(section: newValue)
            }
        }
    }
    public var depiction: String {
        get { return managedObject.depiction ?? "" }
        set { if managedObject.depiction != newValue { managedObject.depiction = newValue } }
    }
    public var duration: Int {
        return playables.reduce(0){ $0 + $1.duration }
    }
    public var episodes: [PodcastEpisode] {
        guard let episodesSet = managedObject.episodes, let episodesMO = episodesSet.array as? [PodcastEpisodeMO] else { return [PodcastEpisode]() }
        return episodesMO.compactMap{ PodcastEpisode(managedObject: $0) }.sortByPublishDate()
    }
    override public func getDefaultImage(themeColor: UIColor) -> UIImage  {
        return UIImage.getGeneratedArtwork(themeColor: themeColor, artworkType: .podcast)
    }

}

extension Podcast: PlayableContainable  {
    public var name: String { return title }
    public var subtitle: String? { return nil }
    public var subsubtitle: String? { return nil }
    public func infoDetails(for api: BackenApiType, details: DetailInfoType) -> [String] {
        var infoContent = [String]()
        if details.type != .noCountInfo {
            if episodes.count == 1 {
                infoContent.append("1 Episode")
            } else if episodes.count > 1 {
                infoContent.append("\(episodes.count) Episodes")
            }
        }
        if details.type == .long || details.type == .noCountInfo {
            if isCompletelyCached {
                infoContent.append("Cached")
            }
            let completeDuration = episodes.reduce(0, {$0 + $1.duration})
            if completeDuration > 0 {
                infoContent.append("\(completeDuration.asDurationString)")
            }
            if details.isShowDetailedInfo {
                infoContent.append("ID: \(!self.id.isEmpty ? self.id : "-")")
            }
        }
        return infoContent
    }
    public var playables: [AbstractPlayable] {
        return episodes.filter{ $0.isAvailableToUser }
    }
    public var playContextType: PlayerMode { return .podcast }
    public func fetchFromServer(storage: PersistentStorage, librarySyncer: LibrarySyncer, playableDownloadManager: DownloadManageable) -> Promise<Void> {
        return librarySyncer.sync(podcast: self)
    }
    public func remoteToggleFavorite(syncer: LibrarySyncer) -> Promise<Void> {
        return Promise<Void>(error: BackendError.notSupported)
    }
    public func getArtworkCollection(themeColor: UIColor) -> ArtworkCollection {
        return ArtworkCollection(defaultImage: getDefaultImage(themeColor: themeColor), singleImageEntity: self)
    }
    public var containerIdentifier: PlayableContainerIdentifier { return PlayableContainerIdentifier(type: .podcast, objectID: managedObject.objectID.uriRepresentation().absoluteString) }
}

extension Podcast: Hashable, Equatable {
    public static func == (lhs: Podcast, rhs: Podcast) -> Bool {
        return lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(managedObject)
    }
}
