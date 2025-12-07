//
//  BasicFetchedResultsController.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 19.04.21.
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

extension NSFetchedResultsController {
  @objc
  func fetch() {
    do {
      try performFetch()
    } catch let error as NSError {
      print("Unable to perform fetch: \(error.localizedDescription)")
    }
  }

  @objc
  func clearResults() {
    let oldPredicate = fetchRequest.predicate
    fetchRequest.predicate = NSPredicate(value: false)
    fetch()
    fetchRequest.predicate = oldPredicate
  }
}

// MARK: - SectionIndexType

public enum SectionIndexType: Int, Sendable {
  case alphabet = 0
  case rating = 1
  case newestOrRecent = 2
  case durationSong = 3
  case durationAlbum = 4
  case durationArtist = 5
  case none = 6
  case year = 7

  public static let defaultValue: SectionIndexType = .alphabet
  public static let noRatingIndexSymbol = "#"
  public static let noDurationSymbol = "#"
  public static let noYearSymbol = "#"
}

// MARK: - IndexHeaderNameGenerator

public class IndexHeaderNameGenerator {
  public static func sortByRating(forSectionName sectionName: String) -> String {
    guard !sectionName.isEmpty else { return SectionIndexType.noRatingIndexSymbol }
    let initial = String(sectionName.prefix(1))
    switch initial {
    case "5": return "5"
    case "4": return "4"
    case "3": return "3"
    case "2": return "2"
    case "1": return "1"
    default: return SectionIndexType.noRatingIndexSymbol
    }
  }

  public static func sortByDurationSong(forSectionName sectionName: String) -> String {
    if let durationInSec = Int(sectionName) {
      if durationInSec == 0 {
        return SectionIndexType.noDurationSymbol
      } else if durationInSec >= 3 * 60 * 60 {
        return Int(180 * 60).asColonDurationString
      } else if durationInSec >= 1 * 60 * 60 {
        return durationInSec.roundDownToFractionOf(30 * 60).asColonDurationString
      } else if durationInSec >= 30 * 60 {
        return durationInSec.roundDownToFractionOf(10 * 60).asColonDurationString
      } else if durationInSec >= 10 * 60 {
        return durationInSec.roundDownToFractionOf(5 * 60).asColonDurationString
      } else if durationInSec >= 5 * 60 {
        return durationInSec.roundDownToFractionOf(1 * 60).asColonDurationString
      } else {
        return durationInSec.roundDownToFractionOf(30).asColonDurationString
      }
    } else {
      return SectionIndexType.noDurationSymbol
    }
  }

  public static func sortByDurationAlbum(forSectionName sectionName: String) -> String {
    if let durationInSec = Int(sectionName) {
      if durationInSec == 0 {
        return SectionIndexType.noDurationSymbol
      } else if durationInSec >= 5 * 60 * 60 {
        return Int(5 * 60 * 60).asColonDurationString
      } else if durationInSec >= 100 * 60 {
        if durationInSec < 2 * 60 * 60 {
          return Int(100 * 60).asColonDurationString
        } else {
          return durationInSec.roundDownToFractionOf(60 * 60).asColonDurationString
        }
      } else if durationInSec >= 70 * 60 {
        return durationInSec.roundDownToFractionOf(10 * 60).asColonDurationString
      } else if durationInSec >= 30 * 60 {
        return durationInSec.roundDownToFractionOf(5 * 60).asColonDurationString
      } else if durationInSec >= 10 * 60 {
        return durationInSec.roundDownToFractionOf(10 * 60).asColonDurationString
      } else if durationInSec >= 1 * 60 {
        return durationInSec.roundDownToFractionOf(2 * 60).asColonDurationString
      } else {
        return Int(0).asColonDurationString
      }
    } else {
      return SectionIndexType.noDurationSymbol
    }
  }

