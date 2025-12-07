//
//  AbstractPlayableMO+CoreDataClass.swift
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

import CoreData
import Foundation

@objc(AbstractPlayableMO)
public class AbstractPlayableMO: AbstractLibraryEntityMO {
  func passOwnership(to targetPlayable: AbstractPlayableMO) {
    let playlistItemsCopy = playlistItems
    playlistItemsCopy.forEach {
      $0.playable = targetPlayable
    }

    let scrobbleCopy = scrobbleEntries?.compactMap { $0 as? ScrobbleEntryMO }
    scrobbleCopy?.forEach {
      $0.playable = targetPlayable
    }

    if targetPlayable.download == nil {
      targetPlayable.download = download
      download = nil
    }

    if targetPlayable.embeddedArtwork == nil {
      targetPlayable.embeddedArtwork = embeddedArtwork
      embeddedArtwork = nil
    }
  }
}
