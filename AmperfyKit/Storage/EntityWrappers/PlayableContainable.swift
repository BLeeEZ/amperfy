//
//  PlayableContainable.swift
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
import PromiseKit

public enum DetailType {
    case short
    case long
}

public struct DetailInfoType {
    public var type: DetailType
    public var isShowDetailedInfo: Bool
    public var isShowAlbumDuration: Bool
    public var isShowArtistDuration: Bool
    
    public init(type: DetailType, settings: PersistentStorage.Settings) {
        self.type = type
        self.isShowDetailedInfo = settings.isShowDetailedInfo
        self.isShowAlbumDuration = settings.isShowAlbumDuration
        self.isShowArtistDuration = settings.isShowArtistDuration
    }
}

public enum PlayableContainerBaseType: Int, Codable {
    case song = 0
    case podcastEpisode
    case album
    case artist
    case genre
    case playlist
    case podcast
}

public struct PlayableContainerIdentifier: Codable {
    public var type: PlayableContainerBaseType?
    public var objectID: String?
    
    public static func getContainer(library: LibraryStorage, containerIdentifierString: String) -> PlayableContainable? {
        guard let identifierData = containerIdentifierString.data(using: .utf8),
              let containerIdentifier = try? JSONDecoder().decode(PlayableContainerIdentifier.self, from: identifierData),
              let container = library.getContainer(identifier: containerIdentifier)
        else { return nil }
        return container
    }
}

public protocol PlayableContainable {
    var id: String { get }
    var name: String { get }
    var subtitle: String? { get }
    var subsubtitle: String? { get }
    func infoDetails(for api: BackenApiType, details: DetailInfoType) -> [String]
    func info(for api: BackenApiType, details: DetailInfoType) -> String
    var playables: [AbstractPlayable] { get }
    var playContextType: PlayerMode { get }
    var duration: Int { get }
    var isRateable: Bool { get }
    var isDownloadAvailable: Bool { get }
    var artworkCollection: ArtworkCollection { get }
    func cachePlayables(downloadManager: DownloadManageable)
    func fetchFromServer(storage: PersistentStorage, librarySyncer: LibrarySyncer, playableDownloadManager: DownloadManageable) -> Promise<Void>
    var isFavoritable: Bool { get }
    var isFavorite: Bool { get }
    func remoteToggleFavorite(syncer: LibrarySyncer) -> Promise<Void>
    func playedViaContext()
    var containerIdentifier: PlayableContainerIdentifier { get }
}

extension PlayableContainable {
    
    public func cachePlayables(downloadManager: DownloadManageable) {
        for playable in playables {
            if !playable.isCached {
                downloadManager.download(object: playable)
            }
        }
    }
    
    public func info(for api: BackenApiType, details: DetailInfoType) -> String {
        return infoDetails(for: api, details: details).joined(separator: " \(CommonString.oneMiddleDot) ")
    }
    
    public func fetch(storage: PersistentStorage, librarySyncer: LibrarySyncer, playableDownloadManager: DownloadManageable) -> Promise<Void> {
        guard storage.settings.isOnlineMode else { return Promise.value }
        return fetchFromServer(storage: storage, librarySyncer: librarySyncer, playableDownloadManager: playableDownloadManager)
    }
    public var isCompletelyCached: Bool { return !playables.isEmpty && playables.isCachedCompletely }
    public var isRateable: Bool { return false }
    public var isFavoritable: Bool { return false }
    public var isFavorite: Bool { return false }
    public var isDownloadAvailable: Bool { return true }
    public var containerIdentifierString: String {
        return self.containerIdentifier.asJSONString()
    }
}
