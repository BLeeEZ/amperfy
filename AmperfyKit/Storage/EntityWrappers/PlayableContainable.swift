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

public protocol PlayableContainable {
    var name: String { get }
    var subtitle: String? { get }
    var subsubtitle: String? { get }
    func infoDetails(for api: BackenApiType, type: DetailType) -> [String]
    func info(for api: BackenApiType, type: DetailType) -> String
    var playables: [AbstractPlayable] { get }
    var playContextType: PlayerMode { get }
    var duration: Int { get }
    var isRateable: Bool { get }
    var isDownloadAvailable: Bool { get }
    var artworkCollection: ArtworkCollection { get }
    func cachePlayables(downloadManager: DownloadManageable)
    func fetchFromServer(storage: PersistentStorage, backendApi: BackendApi, playableDownloadManager: DownloadManageable) -> Promise<Void>
    var isFavoritable: Bool { get }
    var isFavorite: Bool { get }
    func remoteToggleFavorite(syncer: LibrarySyncer) -> Promise<Void>
    func playedViaContext()
}

extension PlayableContainable {
    public var duration: Int {
        return playables.reduce(0){ $0 + $1.duration }
    }
    
    public func cachePlayables(downloadManager: DownloadManageable) {
        for playable in playables {
            if !playable.isCached {
                downloadManager.download(object: playable)
            }
        }
    }
    
    public func info(for api: BackenApiType, type: DetailType) -> String {
        return infoDetails(for: api, type: type).joined(separator: " \(CommonString.oneMiddleDot) ")
    }
    
    public func fetch(storage: PersistentStorage, backendApi: BackendApi, playableDownloadManager: DownloadManageable) -> Promise<Void> {
        guard storage.settings.isOnlineMode else { return Promise.value }
        return fetchFromServer(storage: storage, backendApi: backendApi, playableDownloadManager: playableDownloadManager)
    }
    public var isRateable: Bool { return false }
    public var isFavoritable: Bool { return false }
    public var isFavorite: Bool { return false }
    public var isDownloadAvailable: Bool { return true }
}
