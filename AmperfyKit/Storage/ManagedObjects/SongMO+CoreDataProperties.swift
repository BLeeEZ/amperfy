//
//  SongMO+CoreDataProperties.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

extension SongMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<SongMO> {
    NSFetchRequest<SongMO>(entityName: "Song")
  }

  @NSManaged
  public var lyricsRelFilePath: String?
  @NSManaged
  public var addedDate: Date?
  @NSManaged
  public var album: AlbumMO?
  @NSManaged
  public var artist: ArtistMO?
  @NSManaged
  public var directory: DirectoryMO?
  @NSManaged
  public var genre: GenreMO?
  @NSManaged
  public var musicFolder: MusicFolderMO?

  static let relationshipKeyPathsForPrefetching = [
    #keyPath(SongMO.addedDate),
    #keyPath(SongMO.album),
    #keyPath(SongMO.artist),
    #keyPath(SongMO.artwork),
    #keyPath(SongMO.embeddedArtwork),
  ]
}
