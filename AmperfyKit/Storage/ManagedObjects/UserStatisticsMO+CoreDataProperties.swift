//
//  UserStatisticsMO+CoreDataProperties.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 24.05.21.
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

import CoreData
import Foundation

extension UserStatisticsMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<UserStatisticsMO> {
    NSFetchRequest<UserStatisticsMO>(entityName: "UserStatistics")
  }

  @NSManaged
  public var activeRepeatAllSongsCount: Int32
  @NSManaged
  public var activeRepeatOffSongsCount: Int32
  @NSManaged
  public var activeRepeatSingleSongsCount: Int32
  @NSManaged
  public var activeShuffleOffSongsCount: Int32
  @NSManaged
  public var activeShuffleOnSongsCount: Int32
  @NSManaged
  public var appSessionsStartedCount: Int32
  @NSManaged
  public var appStartedViaNotificationCount: Int32
  @NSManaged
  public var appVersion: String
  @NSManaged
  public var backgroundFetchFailedCount: Int32
  @NSManaged
  public var backgroundFetchNewDataCount: Int32
  @NSManaged
  public var backgroundFetchNoDataCount: Int32
  @NSManaged
  public var creationDate: Date
  @NSManaged
  public var localNotificationCreationCount: Int32
  @NSManaged
  public var playedSongFromCacheCount: Int32
  @NSManaged
  public var playedSongsCount: Int32
  @NSManaged
  public var playedSongViaStreamCount: Int32
  @NSManaged
  public var usedAirplayCount: Int32
  @NSManaged
  public var usedAlertGoToAlbumCount: Int32
  @NSManaged
  public var usedAlertGoToArtistCount: Int32
  @NSManaged
  public var usedAlertGoToPodcastCount: Int32
  @NSManaged
  public var usedChangePlayerDisplayStyleCount: Int32
  @NSManaged
  public var usedPlayerOptionsCount: Int32
  @NSManaged
  public var usedPlayerSeekCount: Int32
  @NSManaged
  public var visitedAlbumDetailCount: Int32
  @NSManaged
  public var visitedAlbumsCount: Int32
  @NSManaged
  public var visitedArtistDetailCount: Int32
  @NSManaged
  public var visitedArtistsCount: Int32
  @NSManaged
  public var visitedDownloadsCount: Int32
  @NSManaged
  public var visitedEventLogCount: Int32
  @NSManaged
  public var visitedGenreDetailCount: Int32
  @NSManaged
  public var visitedGenresCount: Int32
  @NSManaged
  public var visitedLibraryCount: Int32
  @NSManaged
  public var visitedLicenseCount: Int32
  @NSManaged
  public var visitedPlaylistDetailCount: Int32
  @NSManaged
  public var visitedPlaylistsCount: Int32
  @NSManaged
  public var visitedPlaylistSelectorCount: Int32
  @NSManaged
  public var visitedPodcastDetailCount: Int32
  @NSManaged
  public var visitedPodcastsCount: Int32
  @NSManaged
  public var visitedPopupPlayerCount: Int32
  @NSManaged
  public var visitedSearchCount: Int32
  @NSManaged
  public var visitedSettingsCount: Int32
  @NSManaged
  public var visitedSettingsLibraryCount: Int32
  @NSManaged
  public var visitedSettingsPlayerCount: Int32
  @NSManaged
  public var visitedSettingsPlayerSongTabCount: Int32
  @NSManaged
  public var visitedSettingsServerCount: Int32
  @NSManaged
  public var visitedSettingsSupportCount: Int32
  @NSManaged
  public var visitedSongsCount: Int32
  @NSManaged
  public var visitedRadiosCount: Int32
  @NSManaged
  public var visitedMusicFoldersCount: Int32
  @NSManaged
  public var visitedIndexesCount: Int32
  @NSManaged
  public var visitedDirectoriesCount: Int32
}
