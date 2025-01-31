//
//  Directory.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 27.05.21.
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
import UIKit
import PromiseKit

public class Directory: AbstractLibraryEntity {
    
    public let managedObject: DirectoryMO
    
    public init(managedObject: DirectoryMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    public var name: String {
        get { return managedObject.name ?? "" }
        set {
            if managedObject.name != newValue {
                managedObject.name = newValue
                updateAlphabeticSectionInitial(section: newValue)
            }
        }
    }
    public var isCached: Bool {
        get { return managedObject.isCached }
        set {
            if managedObject.isCached != newValue {
                managedObject.isCached = newValue
            }
        }
    }
    public var songCount: Int {
        get { return Int(managedObject.songCount) }
    }
    public var subdirectoryCount: Int {
        get { return Int(managedObject.subdirectoryCount) }
    }
    public var songs: [Song] {
        return managedObject.songs?.compactMap{ Song(managedObject: $0 as! SongMO) } ?? [Song]()
    }
    public var subdirectories: [Directory] {
        return managedObject.subdirectories?.compactMap{ Directory(managedObject: $0 as! DirectoryMO) } ?? [Directory]()
    }

}

extension Directory: PlayableContainable  {
    public var subtitle: String? { return nil }
    public var subsubtitle: String? { return nil }
    public func infoDetails(for api: BackenApiType, details: DetailInfoType) -> [String] {
        var infoContent = [String]()
        if subdirectories.count == 1 {
            infoContent.append("1 Subdirectory")
        } else if subdirectories.count > 1 {
            infoContent.append("\(subdirectories.count) Subdirectory")
        }
        
        if songCount == 1 {
            infoContent.append("1 Song")
        } else if songCount > 1 {
            infoContent.append("\(songCount) Songs")
        }
        
        if details.type == .long {
            if isCached {
                infoContent.append("Cached")
            }
            if duration > 0 {
                infoContent.append("\(duration.asDurationString)")
            }
            if details.isShowDetailedInfo {
                infoContent.append("ID: \(!self.id.isEmpty ? self.id : "-")")
            }
        }
        return infoContent
    }
    public var playables: [AbstractPlayable] {
        return songs
    }
    public var playContextType: PlayerMode { return .music }
    public var isRateable: Bool { return false }
    public var isFavoritable: Bool { return false }
    public func remoteToggleFavorite(syncer: LibrarySyncer) -> Promise<Void> {
        return Promise<Void>(error: BackendError.notSupported)
    }
    public func fetchFromServer(storage: PersistentStorage, librarySyncer: LibrarySyncer, playableDownloadManager: DownloadManageable) -> Promise<Void> {
        return librarySyncer.sync(directory: self)
    }
    public func getArtworkCollection(theme: ThemePreference) -> ArtworkCollection {
        return ArtworkCollection(defaultImage: .getGeneratedArtwork(theme: theme, artworkType: .folder), singleImageEntity: self)
    }
    public var containerIdentifier: PlayableContainerIdentifier { return PlayableContainerIdentifier(type: .directory, objectID: managedObject.objectID.uriRepresentation().absoluteString) }
    public var duration: Int {
        playables.reduce(0){ $0 + $1.duration }
    }
}