  public static func sortByDurationArtist(forSectionName sectionName: String) -> String {
    if let durationInSec = Int(sectionName) {
      if durationInSec == 0 {
        return SectionIndexType.noDurationSymbol
      } else if durationInSec >= 20 * 60 * 60 {
        return Int(20 * 60 * 60).asColonDurationString
      } else if durationInSec >= 5 * 60 * 60 {
        return durationInSec.roundDownToFractionOf(5 * 60 * 60).asColonDurationString
      } else if durationInSec >= 60 * 60 {
        return durationInSec.roundDownToFractionOf(30 * 60).asColonDurationString
      } else if durationInSec >= 20 * 60 {
        return durationInSec.roundDownToFractionOf(10 * 60).asColonDurationString
      } else if durationInSec >= 5 * 60 {
        return durationInSec.roundDownToFractionOf(Int(2 * 60)).asColonDurationString
      } else {
        return Int(0).asColonDurationString
      }
    } else {
      return SectionIndexType.noDurationSymbol
    }
  }

  public static func sortByYear(forSectionName sectionName: String) -> String {
    if let year = Int(sectionName), year > 0 {
      return "\(year)"
    } else {
      return SectionIndexType.noYearSymbol
    }
  }
}

// MARK: - CustomSectionIndexFetchedResultsController

public class CustomSectionIndexFetchedResultsController<
  ResultType: NSFetchRequestResult
>: NSFetchedResultsController<NSFetchRequestResult> {
  public var sectionIndexType: SectionIndexType

  public init(
    fetchRequest: NSFetchRequest<ResultType>,
    coreDataCompanion: CoreDataCompanion,
    sectionNameKeyPath: String?,
    cacheName name: String?,
    sectionIndexType: SectionIndexType = .defaultValue
  ) {
    self.sectionIndexType = sectionIndexType
    super.init(
      fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>,
      managedObjectContext: coreDataCompanion.context,
      sectionNameKeyPath: sectionNameKeyPath,
      cacheName: name
    )
  }

  override public func sectionIndexTitle(forSectionName sectionName: String) -> String? {
    switch sectionIndexType {
    case .alphabet:
      return sectionName
    case .rating:
      return IndexHeaderNameGenerator.sortByRating(forSectionName: sectionName)
    case .newestOrRecent:
      return nil
    case .durationSong:
      return IndexHeaderNameGenerator.sortByDurationSong(forSectionName: sectionName)
    case .durationAlbum:
      return IndexHeaderNameGenerator.sortByDurationAlbum(forSectionName: sectionName)
    case .durationArtist:
      return IndexHeaderNameGenerator.sortByDurationArtist(forSectionName: sectionName)
    case .none:
      return nil
    case .year:
      return IndexHeaderNameGenerator.sortByYear(forSectionName: sectionName)
    }
  }
}

// MARK: - BasicFetchedResultsController

public class BasicFetchedResultsController<ResultType>: NSObject
  where ResultType: NSFetchRequestResult {
  public var fetchResultsController: CustomSectionIndexFetchedResultsController<ResultType>
  let coreDataCompanion: CoreDataCompanion
  let defaultPredicate: NSPredicate?
  public var delegate: NSFetchedResultsControllerDelegate? {
    set { fetchResultsController.delegate = newValue }
    get { fetchResultsController.delegate }
  }

  public var isSearchActive = false

  public init(
    coreDataCompanion: CoreDataCompanion,
    fetchRequest: NSFetchRequest<ResultType>,
    isGroupedInAlphabeticSections: Bool
  ) {
    self.coreDataCompanion = coreDataCompanion
    self.defaultPredicate = fetchRequest.predicate?.copy() as? NSPredicate
    let sectionNameKeyPath: String? = isGroupedInAlphabeticSections ? fetchRequest
      .sortDescriptors![0].key : nil
    self.fetchResultsController = CustomSectionIndexFetchedResultsController<ResultType>(
      fetchRequest: fetchRequest.copy() as! NSFetchRequest<ResultType>,
      coreDataCompanion: coreDataCompanion,
      sectionNameKeyPath: sectionNameKeyPath,
      cacheName: nil
    )
  }

  public func search(predicate: NSPredicate?) {
    isSearchActive = true
    fetchResultsController.fetchRequest.predicate = predicate
    fetchResultsController.fetch()
  }

  public func fetch() {
    fetchResultsController.fetch()
  }

  public func clearResults() {
    fetchResultsController.clearResults()
  }

  public func showAllResults() {
    isSearchActive = false
    fetchResultsController.fetchRequest.predicate = defaultPredicate
    fetch()
  }

  public var fetchedObjects: [ResultType]? {
    fetchResultsController.fetchedObjects as? [ResultType]
  }

  public var sections: [NSFetchedResultsSectionInfo]? {
    fetchResultsController.sections
  }

  public var numberOfSections: Int {
    fetchResultsController.sections?.count ?? 0
  }

  public func titleForHeader(inSection section: Int) -> String? {
    fetchResultsController.sectionIndexTitles.object(at: section)
  }

  public func numberOfRows(inSection section: Int) -> Int {
    fetchResultsController.sections?[section].numberOfObjects ?? 0
  }

  public var sectionIndexTitles: [String]? {
    fetchResultsController.sectionIndexTitles
  }

  public func section(forSectionIndexTitle title: String, at index: Int) -> Int {
    fetchResultsController.section(forSectionIndexTitle: title, at: index)
  }
}

