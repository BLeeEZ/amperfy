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

import Foundation
import os.log

@MainActor
public class DuplicateEntitiesResolver {
  private let log = OSLog(subsystem: "Amperfy", category: "DuplicateEntitiesResolver")
  private let storage: PersistentStorage
  private var isRunning = false
  private var isActive = false

  init(storage: PersistentStorage) {
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
      if self.isRunning, self.storage.loginCredentials?.backendApi == .ampache {
        try? await self.storage.async.perform { asyncCompanion in
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Genre.typeName,
            keyPathString: #keyPath(GenreMO.id)
          )
          asyncCompanion.library.resolveGenresDuplicates(duplicates: duplicates, byName: false)
        }
      } else if self.isRunning, self.storage.loginCredentials?.backendApi != .ampache {
        try? await self.storage.async.perform { asyncCompanion in
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Genre.typeName,
            keyPathString: #keyPath(GenreMO.name)
          )
          asyncCompanion.library.resolveGenresDuplicates(duplicates: duplicates, byName: true)
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Artist.typeName,
            keyPathString: #keyPath(ArtistMO.id)
          )
          asyncCompanion.library.resolveArtistsDuplicates(duplicates: duplicates)
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Album.typeName,
            keyPathString: #keyPath(AlbumMO.id)
          )
          asyncCompanion.library.resolveAlbumsDuplicates(duplicates: duplicates)
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Song.typeName,
            keyPathString: #keyPath(SongMO.id)
          )
          asyncCompanion.library.resolveSongsDuplicates(duplicates: duplicates)
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let duplicates = asyncCompanion.library.findDuplicates(
            for: PodcastEpisode.typeName,
            keyPathString: #keyPath(PodcastEpisodeMO.id)
          )
          asyncCompanion.library.resolvePodcastEpisodesDuplicates(duplicates: duplicates)
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Radio.typeName,
            keyPathString: #keyPath(RadioMO.id)
          )
          asyncCompanion.library.resolveRadioDuplicates(duplicates: duplicates)
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Podcast.typeName,
            keyPathString: #keyPath(PodcastMO.id)
          )
          asyncCompanion.library.resolvePodcastsDuplicates(duplicates: duplicates)
        }
      }

      if self.isRunning {
        try? await self.storage.async.perform { asyncCompanion in
          let duplicates = asyncCompanion.library.findDuplicates(
            for: Playlist.typeName,
            keyPathString: #keyPath(PlaylistMO.id)
          )
          asyncCompanion.library.resolvePlaylistsDuplicates(duplicates: duplicates)
        }
      }

      os_log("stopped", log: self.log, type: .info)
      self.isActive = false
    }
  }
}
