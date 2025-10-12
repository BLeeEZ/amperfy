//
//  PodcastMO+CoreDataClass.swift
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

import CoreData
import Foundation

// MARK: - PodcastMO

@objc(PodcastMO)
public final class PodcastMO: AbstractLibraryEntityMO {
  override public func willSave() {
    super.willSave()
    if hasChangedEpisodes {
      updateEpisodeCount()
    }
  }

  fileprivate var hasChangedEpisodes: Bool {
    changedValues().keys.contains(#keyPath(episodes))
  }

  fileprivate func updateEpisodeCount() {
    guard Int16(clamping: episodes?.count ?? 0) != episodeCount else { return }
    episodeCount = Int16(clamping: episodes?.count ?? 0)
  }
}

// MARK: CoreDataIdentifyable

extension PodcastMO: CoreDataIdentifyable {
  static var identifierKey: KeyPath<PodcastMO, String?> {
    \PodcastMO.title
  }

  static var alphabeticSortedFetchRequest: NSFetchRequest<PodcastMO> {
    let fetchRequest: NSFetchRequest<PodcastMO> = PodcastMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(
        key: #keyPath(PodcastMO.alphabeticSectionInitial),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: Self.identifierKeyString,
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: "id",
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
    ]
    return fetchRequest
  }

  func passOwnership(to targetPodcast: PodcastMO) {
    let episodesCopy = episodes?.compactMap { $0 as? PodcastEpisodeMO }
    episodesCopy?.forEach {
      $0.podcast = targetPodcast
    }
  }
}