extension BasicFetchedResultsController where ResultType == SearchHistoryItemMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> SearchHistoryItem {
    let searchHistoryItemMO = fetchResultsController.object(at: indexPath) as! ResultType
    return SearchHistoryItem(managedObject: searchHistoryItemMO)
  }
}

extension BasicFetchedResultsController where ResultType == GenreMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> Genre {
    let genreMO = fetchResultsController.object(at: indexPath) as! ResultType
    return Genre(managedObject: genreMO)
  }
}

extension BasicFetchedResultsController where ResultType == ArtistMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> Artist {
    let artistMO = fetchResultsController.object(at: indexPath) as! ResultType
    return Artist(managedObject: artistMO)
  }

  public func getWrappedEntity(at index: Int) -> Artist? {
    guard let fetchedObjects = fetchResultsController.fetchedObjects,
          index < fetchedObjects.count
    else { return nil }
    let managedObject = fetchedObjects[index] as! ResultType
    return Artist(managedObject: managedObject)
  }
}

extension BasicFetchedResultsController where ResultType == AlbumMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> Album {
    let albumMO = fetchResultsController.object(at: indexPath) as! ResultType
    return Album(managedObject: albumMO)
  }

  public func getWrappedEntity(at index: Int) -> Album? {
    guard let fetchedObjects = fetchResultsController.fetchedObjects,
          index < fetchedObjects.count
    else { return nil }
    let managedObject = fetchedObjects[index] as! ResultType
    return Album(managedObject: managedObject)
  }
}

extension BasicFetchedResultsController where ResultType == SongMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> Song {
    let songMO = fetchResultsController.object(at: indexPath) as! ResultType
    return Song(managedObject: songMO)
  }

  public func getWrappedEntity(at index: Int) -> Song? {
    guard let fetchedObjects = fetchResultsController.fetchedObjects,
          index < fetchedObjects.count
    else { return nil }
    let managedObject = fetchedObjects[index] as! ResultType
    return Song(managedObject: managedObject)
  }

  public func getContextSongs(onlyCachedSongs: Bool) -> [AbstractPlayable]? {
    guard let basicPredicate = defaultPredicate else { return nil }
    let cachedFetchRequest = fetchResultsController.fetchRequest.copy() as! NSFetchRequest<SongMO>
    cachedFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      basicPredicate,
      coreDataCompanion.library.getFetchPredicate(onlyCachedSongs: onlyCachedSongs),
    ])
    let songsMO = try? coreDataCompanion.context.fetch(cachedFetchRequest)
    let songs = songsMO?.compactMap { Song(managedObject: $0) }
    return songs
  }
}

