//
//  DuplicateEntitiesResolver.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 30.05.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

import CoreData
import Foundation
import os.log

@MainActor
public class DuplicateEntitiesResolver {
  private let log = OSLog(subsystem: "Amperfy", category: "DuplicateEntitiesResolver")
  private let account: Account
  private let accountObjectId: NSManagedObjectID
  private let storage: PersistentStorage
  private var isRunning = false
  private var isActive = false

  init(account: Account, storage: PersistentStorage) {
    self.account = account
    self.accountObjectId = account.managedObject.objectID
    self.storage = storage
  }

  public func start() {
    isRunning = true
    if !isActive {
      isActive = true
      resolveDuplicatesInBackground()
    }
  }

  private func resolveDuplicatesInBackground() {
    Task { @MainActor in
      os_log("start", log: self.log, type: .info)

      // only check for duplicates on Ampache API, Subsonic does not have genre ids
      if self.isRunning, account.apiType.asServerApiType == .ampache {
        try? await self.storage.async.perform { asyncCompanion in
          let accountAsync = Account(
            managedObject: asyncCompanion.context
              .object(with: self.accountObjectId) as! AccountMO
          )
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Genre.typeName,
            keyPathString: #keyPath(GenreMO.id),
            account: accountAsync
          )
          asyncCompanion.library.resolveGenresDuplicates(
            account: accountAsync,
            duplicates: duplicates,
            byName: false
          )
        }
      } else if self.isRunning, account.apiType.asServerApiType == .subsonic {
        try? await self.storage.async.perform { asyncCompanion in
          let accountAsync = Account(
            managedObject: asyncCompanion.context
              .object(with: self.accountObjectId) as! AccountMO
          )
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Genre.typeName,
            keyPathString: #keyPath(GenreMO.name),
            account: accountAsync
          )
          asyncCompanion.library.resolveGenresDuplicates(
            account: accountAsync,
            duplicates: duplicates,
            byName: true
          )
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let accountAsync = Account(
            managedObject: asyncCompanion.context
              .object(with: self.accountObjectId) as! AccountMO
          )
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Artist.typeName,
            keyPathString: #keyPath(ArtistMO.id),
            account: accountAsync
          )
          asyncCompanion.library.resolveArtistsDuplicates(
            account: accountAsync,
            duplicates: duplicates
          )
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let accountAsync = Account(
            managedObject: asyncCompanion.context
              .object(with: self.accountObjectId) as! AccountMO
          )
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Album.typeName,
            keyPathString: #keyPath(AlbumMO.id),
            account: accountAsync
          )
          asyncCompanion.library.resolveAlbumsDuplicates(
            account: accountAsync,
            duplicates: duplicates
          )
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let accountAsync = Account(
            managedObject: asyncCompanion.context
              .object(with: self.accountObjectId) as! AccountMO
          )
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Song.typeName,
            keyPathString: #keyPath(SongMO.id),
            account: accountAsync
          )
          asyncCompanion.library.resolveSongsDuplicates(
            account: accountAsync,
            duplicates: duplicates
          )
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let accountAsync = Account(
            managedObject: asyncCompanion.context
              .object(with: self.accountObjectId) as! AccountMO
          )
          let duplicates = asyncCompanion.library.findDuplicates(
            for: PodcastEpisode.typeName,
            keyPathString: #keyPath(PodcastEpisodeMO.id),
            account: accountAsync
          )
          asyncCompanion.library.resolvePodcastEpisodesDuplicates(
            account: accountAsync,
            duplicates: duplicates
          )
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let accountAsync = Account(
            managedObject: asyncCompanion.context
              .object(with: self.accountObjectId) as! AccountMO
          )
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Radio.typeName,
            keyPathString: #keyPath(RadioMO.id),
            account: accountAsync
          )
          asyncCompanion.library.resolveRadioDuplicates(
            account: accountAsync,
            duplicates: duplicates
          )
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let accountAsync = Account(
            managedObject: asyncCompanion.context
              .object(with: self.accountObjectId) as! AccountMO
          )
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Podcast.typeName,
            keyPathString: #keyPath(PodcastMO.id),
            account: accountAsync
          )
          asyncCompanion.library.resolvePodcastsDuplicates(
            account: accountAsync,
            duplicates: duplicates
          )
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let accountAsync = Account(
            managedObject: asyncCompanion.context
              .object(with: self.accountObjectId) as! AccountMO
          )
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Playlist.typeName,
            keyPathString: #keyPath(PlaylistMO.id),
            account: accountAsync
          )
          asyncCompanion.library.resolvePlaylistsDuplicates(
            account: accountAsync,
            duplicates: duplicates
          )
        }
      }

      os_log("stopped", log: self.log, type: .info)
      self.isActive = false
    }
  }
}
