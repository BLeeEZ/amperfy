//
//  AccountMO+CoreDataProperties.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 28.11.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

public import Foundation
public import CoreData

public typealias AccountMOCoreDataPropertiesSet = NSSet

extension AccountMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<AccountMO> {
    NSFetchRequest<AccountMO>(entityName: "Account")
  }

  @NSManaged
  public var id: String?
  @NSManaged
  public var apiType: Int16
  @NSManaged
  public var serverHash: String?
  @NSManaged
  public var serverUrl: String?
  @NSManaged
  public var userHash: String?
  @NSManaged
  public var userName: String?
  @NSManaged
  public var artworks: NSSet?
  @NSManaged
  public var downloads: NSSet?
  @NSManaged
  public var embeddedArtworks: NSSet?
  @NSManaged
  public var entities: NSSet?
  @NSManaged
  public var musicFolders: NSSet?
  @NSManaged
  public var player: NSSet?
  @NSManaged
  public var playlistItems: NSSet?
  @NSManaged
  public var playlists: NSSet?
  @NSManaged
  public var scrobbleEntries: NSSet?
  @NSManaged
  public var searchHistories: NSSet?
}

// MARK: Generated accessors for artworks

extension AccountMO {
  @objc(addArtworksObject:)
  @NSManaged
  public func addToArtworks(_ value: ArtworkMO)

  @objc(removeArtworksObject:)
  @NSManaged
  public func removeFromArtworks(_ value: ArtworkMO)

  @objc(addArtworks:)
  @NSManaged
  public func addToArtworks(_ values: NSSet)

  @objc(removeArtworks:)
  @NSManaged
  public func removeFromArtworks(_ values: NSSet)
}

// MARK: Generated accessors for downloads

extension AccountMO {
  @objc(addDownloadsObject:)
  @NSManaged
  public func addToDownloads(_ value: DownloadMO)

  @objc(removeDownloadsObject:)
  @NSManaged
  public func removeFromDownloads(_ value: DownloadMO)

  @objc(addDownloads:)
  @NSManaged
  public func addToDownloads(_ values: NSSet)

  @objc(removeDownloads:)
  @NSManaged
  public func removeFromDownloads(_ values: NSSet)
}

// MARK: Generated accessors for embeddedArtworks

extension AccountMO {
  @objc(addEmbeddedArtworksObject:)
  @NSManaged
  public func addToEmbeddedArtworks(_ value: EmbeddedArtworkMO)

  @objc(removeEmbeddedArtworksObject:)
  @NSManaged
  public func removeFromEmbeddedArtworks(_ value: EmbeddedArtworkMO)

  @objc(addEmbeddedArtworks:)
  @NSManaged
  public func addToEmbeddedArtworks(_ values: NSSet)

  @objc(removeEmbeddedArtworks:)
  @NSManaged
  public func removeFromEmbeddedArtworks(_ values: NSSet)
}

// MARK: Generated accessors for entities

extension AccountMO {
  @objc(addEntitiesObject:)
  @NSManaged
  public func addToEntities(_ value: AbstractLibraryEntityMO)

  @objc(removeEntitiesObject:)
  @NSManaged
  public func removeFromEntities(_ value: AbstractLibraryEntityMO)

  @objc(addEntities:)
  @NSManaged
  public func addToEntities(_ values: NSSet)

  @objc(removeEntities:)
  @NSManaged
  public func removeFromEntities(_ values: NSSet)
}

// MARK: Generated accessors for musicFolders

extension AccountMO {
  @objc(addMusicFoldersObject:)
  @NSManaged
  public func addToMusicFolders(_ value: MusicFolderMO)

  @objc(removeMusicFoldersObject:)
  @NSManaged
  public func removeFromMusicFolders(_ value: MusicFolderMO)

  @objc(addMusicFolders:)
  @NSManaged
  public func addToMusicFolders(_ values: NSSet)

  @objc(removeMusicFolders:)
  @NSManaged
  public func removeFromMusicFolders(_ values: NSSet)
}

// MARK: Generated accessors for player

extension AccountMO {
  @objc(addPlayerObject:)
  @NSManaged
  public func addToPlayer(_ value: PlayerMO)

  @objc(removePlayerObject:)
  @NSManaged
  public func removeFromPlayer(_ value: PlayerMO)

  @objc(addPlayer:)
  @NSManaged
  public func addToPlayer(_ values: NSSet)

  @objc(removePlayer:)
  @NSManaged
  public func removeFromPlayer(_ values: NSSet)
}

// MARK: Generated accessors for playlistItems

extension AccountMO {
  @objc(addPlaylistItemsObject:)
  @NSManaged
  public func addToPlaylistItems(_ value: PlaylistItemMO)

  @objc(removePlaylistItemsObject:)
  @NSManaged
  public func removeFromPlaylistItems(_ value: PlaylistItemMO)

  @objc(addPlaylistItems:)
  @NSManaged
  public func addToPlaylistItems(_ values: NSSet)

  @objc(removePlaylistItems:)
  @NSManaged
  public func removeFromPlaylistItems(_ values: NSSet)
}

// MARK: Generated accessors for playlists

extension AccountMO {
  @objc(addPlaylistsObject:)
  @NSManaged
  public func addToPlaylists(_ value: PlaylistMO)

  @objc(removePlaylistsObject:)
  @NSManaged
  public func removeFromPlaylists(_ value: PlaylistMO)

  @objc(addPlaylists:)
  @NSManaged
  public func addToPlaylists(_ values: NSSet)

  @objc(removePlaylists:)
  @NSManaged
  public func removeFromPlaylists(_ values: NSSet)
}

// MARK: Generated accessors for scrobbleEntries

extension AccountMO {
  @objc(addScrobbleEntriesObject:)
  @NSManaged
  public func addToScrobbleEntries(_ value: ScrobbleEntryMO)

  @objc(removeScrobbleEntriesObject:)
  @NSManaged
  public func removeFromScrobbleEntries(_ value: ScrobbleEntryMO)

  @objc(addScrobbleEntries:)
  @NSManaged
  public func addToScrobbleEntries(_ values: NSSet)

  @objc(removeScrobbleEntries:)
  @NSManaged
  public func removeFromScrobbleEntries(_ values: NSSet)
}

// MARK: Generated accessors for searchHistories

extension AccountMO {
  @objc(addSearchHistoriesObject:)
  @NSManaged
  public func addToSearchHistories(_ value: SearchHistoryItemMO)

  @objc(removeSearchHistoriesObject:)
  @NSManaged
  public func removeFromSearchHistories(_ value: SearchHistoryItemMO)

  @objc(addSearchHistories:)
  @NSManaged
  public func addToSearchHistories(_ values: NSSet)

  @objc(removeSearchHistories:)
  @NSManaged
  public func removeFromSearchHistories(_ values: NSSet)
}

// MARK: - AccountMO + Identifiable

extension AccountMO: Identifiable {}