extension BasicFetchedResultsController where ResultType == RadioMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> Radio {
    let radioMO = fetchResultsController.object(at: indexPath) as! ResultType
    return Radio(managedObject: radioMO)
  }

  public func getContextRadios() -> [AbstractPlayable]? {
    guard let basicPredicate = defaultPredicate else { return nil }
    let cachedFetchRequest = fetchResultsController.fetchRequest.copy() as! NSFetchRequest<RadioMO>
    cachedFetchRequest.predicate = basicPredicate
    let radiosMO = try? coreDataCompanion.context.fetch(cachedFetchRequest)
    let radios = radiosMO?.compactMap { Radio(managedObject: $0) }
    return radios
  }
}

extension BasicFetchedResultsController where ResultType == PlaylistMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> Playlist {
    let playlistMO = fetchResultsController.object(at: indexPath) as! ResultType
    return Playlist(library: coreDataCompanion.library, managedObject: playlistMO)
  }
}

extension BasicFetchedResultsController where ResultType == PlaylistItemMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> PlaylistItem {
    let itemMO = fetchResultsController.object(at: indexPath) as! ResultType
    return PlaylistItem(library: coreDataCompanion.library, managedObject: itemMO)
  }

  public func getContextSongs(onlyCachedSongs: Bool) -> [AbstractPlayable]? {
    guard let basicPredicate = defaultPredicate else { return nil }
    let cachedFetchRequest = fetchResultsController.fetchRequest
      .copy() as! NSFetchRequest<PlaylistItemMO>
    cachedFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      basicPredicate,
      coreDataCompanion.library.getFetchPredicate(onlyCachedPlaylistItems: onlyCachedSongs),
    ])
    let playlistItemsMO = try? coreDataCompanion.context.fetch(cachedFetchRequest)
    let playables = playlistItemsMO?.compactMap { $0.playable }
      .compactMap { AbstractPlayable(managedObject: $0) }
    return playables
  }
}

extension BasicFetchedResultsController where ResultType == LogEntryMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> LogEntry {
    let itemMO = fetchResultsController.object(at: indexPath) as! ResultType
    return LogEntry(managedObject: itemMO)
  }
}

extension BasicFetchedResultsController where ResultType == MusicFolderMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> MusicFolder {
    let musicFolderMO = fetchResultsController.object(at: indexPath) as! ResultType
    return MusicFolder(managedObject: musicFolderMO)
  }
}

extension BasicFetchedResultsController where ResultType == DirectoryMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> Directory {
    let directoryMO = fetchResultsController.object(at: indexPath) as! ResultType
    return Directory(managedObject: directoryMO)
  }
}

extension BasicFetchedResultsController where ResultType == PodcastMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> Podcast {
    let podcastMO = fetchResultsController.object(at: indexPath) as! ResultType
    return Podcast(managedObject: podcastMO)
  }
}

extension BasicFetchedResultsController where ResultType == PodcastEpisodeMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> PodcastEpisode {
    let podcastEpisodeMO = fetchResultsController.object(at: indexPath) as! ResultType
    return PodcastEpisode(managedObject: podcastEpisodeMO)
  }

  public func getWrappedEntity(at index: Int) -> PodcastEpisode? {
    guard let fetchedObjects = fetchResultsController.fetchedObjects,
          index < fetchedObjects.count
    else { return nil }
    let managedObject = fetchedObjects[index] as! ResultType
    return PodcastEpisode(managedObject: managedObject)
  }

  public func getContextPodcastEpisodes(onlyCachedSongs: Bool) -> [AbstractPlayable]? {
    guard let basicPredicate = defaultPredicate else { return nil }
    let cachedFetchRequest = fetchResultsController.fetchRequest
      .copy() as! NSFetchRequest<PodcastEpisodeMO>
    cachedFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      basicPredicate,
      coreDataCompanion.library.getFetchPredicate(onlyCachedPlaylistItems: onlyCachedSongs),
    ])
    let podcastEpisodesMO = try? coreDataCompanion.context.fetch(cachedFetchRequest)
    let playables = podcastEpisodesMO?.compactMap { PodcastEpisode(managedObject: $0) }
    return playables
  }
}

extension BasicFetchedResultsController where ResultType == DownloadMO {
  public func getWrappedEntity(at indexPath: IndexPath) -> Download {
    let downloadMO = fetchResultsController.object(at: indexPath) as! ResultType
    return Download(managedObject: downloadMO)
  }
}

// MARK: - CachedFetchedResultsController

public class CachedFetchedResultsController<ResultType>: BasicFetchedResultsController<ResultType>
  where ResultType: NSFetchRequestResult {
  let account: Account
  var keepAllResultsUpdated = true
  private let allFetchResulsController: CustomSectionIndexFetchedResultsController<ResultType>
  private let searchFetchResulsController: CustomSectionIndexFetchedResultsController<ResultType>
  private var sectionIndexType: SectionIndexType

  private var delegateInternal: NSFetchedResultsControllerDelegate?
  override public var delegate: NSFetchedResultsControllerDelegate? {
    set {
      delegateInternal = newValue
      updateFetchResultsControllerDelegate()
    }
    get { delegateInternal }
  }

  private var isSearchActiveInternal = false
  override public var isSearchActive: Bool {
    set {
      isSearchActiveInternal = newValue
      updateFetchResultsControllerDelegate()
    }
    get { isSearchActiveInternal }
  }

  public init(
    coreDataCompanion: CoreDataCompanion,
    fetchRequest: NSFetchRequest<ResultType>,
    account: Account,
    sectionIndexType: SectionIndexType = .defaultValue,
    isGroupedInAlphabeticSections: Bool
  ) {
    self.account = account
    self.sectionIndexType = sectionIndexType
    let sectionNameKeyPath: String? = isGroupedInAlphabeticSections ? fetchRequest
      .sortDescriptors![0].key : nil
    self.allFetchResulsController = CustomSectionIndexFetchedResultsController<ResultType>(
      fetchRequest: fetchRequest.copy() as! NSFetchRequest<ResultType>,
      coreDataCompanion: coreDataCompanion,
      sectionNameKeyPath: sectionNameKeyPath,
      cacheName: "\(Self.typeName)-\(account.serverHash)-\(account.userHash)"
    )
    allFetchResulsController.sectionIndexType = sectionIndexType
    self.searchFetchResulsController = CustomSectionIndexFetchedResultsController<ResultType>(
      fetchRequest: fetchRequest.copy() as! NSFetchRequest<ResultType>,
      coreDataCompanion: coreDataCompanion,
      sectionNameKeyPath: sectionNameKeyPath,
      cacheName: nil
    )
    searchFetchResulsController.sectionIndexType = sectionIndexType
    super.init(
      coreDataCompanion: coreDataCompanion,
      fetchRequest: fetchRequest,
      isGroupedInAlphabeticSections: isGroupedInAlphabeticSections
    )
    fetchResultsController = allFetchResulsController
  }

  override public func search(predicate: NSPredicate?) {
    isSearchActive = true
    searchFetchResulsController.fetchRequest.predicate = predicate
    searchFetchResulsController.fetch()
  }

  public static func deleteCache() {
    NSFetchedResultsController<ResultType>.deleteCache(withName: Self.typeName)
  }

  override public func fetch() {
    isSearchActive = false
    allFetchResulsController.fetch()
  }

  override public func showAllResults() {
    fetch()
  }

  override public func clearResults() {
    isSearchActive = true
    searchFetchResulsController.clearResults()
  }

  private func updateFetchResultsControllerDelegate() {
    fetchResultsController.delegate = nil
    if isSearchActiveInternal {
      fetchResultsController = searchFetchResulsController
      fetchResultsController.delegate = delegateInternal
    } else {
      fetchResultsController = allFetchResulsController
      if keepAllResultsUpdated {
        fetchResultsController.delegate = delegateInternal
      }
    }
  }

  public func hideResults() {
    isSearchActive = true
    searchFetchResulsController.fetchRequest.predicate = NSPredicate(format: "id == nil")
    searchFetchResulsController.fetch()
  }

  public func isOneOfThis(_ controller: NSFetchedResultsController<NSFetchRequestResult>) -> Bool {
    (controller == allFetchResulsController) || (controller == searchFetchResulsController)
  }
}
