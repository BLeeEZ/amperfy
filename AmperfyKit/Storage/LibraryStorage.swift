//
//  LibraryStorage.swift
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
import os.log

// MARK: - PlayableFileCachable

protocol PlayableFileCachable {
  func getFileURL(forPlayable playable: AbstractPlayable) -> URL?
}

// MARK: - PlaylistSearchCategory

public enum PlaylistSearchCategory: Int, Sendable {
  case all = 0
  case cached = 1
  case userOnly = 2
  case smartOnly = 3

  public static let defaultValue: PlaylistSearchCategory = .all
}

// MARK: - LibraryDuplicateInfo

struct LibraryDuplicateInfo {
  let id: String
  let count: Int
}

// MARK: - LibraryStorage

public class LibraryStorage: PlayableFileCachable {
  public static let carPlayMaxElements = 200

  static let entitiesToDelete = [
    Genre.typeName,
    Artist.typeName,
    Album.typeName,
    Song.typeName,
    Artwork.typeName,
    EmbeddedArtwork.typeName,
    Playlist.typeName,
    PlaylistItem.typeName,
    PlayerData.entityName,
    LogEntry.typeName,
    MusicFolder.typeName,
    Directory.typeName,
    Podcast.typeName,
    PodcastEpisode.typeName,
    Radio.typeName,
    Download.typeName,
    ScrobbleEntry.typeName,
    SearchHistoryItem.typeName,
    // Accounts are not going to get deleted
  ]
  private let log = OSLog(subsystem: "Amperfy", category: "LibraryStorage")
  private var context: NSManagedObjectContext
  private let fileManager = CacheFileManager.shared

  public init(context: NSManagedObjectContext) {
    self.context = context
  }

  func resolveGenresDuplicates(account: Account, duplicates: [LibraryDuplicateInfo], byName: Bool) {
    guard !duplicates.isEmpty else { return }
    let duplicateIds = Set(duplicates.compactMap { $0.id })
    let genreDuplicatesList = byName ? getGenresDictList(account: account, names: duplicateIds) :
      getGenresDictList(account: account, ids: duplicateIds)

    for genreDuplicates in genreDuplicatesList {
      var duplicateList = genreDuplicates.value
      let lead = duplicateList.removeFirst()
      if byName {
        os_log(
          "Duplicated Genre (count %i): %s",
          log: log,
          type: .info,
          genreDuplicates.value.count,
          lead.name
        )
      } else {
        os_log(
          "Duplicated Genre (count %i) (id: %s): %s",
          log: log,
          type: .info,
          genreDuplicates.value.count,
          genreDuplicates.key,
          lead.name
        )
      }
      for genre in duplicateList {
        genre.managedObject.passOwnership(to: lead.managedObject)
        context.delete(genre.managedObject)
      }
    }
  }

  func resolveArtistsDuplicates(account: Account, duplicates: [LibraryDuplicateInfo]) {
    guard !duplicates.isEmpty else { return }
    let duplicateIds = Set(duplicates.compactMap { $0.id })
    let artistDuplicatesList = getArtistsDictList(account: account, ids: duplicateIds)

    for artistDuplicates in artistDuplicatesList {
      var duplicateList = artistDuplicates.value
      let lead = duplicateList.removeFirst()
      os_log(
        "Duplicated Artist (count %i) (id: %s): %s",
        log: log,
        type: .info,
        artistDuplicates.value.count,
        artistDuplicates.key,
        lead.name
      )
      for artist in duplicateList {
        artist.managedObject.passOwnership(to: lead.managedObject)
        context.delete(artist.managedObject)
      }
    }
  }

  func resolveAlbumsDuplicates(account: Account, duplicates: [LibraryDuplicateInfo]) {
    guard !duplicates.isEmpty else { return }
    let duplicateIds = Set(duplicates.compactMap { $0.id })
    let albumDuplicatesList = getAlbumsDictList(account: account, ids: duplicateIds)

    for albumDuplicates in albumDuplicatesList {
      var duplicateList = albumDuplicates.value
      let lead = duplicateList.removeFirst()
      os_log(
        "Duplicated Album (count %i) (id: %s): %s",
        log: log,
        type: .info,
        albumDuplicates.value.count,
        albumDuplicates.key,
        lead.name
      )
      for album in duplicateList {
        album.managedObject.passOwnership(to: lead.managedObject)
        context.delete(album.managedObject)
      }
    }
  }

  func resolveSongsDuplicates(account: Account, duplicates: [LibraryDuplicateInfo]) {
    guard !duplicates.isEmpty else { return }
    let duplicateIds = Set(duplicates.compactMap { $0.id })
    let songDuplicatesList = getSongsDictList(account: account, ids: duplicateIds)

    for songDuplicates in songDuplicatesList {
      var duplicateList = songDuplicates.value
      let lead = duplicateList.removeFirst()
      os_log(
        "Duplicated Song (count %i) (id: %s): %s",
        log: log,
        type: .info,
        songDuplicates.value.count,
        songDuplicates.key,
        lead.displayString
      )
      for song in duplicateList {
        song.managedObject.passOwnership(to: lead.managedObject)
        if let embeddedArtwork = song.managedObject.embeddedArtwork {
          context.delete(embeddedArtwork)
        }
        if let download = song.managedObject.download {
          context.delete(download)
        }
        context.delete(song.managedObject)
      }
    }
  }

  func resolvePodcastEpisodesDuplicates(account: Account, duplicates: [LibraryDuplicateInfo]) {
    guard !duplicates.isEmpty else { return }
    let duplicateIds = Set(duplicates.compactMap { $0.id })
    let podcastEpisodeDuplicatesList = getPodcastEpisodesDictList(
      account: account,
      ids: duplicateIds
    )

    for podcastEpisodeDuplicates in podcastEpisodeDuplicatesList {
      var duplicateList = podcastEpisodeDuplicates.value
      let lead = duplicateList.removeFirst()
      os_log(
        "Duplicated Podcast Episode (count %i) (id: %s): %s",
        log: log,
        type: .info,
        podcastEpisodeDuplicates.value.count,
        podcastEpisodeDuplicates.key,
        lead.displayString
      )
      for podcastEpisode in duplicateList {
        podcastEpisode.managedObject.passOwnership(to: lead.managedObject)
        if let embeddedArtwork = podcastEpisode.managedObject.embeddedArtwork {
          context.delete(embeddedArtwork)
        }
        if let download = podcastEpisode.managedObject.download {
          context.delete(download)
        }
        context.delete(podcastEpisode.managedObject)
      }
    }
  }

  func resolveRadioDuplicates(account: Account, duplicates: [LibraryDuplicateInfo]) {
    guard !duplicates.isEmpty else { return }
    let duplicateIds = Set(duplicates.compactMap { $0.id })
    let radioDuplicatesList = getRadiosDictList(account: account, ids: duplicateIds)

    for radioDuplicates in radioDuplicatesList {
      var duplicateList = radioDuplicates.value
      let lead = duplicateList.removeFirst()
      os_log(
        "Duplicated Radio (count %i) (id: %s): %s",
        log: log,
        type: .info,
        radioDuplicates.value.count,
        radioDuplicates.key,
        lead.displayString
      )
      for radio in duplicateList {
        radio.managedObject.passOwnership(to: lead.managedObject)
        if let download = radio.managedObject.download {
          context.delete(download)
        }
        context.delete(radio.managedObject)
      }
    }
  }

  func resolvePodcastsDuplicates(account: Account, duplicates: [LibraryDuplicateInfo]) {
    guard !duplicates.isEmpty else { return }
    let duplicateIds = Set(duplicates.compactMap { $0.id })
    let podcastDuplicatesList = getPodcastsDictList(account: account, ids: duplicateIds)

    for podcastDuplicates in podcastDuplicatesList {
      var duplicateList = podcastDuplicates.value
      let lead = duplicateList.removeFirst()
      os_log(
        "Duplicated Podcast (count %i) (id: %s): %s",
        log: log,
        type: .info,
        podcastDuplicates.value.count,
        podcastDuplicates.key,
        lead.name
      )
      for podcast in duplicateList {
        podcast.managedObject.passOwnership(to: lead.managedObject)
        context.delete(podcast.managedObject)
      }
    }
  }

  func resolvePlaylistsDuplicates(account: Account, duplicates: [LibraryDuplicateInfo]) {
    guard !duplicates.isEmpty else { return }
    let duplicateIds = Set(duplicates.compactMap { $0.id })
    let playlistDuplicatesList = getPlaylistsDictList(account: account, ids: duplicateIds)

    for playlistDuplicates in playlistDuplicatesList {
      var duplicateList = playlistDuplicates.value
      let lead = duplicateList.removeFirst()
      os_log(
        "Duplicated Playlist (count %i) (id: %s): %s",
        log: log,
        type: .info,
        playlistDuplicates.value.count,
        playlistDuplicates.key,
        lead.name
      )
      for playlist in duplicateList {
        playlist.managedObject.passOwnership(to: lead.managedObject)
        deletePlaylist(playlist)
      }
    }
  }

  func findDuplicates(
    for entityName: String,
    keyPathString: String,
    account: Account
  )
    -> [LibraryDuplicateInfo] {
    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: entityName)
    let idExpr = NSExpression(forKeyPath: keyPathString)
    let countExpr = NSExpressionDescription()
    let countVariableExpr = NSExpression(forVariable: "count")

    countExpr.name = "count"
    countExpr.expression = NSExpression(forFunction: "count:", arguments: [idExpr])
    countExpr.expressionResultType = .integer64AttributeType

    fetchRequest.resultType = .dictionaryResultType
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: keyPathString, ascending: true)]
    fetchRequest.propertiesToGroupBy = [keyPathString]
    fetchRequest.propertiesToFetch = [keyPathString, countExpr]
    fetchRequest.havingPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(format: "%@ > 1", countVariableExpr),
    ])

    let results = (try? context.fetch(fetchRequest)) ?? [NSDictionary]()
    return results.compactMap {
      // remove results with id == ""
      guard let id = $0[keyPathString] as? String, !id.isEmpty,
            let count = $0["count"] as? Int else { return nil }
      return LibraryDuplicateInfo(id: id, count: count)
    }
  }

  func getInfo(account: Account) -> AccountLibraryInfo {
    var libraryInfo = AccountLibraryInfo()
    libraryInfo.apiType = account.apiType.description
    libraryInfo.artistCount = getArtistCount(for: account)
    libraryInfo.albumCount = getAlbumCount(for: account)
    libraryInfo.songCount = getSongCount(for: account)
    libraryInfo.cachedSongCount = getCachedSongCount(for: account)
    libraryInfo.playlistCount = getPlaylistCount(for: account)
    libraryInfo.cachedSongSize = fileManager.getPlayableCacheSize(for: account.info).asByteString
    libraryInfo.genreCount = getGenreCount(for: account)
    libraryInfo.artworkCount = getArtworkCount(for: account)
    libraryInfo.musicFolderCount = getMusicFolderCount(for: account)
    libraryInfo.directoryCount = getDirectoryCount(for: account)
    libraryInfo.podcastCount = getPodcastCount(for: account)
    libraryInfo.podcastEpisodeCount = getPodcastEpisodeCount(for: account)
    libraryInfo.radioCount = getRadioCount(for: account)
    return libraryInfo
  }

  public func getGenreCount(for account: Account) -> Int {
    let request: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getArtistCount(for account: Account) -> Int {
    let request: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getAlbumCount(for account: Account) -> Int {
    let request: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %i",
        #keyPath(AlbumMO.remoteStatus),
        RemoteStatus.available.rawValue
      ),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getAlbumWithSyncedSongsCount(for account: Account) -> Int {
    let request: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %i",
        #keyPath(AlbumMO.remoteStatus),
        RemoteStatus.available.rawValue
      ),
      NSPredicate(format: "%K == TRUE", #keyPath(AlbumMO.isSongsMetaDataSynced)),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getSongCount(for account: Account) -> Int {
    let request: NSFetchRequest<SongMO> = SongMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getUploadableScrobbleEntryCount(for account: Account) -> Int {
    let fetchRequest = ScrobbleEntryMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == FALSE",
        #keyPath(ScrobbleEntryMO.isUploaded)
      ),
    ])
    return (try? context.count(for: fetchRequest)) ?? 0
  }

  public func getArtworkCount(for account: Account) -> Int {
    let request: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getArtworkNotCheckedCount(for account: Account) -> Int {
    let request: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(format: "%K == nil", #keyPath(ArtworkMO.relFilePath)),
      NSPredicate(
        format: "%K == %@",
        #keyPath(ArtworkMO.status),
        NSNumber(integerLiteral: Int(ImageStatus.NotChecked.rawValue))
      ),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getCachedArtworkCount(for account: Account) -> Int {
    let request: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(format: "%K != nil", #keyPath(ArtworkMO.relFilePath)),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getMusicFolderCount(for account: Account) -> Int {
    let request: NSFetchRequest<MusicFolderMO> = MusicFolderMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getDirectoryCount(for account: Account) -> Int {
    let request: NSFetchRequest<DirectoryMO> = DirectoryMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getCachedSongCount(for account: Account) -> Int {
    let request: NSFetchRequest<SongMO> = SongMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      getFetchPredicate(onlyCachedSongs: true),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getPlaylistCount(for account: Account) -> Int {
    let request: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      PlaylistMO.excludeSystemPlaylistsFetchPredicate,
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getPodcastCount(for account: Account) -> Int {
    let request: NSFetchRequest<PodcastMO> = PodcastMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getPodcastEpisodeCount(for account: Account) -> Int {
    let request: NSFetchRequest<PodcastEpisodeMO> = PodcastEpisodeMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getRadioCount(for account: Account) -> Int {
    let request: NSFetchRequest<RadioMO> = RadioMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getCachedPodcastEpisodeCount(for account: Account) -> Int {
    let request: NSFetchRequest<PodcastEpisodeMO> = PodcastEpisodeMO.fetchRequest()
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      getFetchPredicate(onlyCachedPodcastEpisodes: true),
    ])
    return (try? context.count(for: request)) ?? 0
  }

  public func getAllAccounts() -> [Account] {
    let fetchRequest = AccountMO.fetchRequest()
    let accountMOs = try? context.fetch(fetchRequest)
    let accounts = accountMOs?.compactMap {
      Account(managedObject: $0)
    }
    return accounts ?? [Account]()
  }

  public func createAccount(info: AccountInfo) -> Account {
    let account = Account(managedObject: AccountMO(context: context))
    account.assignInfo(info: info)
    return account
  }

  func deleteAccount(account: Account) {
    context.delete(account.managedObject)
  }

  public func getAccount(managedObjectId: NSManagedObjectID) -> Account {
    Account(
      managedObject: context
        .object(with: managedObjectId) as! AccountMO
    )
  }

  public func getAccount(ident: String) -> Account? {
    guard let accountInfo = AccountInfo.create(basedOnIdent: ident) else { return nil }
    let fetchRequest = AccountMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      NSPredicate(format: "%K == %@", #keyPath(AccountMO.serverHash), accountInfo.serverHash),
      NSPredicate(format: "%K == %@", #keyPath(AccountMO.userHash), accountInfo.userHash),
    ])
    fetchRequest.fetchLimit = 1
    guard let accounts = try? context.fetch(fetchRequest),
          let accountMO = accounts.lazy.first
    else { return nil }
    return Account(managedObject: accountMO)
  }

  public func getAccount(info: AccountInfo) -> Account {
    let fetchRequest = AccountMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      NSPredicate(format: "%K == %@", #keyPath(AccountMO.serverHash), info.serverHash),
      NSPredicate(format: "%K == %@", #keyPath(AccountMO.userHash), info.userHash),
    ])
    fetchRequest.fetchLimit = 1
    if let accounts = try? context.fetch(fetchRequest),
       let accountMO = accounts.lazy.first {
      return Account(managedObject: accountMO)
    } else {
      // create an "empty" Account
      let account = createAccount(info: info)
      saveContext()
      return account
    }
  }

  func createGenre(account: Account) -> Genre {
    let genreMO = GenreMO(context: context)
    genreMO.account = account.managedObject
    return Genre(managedObject: genreMO)
  }

  func createArtist(account: Account) -> Artist {
    let artistMO = ArtistMO(context: context)
    artistMO.account = account.managedObject
    return Artist(managedObject: artistMO)
  }

  func deleteArtist(artist: Artist) {
    context.delete(artist.managedObject)
  }

  func createAlbum(account: Account) -> Album {
    let albumMO = AlbumMO(context: context)
    albumMO.account = account.managedObject
    return Album(managedObject: albumMO)
  }

  func deleteAlbum(album: Album) {
    context.delete(album.managedObject)
  }

  func createPodcast(account: Account) -> Podcast {
    let podcastMO = PodcastMO(context: context)
    podcastMO.account = account.managedObject
    return Podcast(managedObject: podcastMO)
  }

  func deletePodcast(_ podcast: Podcast) {
    context.delete(podcast.managedObject)
  }

  func createPodcastEpisode(account: Account) -> PodcastEpisode {
    let podcastEpisodeMO = PodcastEpisodeMO(context: context)
    podcastEpisodeMO.account = account.managedObject
    return PodcastEpisode(managedObject: podcastEpisodeMO)
  }

  func createSong(account: Account) -> Song {
    let songMO = SongMO(context: context)
    songMO.account = account.managedObject
    return Song(managedObject: songMO)
  }

  func createRadio(account: Account) -> Radio {
    let radioMO = RadioMO(context: context)
    radioMO.account = account.managedObject
    return Radio(managedObject: radioMO)
  }

  func createScrobbleEntry(account: Account) -> ScrobbleEntry {
    let scrobbleEntryMO = ScrobbleEntryMO(context: context)
    scrobbleEntryMO.account = account.managedObject
    return ScrobbleEntry(managedObject: scrobbleEntryMO)
  }

  func deleteRadio(_ radio: Radio) {
    context.delete(radio.managedObject)
  }

  func deleteScrobbleEntry(_ scrobbleEntry: ScrobbleEntry) {
    context.delete(scrobbleEntry.managedObject)
  }

  func createMusicFolder(account: Account) -> MusicFolder {
    let musicFolderMO = MusicFolderMO(context: context)
    let musicFolder = MusicFolder(managedObject: musicFolderMO)
    musicFolder.account = account
    return musicFolder
  }

  func deleteMusicFolder(musicFolder: MusicFolder) {
    context.delete(musicFolder.managedObject)
  }

  func createDirectory(account: Account) -> Directory {
    let directoryMO = DirectoryMO(context: context)
    directoryMO.account = account.managedObject
    return Directory(managedObject: directoryMO)
  }

  func deleteDirectory(directory: Directory) {
    context.delete(directory.managedObject)
  }

  func createLogEntry() -> LogEntry {
    let logEntryMO = LogEntryMO(context: context)
    logEntryMO.creationDate = Date()
    return LogEntry(managedObject: logEntryMO)
  }

  private func createUserStatistics(appVersion: String) -> UserStatistics {
    let userStatistics = UserStatisticsMO(context: context)
    userStatistics.creationDate = Date()
    userStatistics.appVersion = appVersion
    return UserStatistics(managedObject: userStatistics, library: self)
  }

  public func deleteCache(ofPlayable playable: AbstractPlayable) {
    if let account = playable.account,
       let relFilePath = playable.relFilePath,
       fileManager.fileExits(relFilePath: relFilePath),
       let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
      do {
        try fileManager.removeItem(at: absFilePath, accountInfo: account.info)
      } catch {
        os_log(
          "File for <%s> could not be removed at <%s>",
          log: log,
          type: .info,
          playable.displayString,
          absFilePath.path
        )
      }
    }
    deleteCacheFinalStep(playable: playable)
  }

  private func deleteCacheFinalStep(playable: AbstractPlayable) {
    playable.contentTypeTranscoded = nil
    playable.relFilePath = nil
    playable.deleteCache()
  }

  public func deleteCache(of playables: [AbstractPlayable]) {
    for playable in playables {
      deleteCache(ofPlayable: playable)
    }
  }

  public func deleteCache(of playableContainer: PlayableContainable) {
    for playable in playableContainer.playables {
      deleteCache(ofPlayable: playable)
    }
  }

  public func deletePlayableCachePaths(for account: Account) {
    let songs = getCachedSongs(for: account)
    songs.forEach {
      deleteCacheFinalStep(playable: $0)
    }
    let episodes = getCachedPodcastEpisodes(for: account)
    episodes.forEach {
      deleteCacheFinalStep(playable: $0)
    }
  }

  public func deleteRemoteArtworkCachePaths(account: Account) {
    let fetchRequest = ArtworkMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
    ])
    guard let artworksMO = try? context.fetch(fetchRequest) else { return }
    var artworksToDelete = [ArtworkMO]()
    for artworkMO in artworksMO {
      artworkMO.status = ImageStatus.NotChecked.rawValue
      artworkMO.relFilePath = nil
      if artworkMO.id.isEmpty {
        artworksToDelete.append(artworkMO)
      }
    }
    for artwork in artworksToDelete {
      deleteArtwork(artwork: Artwork(managedObject: artwork))
    }
  }

  func createEmbeddedArtwork(account: Account) -> EmbeddedArtwork {
    let artwork = EmbeddedArtwork(managedObject: EmbeddedArtworkMO(context: context))
    artwork.account = account
    return artwork
  }

  func createArtwork(account: Account) -> Artwork {
    let artwork = Artwork(managedObject: ArtworkMO(context: context))
    artwork.account = account
    return artwork
  }

  func deleteArtwork(artwork: Artwork) {
    context.delete(artwork.managedObject)
  }

  public func createPlaylist(account: Account) -> Playlist {
    let playlist = Playlist(library: self, managedObject: PlaylistMO(context: context))
    playlist.account = account
    return playlist
  }

  public func deletePlaylist(_ playlist: Playlist) {
    playlist.removeAllItems()
    context.delete(playlist.managedObject)
  }

  func createPlaylistItem(playable: AbstractPlayable) -> PlaylistItem {
    let itemMO = PlaylistItemMO(context: context)
    itemMO.playable = playable.playableManagedObject
    itemMO.account = playable.account?.managedObject
    return PlaylistItem(library: self, managedObject: itemMO)
  }

  func deletePlaylistItem(item: PlaylistItem) {
    context.delete(item.managedObject)
  }

  func deletePlaylistItemMO(item: PlaylistItemMO) {
    context.delete(item)
  }

  func createDownload(account: Account, id: String) -> Download {
    let download = Download(managedObject: DownloadMO(context: context))
    download.account = account
    download.id = id
    return download
  }

  func getAllDownloads() -> [Download] {
    let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.fetchRequest()
    let downloadsMO = try? context.fetch(fetchRequest)
    let downloads = downloadsMO?.compactMap {
      Download(managedObject: $0)
    }
    return downloads ?? [Download]()
  }

  func getDownload(account: Account, id: String) -> Download? {
    let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(DownloadMO.id),
        NSString(string: id)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let downloads = try? context.fetch(fetchRequest)
    if let downloadMO = downloads?.lazy.first {
      let download = Download(managedObject: downloadMO)
      return download
    }
    return nil
  }

  func getDownloads(account: Account, ids: Set<String>) -> [Download] {
    let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(DownloadMO.id),
        ids
      ),
    ])
    let downloadMOs = try? context.fetch(fetchRequest)
    return downloadMOs?.compactMap { Download(managedObject: $0) } ?? [Download]()
  }
  
  func getDownloadsDict(
    account: Account,
    ids: Set<String>
  )
    -> [String: Download] {
    let downloads = getDownloads(account: account, ids: ids)

    var downloadDict = [String: Download]()
    for download in downloads {
      downloadDict[download.id] = download
    }
    return downloadDict
  }

  func deleteDownload(_ download: Download) {
    context.delete(download.managedObject)
  }

  public func getContainer(identifier: PlayableContainerIdentifier) -> PlayableContainable? {
    guard let type = identifier.type,
          let objectID = identifier.objectID,
          let url = URL(string: objectID),
          let managedObjectID = context.persistentStoreCoordinator?
          .managedObjectID(forURIRepresentation: url)
    else { return nil }

    switch type {
    case .song:
      return Song(managedObject: context.object(with: managedObjectID) as! SongMO)
    case .podcastEpisode:
      return PodcastEpisode(
        managedObject: context
          .object(with: managedObjectID) as! PodcastEpisodeMO
      )
    case .album:
      return Album(managedObject: context.object(with: managedObjectID) as! AlbumMO)
    case .artist:
      return Artist(managedObject: context.object(with: managedObjectID) as! ArtistMO)
    case .genre:
      return Genre(managedObject: context.object(with: managedObjectID) as! GenreMO)
    case .playlist:
      return Playlist(
        library: self,
        managedObject: context.object(with: managedObjectID) as! PlaylistMO
      )
    case .podcast:
      return Podcast(managedObject: context.object(with: managedObjectID) as! PodcastMO)
    case .directory:
      return Directory(managedObject: context.object(with: managedObjectID) as! DirectoryMO)
    case .radio:
      return Radio(managedObject: context.object(with: managedObjectID) as! RadioMO)
    }
  }

  public func createOrUpdateSearchHistory(container: PlayableContainable) -> SearchHistoryItem {
    let fetchRequest: NSFetchRequest<SearchHistoryItemMO> = SearchHistoryItemMO.fetchRequest()
    var predicate: NSPredicate?
    var account: Account?

    if let song = container as? Song {
      predicate = NSPredicate(
        format: "%K == %@",
        #keyPath(SearchHistoryItemMO.searchedLibraryEntity),
        song.managedObject
      )
      account = song.account
    } else if let episode = container as? PodcastEpisode {
      predicate = NSPredicate(
        format: "%K == %@",
        #keyPath(SearchHistoryItemMO.searchedLibraryEntity),
        episode.managedObject
      )
      account = episode.account
    } else if let album = container as? Album {
      predicate = NSPredicate(
        format: "%K == %@",
        #keyPath(SearchHistoryItemMO.searchedLibraryEntity),
        album.managedObject
      )
      account = album.account
    } else if let artist = container as? Artist {
      predicate = NSPredicate(
        format: "%K == %@",
        #keyPath(SearchHistoryItemMO.searchedLibraryEntity),
        artist.managedObject
      )
      account = artist.account
    } else if let podcast = container as? Podcast {
      predicate = NSPredicate(
        format: "%K == %@",
        #keyPath(SearchHistoryItemMO.searchedLibraryEntity),
        podcast.managedObject
      )
      account = podcast.account
    } else if let playlist = container as? Playlist {
      predicate = NSPredicate(
        format: "%K == %@",
        #keyPath(SearchHistoryItemMO.searchedPlaylist),
        playlist.managedObject
      )
      account = playlist.account
    }

    fetchRequest.predicate = predicate
    fetchRequest.fetchLimit = 1
    let searchHistoryMO = try? context.fetch(fetchRequest)
    if let searchHistory = searchHistoryMO?.lazy
      .compactMap({ SearchHistoryItem(managedObject: $0) }).first {
      // update the existing one
      searchHistory.date = Date()
      return searchHistory
    } else {
      // create a new item
      let itemMO = SearchHistoryItemMO(context: context)
      let item = SearchHistoryItem(managedObject: itemMO)
      item.date = Date()
      item.searchedPlayableContainable = container
      item.account = account
      return item
    }
  }

  public func deleteSearchHistory() {
    clearStorage(ofType: SearchHistoryItem.typeName)
  }

  // MARK: FetchPredicates

  func getFetchPredicate(forAccount account: Account) -> NSPredicate {
    NSPredicate(format: "account == %@", account.managedObject.objectID)
  }

  func getFetchPredicate(forGenre genre: Genre) -> NSPredicate {
    NSPredicate(format: "genre == %@", genre.managedObject.objectID)
  }

  func getFetchPredicate(forArtist artist: Artist) -> NSPredicate {
    NSPredicate(format: "artist == %@", artist.managedObject.objectID)
  }

  func getFetchPredicate(forAlbum album: Album) -> NSPredicate {
    NSPredicate(format: "album == %@", album.managedObject.objectID)
  }

  func getFetchPredicate(forPlaylist playlist: Playlist) -> NSPredicate {
    NSPredicate(
      format: "%K == %@",
      #keyPath(PlaylistItemMO.playlist),
      playlist.managedObject.objectID
    )
  }

  func getFetchPredicateForOrphanedPlaylistItems() -> NSPredicate {
    NSCompoundPredicate(orPredicateWithSubpredicates: [
      NSPredicate(format: "%K == nil", #keyPath(PlaylistItemMO.playlist)),
      NSPredicate(format: "%K == nil", #keyPath(PlaylistItemMO.playable)),
    ])
  }

  func getFetchPredicateForUserAvailableEpisodes() -> NSPredicate {
    NSCompoundPredicate(orPredicateWithSubpredicates: [
      getFetchPredicate(onlyCachedPodcastEpisodes: true),
      NSPredicate(
        format: "%K != %i",
        #keyPath(PodcastEpisodeMO.status),
        PodcastEpisodeRemoteStatus.deleted.rawValue
      ),
    ])
  }

  func getFetchPredicateForUserAvailableEpisodes(forPodcast podcast: Podcast) -> NSPredicate {
    NSCompoundPredicate(andPredicateWithSubpredicates: [
      NSPredicate(
        format: "%K == %@",
        #keyPath(PodcastEpisodeMO.podcast),
        podcast.managedObject.objectID
      ),
      getFetchPredicateForUserAvailableEpisodes(),
    ])
  }

  func getFetchPredicate(forMusicFolder musicFolder: MusicFolder) -> NSPredicate {
    NSPredicate(format: "musicFolder == %@", musicFolder.managedObject.objectID)
  }

  func getSongFetchPredicate(forDirectory directory: Directory) -> NSPredicate {
    NSPredicate(format: "%K == %@", #keyPath(SongMO.directory), directory.managedObject.objectID)
  }

  func getDirectoryFetchPredicate(forDirectory directory: Directory) -> NSPredicate {
    NSPredicate(format: "%K == %@", #keyPath(DirectoryMO.parent), directory.managedObject.objectID)
  }

  func getFetchPredicate(onlyCachedArtists: Bool) -> NSPredicate {
    if onlyCachedArtists {
      return NSPredicate(format: "SUBQUERY(songs, $song, $song.relFilePath != nil) .@count > 0")
    } else {
      return NSPredicate(value: true)
    }
  }

  func getFetchPredicate(onlyCachedAlbums: Bool) -> NSPredicate {
    if onlyCachedAlbums {
      return NSPredicate(format: "SUBQUERY(songs, $song, $song.relFilePath != nil) .@count > 0")
    } else {
      return NSPredicate(value: true)
    }
  }

  func getFetchPredicate(forSongsOfArtistWithCommonAlbum artist: Artist) -> NSPredicate {
    NSPredicate(format: "%K == %@", #keyPath(SongMO.album.artist), artist.managedObject.objectID)
  }

  func getFetchPredicate(onlyCachedPlaylistItems: Bool) -> NSPredicate {
    if onlyCachedPlaylistItems {
      return NSPredicate(format: "%K != nil", #keyPath(PlaylistItemMO.playable.relFilePath))
    } else {
      return NSPredicate(value: true)
    }
  }

  func getFetchPredicate(onlyCachedSongs: Bool) -> NSPredicate {
    if onlyCachedSongs {
      return NSCompoundPredicate(orPredicateWithSubpredicates: [
        NSPredicate(format: "%K != nil", #keyPath(SongMO.relFilePath)),
      ])
    } else {
      return NSPredicate(value: true)
    }
  }

  func getFetchPredicate(onlyCachedPodcasts: Bool) -> NSPredicate {
    if onlyCachedPodcasts {
      return NSPredicate(
        format: "SUBQUERY(episodes, $episode, $episode.relFilePath != nil) .@count > 0"
      )
    } else {
      return NSPredicate(value: true)
    }
  }

  func getFetchPredicate(onlyCachedPodcastEpisodes: Bool) -> NSPredicate {
    if onlyCachedPodcastEpisodes {
      return NSCompoundPredicate(orPredicateWithSubpredicates: [
        NSPredicate(format: "%K != nil", #keyPath(PodcastEpisodeMO.relFilePath)),
      ])
    } else {
      return NSPredicate(value: true)
    }
  }

  func getFetchPredicate(onlyCachedGenreArtists: Bool) -> NSPredicate {
    if onlyCachedGenreArtists {
      return NSPredicate(
        format: "SUBQUERY(artists, $artist, ANY $artist.songs.relFilePath != nil) .@count > 0"
      )
    } else {
      return NSPredicate(value: true)
    }
  }

  func getFetchPredicate(onlyCachedGenreAlbums: Bool) -> NSPredicate {
    if onlyCachedGenreAlbums {
      return NSPredicate(
        format: "SUBQUERY(albums, $album, ANY $album.songs.relFilePath != nil) .@count > 0"
      )
    } else {
      return NSPredicate(value: true)
    }
  }

  func getFetchPredicate(onlyCachedGenreSongs: Bool) -> NSPredicate {
    if onlyCachedGenreSongs {
      return NSPredicate(format: "SUBQUERY(songs, $song, $song.relFilePath != nil) .@count > 0")
    } else {
      return NSPredicate(value: true)
    }
  }

  func getFetchPredicate(songsDisplayFilter: DisplayCategoryFilter) -> NSPredicate {
    switch songsDisplayFilter {
    case .all, .newest, .recent:
      return NSPredicate(value: true)
    case .favorites:
      return NSPredicate(format: "%K == TRUE", #keyPath(SongMO.isFavorite))
    }
  }

  func getFetchPredicate(albumsDisplayFilter: DisplayCategoryFilter) -> NSPredicate {
    switch albumsDisplayFilter {
    case .all:
      return NSPredicate(value: true)
    case .newest:
      return NSPredicate(format: "%K > 0", #keyPath(AlbumMO.newestIndex))
    case .recent:
      return NSPredicate(format: "%K > 0", #keyPath(AlbumMO.recentIndex))
    case .favorites:
      return NSPredicate(format: "%K == TRUE", #keyPath(AlbumMO.isFavorite))
    }
  }

  func getFetchPredicate(artistsDisplayFilter: ArtistCategoryFilter) -> NSPredicate {
    switch artistsDisplayFilter {
    case .all:
      return NSPredicate(value: true)
    case .albumArtists:
      return NSPredicate(format: "%K.@count > 0", #keyPath(ArtistMO.albums))
    case .favorites:
      return NSPredicate(format: "%K == TRUE", #keyPath(ArtistMO.isFavorite))
    }
  }

  func getFetchPredicate(forPlaylistSearchCategory playlistSearchCategory: PlaylistSearchCategory)
    -> NSPredicate {
    switch playlistSearchCategory {
    case .all:
      return NSPredicate(value: true)
    case .cached:
      return NSPredicate(
        format: "SUBQUERY(items, $item, $item.playable.relFilePath != nil) .@count > 0"
      )
    case .userOnly:
      return NSPredicate(
        format: "NOT (%K BEGINSWITH %@)",
        #keyPath(PlaylistMO.id),
        Playlist.smartPlaylistIdPrefix
      )
    case .smartOnly:
      return NSPredicate(
        format: "%K BEGINSWITH %@",
        #keyPath(PlaylistMO.id),
        Playlist.smartPlaylistIdPrefix
      )
    }
  }

  // MARK: AbstractLibraryEntity

  public func getAllAbstractLibraryEntities() -> [AbstractLibraryEntity] {
    let fetchRequest = AbstractLibraryEntityMO.fetchRequest()
    let foundEntities = try? context.fetch(fetchRequest)
    let entities = foundEntities?.compactMap { AbstractLibraryEntity(managedObject: $0) }
    return entities ?? [AbstractLibraryEntity]()
  }

  // MARK: Genres

  public func getAllGenres() -> [Genre] {
    getGenres(account: nil, isFaultsOptimized: true)
  }

  public func getGenres(for account: Account) -> [Genre] {
    getGenres(account: account, isFaultsOptimized: false)
  }

  private func getGenres(account: Account?, isFaultsOptimized: Bool) -> [Genre] {
    let fetchRequest = GenreMO.identifierSortedFetchRequest
    if let account {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
      ])
    }
    if isFaultsOptimized {
      fetchRequest.relationshipKeyPathsForPrefetching = GenreMO.relationshipKeyPathsForPrefetching
      fetchRequest.returnsObjectsAsFaults = false
    }
    let foundGenres = try? context.fetch(fetchRequest)
    let genres = foundGenres?.compactMap { Genre(managedObject: $0) }
    return genres ?? [Genre]()
  }

  public func getRandomGenres(for account: Account, count: Int) -> [Genre] {
    let fetchRequest = GenreMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
    ])
    let foundGenres = try? context.fetch(fetchRequest)
    let genres = foundGenres?[randomPick: count].compactMap { Genre(managedObject: $0) }
    return genres ?? [Genre]()
  }

  public func getGenre(for account: Account, id: String) -> Genre? {
    let fetchRequest: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(GenreMO.id),
        NSString(string: id)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let genres = try? context.fetch(fetchRequest)
    return genres?.lazy.compactMap { Genre(managedObject: $0) }.first
  }

  public func getGenre(for account: Account, name: String) -> Genre? {
    let fetchRequest: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(GenreMO.name),
        NSString(string: name)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let genres = try? context.fetch(fetchRequest)
    return genres?.lazy.compactMap { Genre(managedObject: $0) }.first
  }

  // MARK: Artists

  public func getAllArtists() -> [Artist] {
    getArtists(account: nil, isFaultsOptimized: true)
  }

  public func getArtists(for account: Account) -> [Artist] {
    getArtists(account: account, isFaultsOptimized: false)
  }

  private func getArtists(account: Account?, isFaultsOptimized: Bool) -> [Artist] {
    let fetchRequest = ArtistMO.identifierSortedFetchRequest
    if let account {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
      ])
    }
    if isFaultsOptimized {
      fetchRequest.relationshipKeyPathsForPrefetching = ArtistMO.relationshipKeyPathsForPrefetching
      fetchRequest.returnsObjectsAsFaults = false
    }
    let foundArtists = try? context.fetch(fetchRequest)
    let artists = foundArtists?.compactMap { Artist(managedObject: $0) }
    return artists ?? [Artist]()
  }

  public func getRandomArtists(for account: Account, count: Int, onlyCached: Bool) -> [Artist] {
    let fetchRequest = ArtistMO.identifierSortedFetchRequest
    if onlyCached {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
        getFetchPredicate(onlyCachedArtists: true),
      ])
    } else {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
        NSCompoundPredicate(orPredicateWithSubpredicates: [
          AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
          getFetchPredicate(onlyCachedArtists: true),
        ]),
      ])
    }
    let foundArtists = try? context.fetch(fetchRequest)
    let artists = foundArtists?[randomPick: count].compactMap { Artist(managedObject: $0) }
    return artists ?? [Artist]()
  }

  public func getFavoriteArtists(for account: Account) -> [Artist] {
    let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(format: "%K == TRUE", #keyPath(ArtistMO.isFavorite)),
    ])
    let foundArtists = try? context.fetch(fetchRequest)
    let artists = foundArtists?.compactMap { Artist(managedObject: $0) }
    return artists ?? [Artist]()
  }

  public func getAlbumArtists(for account: Account) -> [Artist] {
    let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      getFetchPredicate(artistsDisplayFilter: .albumArtists),
    ])
    let foundArtists = try? context.fetch(fetchRequest)
    let artists = foundArtists?.compactMap { Artist(managedObject: $0) }
    return artists ?? [Artist]()
  }

  public func getArtist(for account: Account, id: String) -> Artist? {
    let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(ArtistMO.id),
        NSString(string: id)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let artists = try? context.fetch(fetchRequest)
    return artists?.lazy.compactMap { Artist(managedObject: $0) }.first
  }

  public func getArtistLocal(for account: Account, name: String) -> Artist? {
    let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(format: "%K == %@", #keyPath(ArtistMO.id), ""),
      NSPredicate(format: "%K == %@", #keyPath(ArtistMO.name), NSString(string: name)),
    ])
    fetchRequest.fetchLimit = 1
    let artists = try? context.fetch(fetchRequest)
    return artists?.lazy.compactMap { Artist(managedObject: $0) }.first
  }

  // MARK: Albums

  public func getAllAlbums() -> [Album] {
    getAlbums(account: nil, isFaultsOptimized: true)
  }

  public func getAlbums(for account: Account) -> [Album] {
    getAlbums(account: account, isFaultsOptimized: false)
  }

  private func getAlbums(account: Account?, isFaultsOptimized: Bool) -> [Album] {
    let fetchRequest = AlbumMO.identifierSortedFetchRequest
    if let account {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
      ])
    }
    if isFaultsOptimized {
      fetchRequest.relationshipKeyPathsForPrefetching = AlbumMO.relationshipKeyPathsForPrefetching
      fetchRequest.returnsObjectsAsFaults = false
    }
    let foundAlbums = try? context.fetch(fetchRequest)
    let albums = foundAlbums?.compactMap { Album(managedObject: $0) }
    return albums ?? [Album]()
  }

  public func getNewestAlbums(for account: Account, offset: Int = 0, count: Int = 50) -> [Album] {
    let fetchRequest = AlbumMO.newestSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      getFetchPredicate(albumsDisplayFilter: .newest),
    ])
    fetchRequest.fetchOffset = offset
    fetchRequest.fetchLimit = count
    let foundAlbums = try? context.fetch(fetchRequest)
    let albums = foundAlbums?.compactMap { Album(managedObject: $0) }
    return albums ?? [Album]()
  }

  public func getRecentAlbums(for account: Account, offset: Int = 0, count: Int = 50) -> [Album] {
    let fetchRequest = AlbumMO.recentSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      getFetchPredicate(albumsDisplayFilter: .recent),
    ])
    fetchRequest.fetchOffset = offset
    fetchRequest.fetchLimit = count
    let foundAlbums = try? context.fetch(fetchRequest)
    let albums = foundAlbums?.compactMap { Album(managedObject: $0) }
    return albums ?? [Album]()
  }

  public func getRandomAlbums(for account: Account, count: Int, onlyCached: Bool) -> [Album] {
    let fetchRequest = AlbumMO.identifierSortedFetchRequest
    if onlyCached {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
        getFetchPredicate(onlyCachedAlbums: true),
      ])
    } else {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
        NSCompoundPredicate(orPredicateWithSubpredicates: [
          AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
          getFetchPredicate(onlyCachedAlbums: true),
        ]),
      ])
    }
    let foundAlbums = try? context.fetch(fetchRequest)
    let albums = foundAlbums?[randomPick: count].compactMap { Album(managedObject: $0) }
    return albums ?? [Album]()
  }

  public func getFavoriteAlbums(for account: Account) -> [Album] {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(format: "%K == TRUE", #keyPath(AlbumMO.isFavorite)),
    ])
    let foundAlbums = try? context.fetch(fetchRequest)
    let albums = foundAlbums?.compactMap { Album(managedObject: $0) }
    return albums ?? [Album]()
  }

  public func getAlbums(
    for account: Account,
    whichContainsSongsWithArtist artist: Artist,
    onlyCached: Bool = false
  )
    -> [Album] {
    let fetchRequest = AlbumMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      getFetchPredicate(onlyCachedAlbums: onlyCached),
      NSCompoundPredicate(orPredicateWithSubpredicates: [
        getFetchPredicate(forArtist: artist),
        AlbumMO.getFetchPredicateForAlbumsWhoseSongsHave(artist: artist),
      ]),
    ])
    let foundAlbums = try? context.fetch(fetchRequest)
    let albums = foundAlbums?.compactMap { Album(managedObject: $0) }
    return albums ?? [Album]()
  }

  public func getAlbum(for account: Account, id: String, isDetailFaultResolution: Bool) -> Album? {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(AlbumMO.id),
        NSString(string: id)
      ),
    ])
    fetchRequest.fetchLimit = 1
    if isDetailFaultResolution {
      fetchRequest.relationshipKeyPathsForPrefetching = AlbumMO
        .relationshipKeyPathsForPrefetchingDetailed
    } else {
      fetchRequest.relationshipKeyPathsForPrefetching = AlbumMO.relationshipKeyPathsForPrefetching
    }
    fetchRequest.returnsObjectsAsFaults = false
    let albums = try? context.fetch(fetchRequest)
    return albums?.lazy.compactMap { Album(managedObject: $0) }.first
  }

  func getAlbumWithoutSyncedSongs() -> [Album] {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      NSPredicate(format: "%K == FALSE", #keyPath(AlbumMO.isSongsMetaDataSynced)),
      NSPredicate(
        format: "%K == %i",
        #keyPath(AlbumMO.remoteStatus),
        RemoteStatus.available.rawValue
      ),
    ])
    let albums = try? context.fetch(fetchRequest)
    return albums?.lazy.compactMap { Album(managedObject: $0) } ?? [Album]()
  }

  // MARK: Podcasts

  public func getAllPodcasts() -> [Podcast] {
    getPodcasts(account: nil, isFaultsOptimized: true)
  }

  public func getPodcasts(for account: Account) -> [Podcast] {
    getPodcasts(account: account, isFaultsOptimized: false)
  }

  private func getPodcasts(account: Account?, isFaultsOptimized: Bool) -> [Podcast] {
    let fetchRequest = PodcastMO.identifierSortedFetchRequest
    if let account {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
      ])
    }
    if isFaultsOptimized {
      fetchRequest.relationshipKeyPathsForPrefetching = PodcastMO.relationshipKeyPathsForPrefetching
      fetchRequest.returnsObjectsAsFaults = false
    }
    let foundPodcasts = try? context.fetch(fetchRequest)
    let podcasts = foundPodcasts?.compactMap { Podcast(managedObject: $0) }
    return podcasts ?? [Podcast]()
  }

  public func getNewestPodcastEpisode(for account: Account, count: Int) -> [PodcastEpisode] {
    let fetchRequest = PodcastEpisodeMO.publishedDateSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      getFetchPredicateForUserAvailableEpisodes(),
    ])
    fetchRequest.fetchLimit = count
    let foundPodcastEpisodes = try? context.fetch(fetchRequest)
    let podcastEpisodes = foundPodcastEpisodes?.compactMap { PodcastEpisode(managedObject: $0) }
    return podcastEpisodes ?? [PodcastEpisode]()
  }

  public func getRemoteAvailablePodcasts(for account: Account) -> [Podcast] {
    let fetchRequest = PodcastMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSCompoundPredicate(orPredicateWithSubpredicates: [
        AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
        getFetchPredicate(onlyCachedPodcasts: true),
      ]),
    ])
    let foundPodcasts = try? context.fetch(fetchRequest)
    let podcasts = foundPodcasts?.compactMap { Podcast(managedObject: $0) }
    return podcasts ?? [Podcast]()
  }

  public func getPodcast(for account: Account, id: String) -> Podcast? {
    let fetchRequest: NSFetchRequest<PodcastMO> = PodcastMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(PodcastMO.id),
        NSString(string: id)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let podcasts = try? context.fetch(fetchRequest)
    return podcasts?.lazy.compactMap { Podcast(managedObject: $0) }.first
  }

  // MARK: PodcastEpisodes

  public func getAllPodcastEpisodes() -> [PodcastEpisode] {
    getPodcastEpisodes(account: nil)
  }

  public func getPodcastEpisodes(for account: Account) -> [PodcastEpisode] {
    getPodcastEpisodes(account: account)
  }

  private func getPodcastEpisodes(account: Account?) -> [PodcastEpisode] {
    let fetchRequest = PodcastEpisodeMO.identifierSortedFetchRequest
    if let account {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
      ])
    }
    let foundPodcastEpisodes = try? context.fetch(fetchRequest)
    let podcastEpisodes = foundPodcastEpisodes?.compactMap { PodcastEpisode(managedObject: $0) }
    return podcastEpisodes ?? [PodcastEpisode]()
  }

  public func getCachedPodcastEpisodes(for account: Account) -> [PodcastEpisode] {
    let fetchRequest = PodcastEpisodeMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      getFetchPredicate(onlyCachedPodcastEpisodes: true),
    ])
    let foundPodcastEpisodes = try? context.fetch(fetchRequest)
    let podcastEpisodes = foundPodcastEpisodes?.compactMap { PodcastEpisode(managedObject: $0) }
    return podcastEpisodes ?? [PodcastEpisode]()
  }

  public func getPodcastEpisode(for account: Account, id: String) -> PodcastEpisode? {
    let fetchRequest: NSFetchRequest<PodcastEpisodeMO> = PodcastEpisodeMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(PodcastEpisodeMO.id),
        NSString(string: id)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let podcastEpisodes = try? context.fetch(fetchRequest)
    return podcastEpisodes?.lazy.compactMap { PodcastEpisode(managedObject: $0) }.first
  }

  // MARK: Songs

  public func getAllSongs() -> [Song] {
    getSongs(account: nil)
  }

  public func getSongs(for account: Account) -> [Song] {
    getSongs(account: account)
  }

  private func getSongs(account: Account?) -> [Song] {
    let fetchRequest = SongMO.identifierSortedFetchRequest
    if let account {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
      ])
    }
    let foundSongs = try? context.fetch(fetchRequest)
    let songs = foundSongs?.compactMap { Song(managedObject: $0) }
    return songs ?? [Song]()
  }

  public func getSongs(
    for account: Account,
    whichContainsSongsWithArtist artist: Artist,
    onlyCached: Bool = false
  )
    -> [Song] {
    let fetchRequest = SongMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
      getFetchPredicate(onlyCachedSongs: onlyCached),
      NSCompoundPredicate(orPredicateWithSubpredicates: [
        getFetchPredicate(forArtist: artist),
        getFetchPredicate(forSongsOfArtistWithCommonAlbum: artist),
      ]),
    ])
    let foundSongs = try? context.fetch(fetchRequest)
    let songs = foundSongs?.compactMap { Song(managedObject: $0) }
    return songs ?? [Song]()
  }

  public func getCachedSongs(for account: Account) -> [Song] {
    let fetchRequest = SongMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
      getFetchPredicate(onlyCachedSongs: true),
    ])
    let foundSongs = try? context.fetch(fetchRequest)
    let songs = foundSongs?.compactMap { Song(managedObject: $0) }
    return songs ?? [Song]()
  }

  public func getRandomSongs(for account: Account, count: Int = 100, onlyCached: Bool) -> [Song] {
    let fetchRequest = SongMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
      getFetchPredicate(onlyCachedSongs: onlyCached),
    ])
    let foundSongs = try? context.fetch(fetchRequest)
    let songs = foundSongs?[randomPick: count].compactMap { Song(managedObject: $0) }
    return songs ?? [Song]()
  }

  public func getFavoriteSongs(for account: Account) -> [Song] {
    let fetchRequest = SongMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
      NSPredicate(format: "%K == TRUE", #keyPath(SongMO.isFavorite)),
    ])
    let foundSongs = try? context.fetch(fetchRequest)
    let songs = foundSongs?.compactMap { Song(managedObject: $0) }
    return songs ?? [Song]()
  }

  public func getSongsForCompleteLibraryDownload(for account: Account) -> [Song] {
    let fetchRequest = SongMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
      NSPredicate(format: "%K == nil", #keyPath(SongMO.relFilePath)),
      NSPredicate(format: "%K == nil", #keyPath(SongMO.download)),
    ])
    let foundSongs = try? context.fetch(fetchRequest)
    let songs = foundSongs?.compactMap { Song(managedObject: $0) }
    return songs ?? [Song]()
  }

  public func getSong(for account: Account, id: String) -> Song? {
    let fetchRequest: NSFetchRequest<SongMO> = SongMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(SongMO.id),
        NSString(string: id)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let songs = try? context.fetch(fetchRequest)
    return songs?.lazy.compactMap { Song(managedObject: $0) }.first
  }

  // MARK: Radios

  public func getRadios(for account: Account) -> [Radio] {
    let fetchRequest = RadioMO.identifierSortedFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      RadioMO.excludeServerDeleteRadiosFetchPredicate,
    ])
    let foundRadios = try? context.fetch(fetchRequest)
    let radios = foundRadios?.compactMap { Radio(managedObject: $0) }
    return radios ?? [Radio]()
  }

  public func getRadio(for account: Account, id: String) -> Radio? {
    let fetchRequest: NSFetchRequest<RadioMO> = RadioMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(RadioMO.id),
        NSString(string: id)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let radios = try? context.fetch(fetchRequest)
    return radios?.lazy.compactMap { Radio(managedObject: $0) }.first
  }

  // MARK: SearchHistory

  public func getAllSearchHistory() -> [SearchHistoryItem] {
    let fetchRequest = SearchHistoryItemMO.fetchRequest()
    let foundHistory = try? context.fetch(fetchRequest)
    let history = foundHistory?.compactMap { SearchHistoryItem(managedObject: $0) }
    return history ?? [SearchHistoryItem]()
  }

  public func getSearchHistory(for account: Account) -> [SearchHistoryItem] {
    let fetchRequest = SearchHistoryItemMO.searchDateFetchRequest
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      SearchHistoryItemMO.excludeEmptyItemsFetchPredicate,
    ])
    let foundHistory = try? context.fetch(fetchRequest)
    let history = foundHistory?.compactMap { SearchHistoryItem(managedObject: $0) }
    return history ?? [SearchHistoryItem]()
  }

  // MARK: ScrobbleEntries

  public func getAllScrobbleEntries() -> [ScrobbleEntry] {
    getScrobbleEntries(account: nil)
  }

  public func getScrobbleEntries(for account: Account) -> [ScrobbleEntry] {
    getScrobbleEntries(account: account)
  }

  private func getScrobbleEntries(account: Account?) -> [ScrobbleEntry] {
    let fetchRequest = ScrobbleEntryMO.fetchRequest()
    if let account {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
      ])
    }
    let entries = try? context.fetch(fetchRequest)
    return entries?.compactMap { ScrobbleEntry(managedObject: $0) } ?? [ScrobbleEntry]()
  }

  public func getFirstUploadableScrobbleEntry(for account: Account) -> ScrobbleEntry? {
    let fetchRequest = ScrobbleEntryMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: #keyPath(ScrobbleEntryMO.date), ascending: true), // oldest first
    ]
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == FALSE",
        #keyPath(ScrobbleEntryMO.isUploaded)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let entries = try? context.fetch(fetchRequest)
    return entries?.lazy.compactMap { ScrobbleEntry(managedObject: $0) }.first
  }

  // MARK: Playlists

  public func getAllPlaylists(
    isFaultsOptimized: Bool = false,
    areSystemPlaylistsIncluded: Bool
  )
    -> [Playlist] {
    getPlaylists(
      account: nil,
      isFaultsOptimized: true,
      areSystemPlaylistsIncluded: areSystemPlaylistsIncluded
    )
  }

  public func getPlaylists(
    for account: Account,
    areSystemPlaylistsIncluded: Bool = false
  )
    -> [Playlist] {
    getPlaylists(
      account: account,
      isFaultsOptimized: false,
      areSystemPlaylistsIncluded: areSystemPlaylistsIncluded
    )
  }

  private func getPlaylists(
    account: Account?,
    isFaultsOptimized: Bool = false,
    areSystemPlaylistsIncluded: Bool = false
  )
    -> [Playlist] {
    let fetchRequest = PlaylistMO.identifierSortedFetchRequest
    var predicates = [NSPredicate]()
    if let account {
      predicates.append(getFetchPredicate(forAccount: account))
    }
    if !areSystemPlaylistsIncluded {
      predicates.append(PlaylistMO.excludeSystemPlaylistsFetchPredicate)
    }
    if !predicates.isEmpty {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    if isFaultsOptimized {
      fetchRequest.relationshipKeyPathsForPrefetching = PlaylistMO
        .relationshipKeyPathsForPrefetching
      fetchRequest.returnsObjectsAsFaults = false
    }
    let foundPlaylists = try? context.fetch(fetchRequest)
    let playlists = foundPlaylists?.compactMap { Playlist(library: self, managedObject: $0) }
    return playlists ?? [Playlist]()
  }

  public func getAllPlaylistItems() -> [PlaylistItemMO] {
    let fetchRequest = PlaylistItemMO.fetchRequest()
    let foundPlaylistItems = try? context.fetch(fetchRequest)
    return foundPlaylistItems ?? [PlaylistItemMO]()
  }

  public func getPlaylistItems(playlist: Playlist) -> [PlaylistItemMO] {
    let fetchRequest = PlaylistItemMO.playlistOrderSortedFetchRequest
    fetchRequest.predicate = getFetchPredicate(forPlaylist: playlist)
    let foundPlaylistItems = try? context.fetch(fetchRequest)
    return foundPlaylistItems ?? [PlaylistItemMO]()
  }

  public func getAllPlaylistItemOrphans() -> [PlaylistItem] {
    let fetchRequest = PlaylistItemMO.playlistOrderSortedFetchRequest
    fetchRequest.predicate = getFetchPredicateForOrphanedPlaylistItems()
    let foundPlaylistItems = try? context.fetch(fetchRequest)
    let items = foundPlaylistItems?.compactMap { PlaylistItem(library: self, managedObject: $0) }
    return items ?? [PlaylistItem]()
  }

  public func getPlaylist(for account: Account, id: String) -> Playlist? {
    let fetchRequest: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(PlaylistMO.id),
        NSString(string: id)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let playlists = try? context.fetch(fetchRequest)
    return playlists?.lazy.compactMap { Playlist(library: self, managedObject: $0) }.first
  }

  func getPlaylist(viaPlaylistFromOtherContext: Playlist) -> Playlist? {
    guard let foundManagedPlaylist = context
      .object(with: viaPlaylistFromOtherContext.managedObject.objectID) as? PlaylistMO
    else { return nil }
    return Playlist(library: self, managedObject: foundManagedPlaylist)
  }

  // MARK: MusicFolders

  public func getAllMusicFolders(isFaultsOptimized: Bool = false) -> [MusicFolder] {
    getMusicFolders(account: nil, isFaultsOptimized: isFaultsOptimized)
  }

  public func getMusicFolders(
    for account: Account,
    isFaultsOptimized: Bool = false
  )
    -> [MusicFolder] {
    getMusicFolders(account: account, isFaultsOptimized: isFaultsOptimized)
  }

  private func getMusicFolders(
    account: Account?,
    isFaultsOptimized: Bool = false
  )
    -> [MusicFolder] {
    let fetchRequest: NSFetchRequest<MusicFolderMO> = MusicFolderMO.fetchRequest()
    if let account {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
      ])
    }
    if isFaultsOptimized {
      fetchRequest.relationshipKeyPathsForPrefetching = MusicFolderMO
        .relationshipKeyPathsForPrefetching
      fetchRequest.returnsObjectsAsFaults = false
    }
    let foundMusicFolders = try? context.fetch(fetchRequest)
    let musicFolders = foundMusicFolders?.compactMap { MusicFolder(managedObject: $0) }
    return musicFolders ?? [MusicFolder]()
  }

  public func getMusicFolder(for account: Account, id: String) -> MusicFolder? {
    let fetchRequest: NSFetchRequest<MusicFolderMO> = MusicFolderMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(MusicFolderMO.id),
        NSString(string: id)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let musicFolders = try? context.fetch(fetchRequest)
    return musicFolders?.lazy.compactMap { MusicFolder(managedObject: $0) }.first
  }

  // MARK: Directories

  func getAllDirectories(isFaultsOptimized: Bool = false) -> [Directory] {
    let fetchRequest: NSFetchRequest<DirectoryMO> = DirectoryMO.fetchRequest()
    if isFaultsOptimized {
      fetchRequest.relationshipKeyPathsForPrefetching = DirectoryMO
        .relationshipKeyPathsForPrefetching
      fetchRequest.returnsObjectsAsFaults = false
    }
    let directories = try? context.fetch(fetchRequest)
    return directories?.lazy.compactMap { Directory(managedObject: $0) } ?? [Directory]()
  }

  func getDirectory(for account: Account, id: String) -> Directory? {
    let fetchRequest: NSFetchRequest<DirectoryMO> = DirectoryMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K == %@",
        #keyPath(DirectoryMO.id),
        NSString(string: id)
      ),
    ])
    fetchRequest.fetchLimit = 1
    let directories = try? context.fetch(fetchRequest)
    return directories?.lazy.compactMap { Directory(managedObject: $0) }.first
  }

  // MARK: Artworks

  public func getAllArtworks() -> [Artwork] {
    getArtworks(account: nil)
  }

  public func getArtworks(for account: Account) -> [Artwork] {
    getArtworks(account: account)
  }

  private func getArtworks(account: Account?) -> [Artwork] {
    let fetchRequest = ArtworkMO.fetchRequest()
    if let account {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
      ])
    }
    let founds = try? context.fetch(fetchRequest)
    let artworks = founds?.compactMap { Artwork(managedObject: $0) }
    return artworks ?? [Artwork]()
  }

  public func getArtwork(for account: Account, remoteInfo: ArtworkRemoteInfo) -> Artwork? {
    let fetchRequest = ArtworkMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(format: "%K == %@", #keyPath(ArtworkMO.id), NSString(string: remoteInfo.id)),
      NSPredicate(format: "%K == %@", #keyPath(ArtworkMO.type), NSString(string: remoteInfo.type)),
    ])
    fetchRequest.fetchLimit = 1
    let artworks = try? context.fetch(fetchRequest)
    return artworks?.lazy.compactMap { Artwork(managedObject: $0) }.first
  }

  public func getArtworksForCompleteLibraryDownload(for account: Account) -> [Artwork] {
    let fetchRequest = ArtworkMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(format: "%K == nil", #keyPath(ArtworkMO.relFilePath)),
      NSCompoundPredicate(orPredicateWithSubpredicates: [
        NSPredicate(format: "%K == nil", #keyPath(ArtworkMO.download)),
        NSPredicate(format: "%K != nil", #keyPath(ArtworkMO.download.errorDate)),
      ]),
      NSCompoundPredicate(orPredicateWithSubpredicates: [
        NSPredicate(
          format: "%K == %@",
          #keyPath(ArtworkMO.status),
          NSNumber(integerLiteral: Int(ImageStatus.NotChecked.rawValue))
        ),
        NSPredicate(
          format: "%K == %@",
          #keyPath(ArtworkMO.status),
          NSNumber(integerLiteral: Int(ImageStatus.FetchError.rawValue))
        ),
      ]),
    ])

    let foundArtworks = try? context.fetch(fetchRequest)
    let artworks = foundArtworks?.compactMap { Artwork(managedObject: $0) }
    return artworks ?? [Artwork]()
  }

  // MARK: EmbeddedArtworks

  public func getAllEmbeddedArtworks() -> [EmbeddedArtwork] {
    getEmbeddedArtworks(account: nil)
  }

  public func getEmbeddedArtworks(for account: Account) -> [EmbeddedArtwork] {
    getEmbeddedArtworks(account: account)
  }

  private func getEmbeddedArtworks(account: Account?) -> [EmbeddedArtwork] {
    let fetchRequest = EmbeddedArtworkMO.fetchRequest()
    if let account {
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        getFetchPredicate(forAccount: account),
      ])
    }
    let embeddedArtworks = try? context.fetch(fetchRequest)
    return embeddedArtworks?
      .compactMap { EmbeddedArtwork(managedObject: $0) } ?? [EmbeddedArtwork]()
  }

  public func getEmbeddedArtwork(forOwner playable: AbstractPlayable) -> EmbeddedArtwork? {
    let fetchRequest: NSFetchRequest<EmbeddedArtworkMO> = EmbeddedArtworkMO.fetchRequest()
    fetchRequest.predicate = NSPredicate(
      format: "%K == %@",
      #keyPath(EmbeddedArtworkMO.owner.id),
      NSString(string: playable.id)
    )
    fetchRequest.fetchLimit = 1
    let embeddedArtworks = try? context.fetch(fetchRequest)
    return embeddedArtworks?.lazy.compactMap { EmbeddedArtwork(managedObject: $0) }.first
  }

  // MARK: LogEntries

  public func getAllLogEntries() -> [LogEntry] {
    let fetchRequest: NSFetchRequest<LogEntryMO> = LogEntryMO.creationDateSortedFetchRequest
    let foundEntries = try? context.fetch(fetchRequest)
    let entries = foundEntries?.compactMap { LogEntry(managedObject: $0) }
    return entries ?? [LogEntry]()
  }

  // MARK: PlayerData

  func getPlayerData() -> PlayerData {
    let fetchRequest = PlayerMO.fetchRequest()
    fetchRequest.relationshipKeyPathsForPrefetching = PlayerMO.relationshipKeyPathsForPrefetching
    fetchRequest.returnsObjectsAsFaults = false
    var playerData: PlayerData
    var playerMO: PlayerMO

    if let fetchResults: [PlayerMO] = try? context.fetch(fetchRequest) {
      if fetchResults.count == 1 {
        playerMO = fetchResults[0]
      } else if fetchResults.isEmpty {
        playerMO = PlayerMO(context: context)
        saveContext()
      } else {
        clearStorage(ofType: PlayerData.entityName)
        playerMO = PlayerMO(context: context)
        saveContext()
      }
    } else {
      playerMO = PlayerMO(context: context)
      saveContext()
    }

    if playerMO.userQueuePlaylist == nil {
      playerMO.userQueuePlaylist = PlaylistMO(context: context)
      saveContext()
    }
    if playerMO.contextPlaylist == nil {
      playerMO.contextPlaylist = PlaylistMO(context: context)
      saveContext()
    }
    if playerMO.shuffledContextPlaylist == nil {
      playerMO.shuffledContextPlaylist = PlaylistMO(context: context)
      saveContext()
    }
    if playerMO.podcastPlaylist == nil {
      playerMO.podcastPlaylist = PlaylistMO(context: context)
      saveContext()
    }

    let userQueuePlaylist = Playlist(library: self, managedObject: playerMO.userQueuePlaylist!)
    let contextPlaylist = Playlist(library: self, managedObject: playerMO.contextPlaylist!)
    let shuffledContextPlaylist = Playlist(
      library: self,
      managedObject: playerMO.shuffledContextPlaylist!
    )
    let podcastPlaylist = Playlist(library: self, managedObject: playerMO.podcastPlaylist!)

    if shuffledContextPlaylist.managedObject.items.count != contextPlaylist.managedObject.items
      .count {
      shuffledContextPlaylist.removeAllItems()
      shuffledContextPlaylist.append(playables: contextPlaylist.playables)
      shuffledContextPlaylist.shuffle()
    }

    playerData = PlayerData(
      library: self,
      managedObject: playerMO,
      userQueue: userQueuePlaylist,
      contextQueue: contextPlaylist,
      shuffledContextQueue: shuffledContextPlaylist,
      podcastQueue: podcastPlaylist
    )

    return playerData
  }

  // MARK: UserStatistics

  func getUserStatistics(appVersion: String) -> UserStatistics {
    let fetchRequest: NSFetchRequest<UserStatisticsMO> = UserStatisticsMO.fetchRequest()
    fetchRequest.predicate = NSPredicate(
      format: "%K == %@",
      #keyPath(UserStatisticsMO.appVersion),
      appVersion
    )
    fetchRequest.fetchLimit = 1
    if let foundUserStatistics = try? context.fetch(fetchRequest).first {
      return UserStatistics(managedObject: foundUserStatistics, library: self)
    } else {
      os_log("New UserStatistics for app version %s created", log: log, type: .info, appVersion)
      let createdUserStatistics = createUserStatistics(appVersion: appVersion)
      saveContext()
      return createdUserStatistics
    }
  }

  func getAllUserStatistics() -> [UserStatistics] {
    let fetchRequest: NSFetchRequest<UserStatisticsMO> = UserStatisticsMO.fetchRequest()
    let foundUserStatistics = try? context.fetch(fetchRequest)
    let userStatistics = foundUserStatistics?.compactMap { UserStatistics(
      managedObject: $0,
      library: self
    ) }
    return userStatistics ?? [UserStatistics]()
  }

  // MARK: Search Predicates

  public func getSearchArtistsPredicate(
    for account: Account,
    searchText: String,
    onlyCached: Bool,
    displayFilter: ArtistCategoryFilter
  )
    -> NSPredicate {
    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSCompoundPredicate(orPredicateWithSubpredicates: [
        AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
        getFetchPredicate(onlyCachedArtists: true),
      ]),
      ArtistMO.getIdentifierBasedSearchPredicate(searchText: searchText),
      getFetchPredicate(onlyCachedArtists: onlyCached),
      getFetchPredicate(artistsDisplayFilter: displayFilter),
    ])
    return predicate
  }

  public func searchArtists(
    for account: Account,
    searchText: String,
    onlyCached: Bool,
    displayFilter: ArtistCategoryFilter
  )
    -> [Artist] {
    let fetchRequest = ArtistMO.identifierSortedFetchRequest
    fetchRequest.predicate = getSearchArtistsPredicate(
      for: account,
      searchText: searchText,
      onlyCached: onlyCached,
      displayFilter: displayFilter
    )
    let found = try? context.fetch(fetchRequest)
    let wrapped = found?.compactMap { Artist(managedObject: $0) }
    return wrapped ?? [Artist]()
  }

  public func getSearchAlbumsPredicate(
    for account: Account,
    searchText: String,
    onlyCached: Bool,
    displayFilter: DisplayCategoryFilter
  )
    -> NSPredicate {
    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSCompoundPredicate(orPredicateWithSubpredicates: [
        AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
        getFetchPredicate(onlyCachedAlbums: true),
      ]),
      AlbumMO.getIdentifierBasedSearchPredicate(searchText: searchText),
      getFetchPredicate(onlyCachedAlbums: onlyCached),
      getFetchPredicate(albumsDisplayFilter: displayFilter),
    ])
    return predicate
  }

  public func searchAlbums(
    for account: Account,
    searchText: String,
    onlyCached: Bool,
    displayFilter: DisplayCategoryFilter
  )
    -> [Album] {
    let fetchRequest = AlbumMO.identifierSortedFetchRequest
    fetchRequest.predicate = getSearchAlbumsPredicate(
      for: account,
      searchText: searchText,
      onlyCached: onlyCached,
      displayFilter: displayFilter
    )
    let found = try? context.fetch(fetchRequest)
    let wrapped = found?.compactMap { Album(managedObject: $0) }
    return wrapped ?? [Album]()
  }

  public func getSearchPlaylistsPredicate(
    for account: Account,
    searchText: String,
    playlistSearchCategory: PlaylistSearchCategory
  )
    -> NSPredicate {
    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      PlaylistMO.excludeSystemPlaylistsFetchPredicate,
      PlaylistMO.getIdentifierBasedSearchPredicate(searchText: searchText),
      getFetchPredicate(forPlaylistSearchCategory: playlistSearchCategory),
    ])
    return predicate
  }

  public func searchPlaylists(
    for account: Account,
    searchText: String,
    playlistSearchCategory: PlaylistSearchCategory
  )
    -> [Playlist] {
    let fetchRequest = PlaylistMO.identifierSortedFetchRequest
    fetchRequest.predicate = getSearchPlaylistsPredicate(
      for: account,
      searchText: searchText,
      playlistSearchCategory: playlistSearchCategory
    )
    let found = try? context.fetch(fetchRequest)
    let wrapped = found?.compactMap { Playlist(library: self, managedObject: $0) }
    return wrapped ?? [Playlist]()
  }

  public func getSearchRadiosPredicate(
    for account: Account,
    searchText: String
  )
    -> NSPredicate {
    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      RadioMO.excludeServerDeleteRadiosFetchPredicate,
      RadioMO.getIdentifierBasedSearchPredicate(searchText: searchText),
    ])
    return predicate
  }

  public func getSearchSongsPredicate(
    for account: Account,
    searchText: String,
    onlyCached: Bool,
    displayFilter: DisplayCategoryFilter
  )
    -> NSPredicate {
    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
      SongMO.getIdentifierBasedSearchPredicate(searchText: searchText),
      getFetchPredicate(onlyCachedSongs: onlyCached),
      getFetchPredicate(songsDisplayFilter: displayFilter),
    ])
    return predicate
  }

  public func searchSongs(
    for account: Account,
    searchText: String,
    onlyCached: Bool,
    displayFilter: DisplayCategoryFilter
  )
    -> [Song] {
    let fetchRequest = SongMO.identifierSortedFetchRequest
    fetchRequest.predicate = getSearchSongsPredicate(
      for: account,
      searchText: searchText,
      onlyCached: onlyCached,
      displayFilter: displayFilter
    )
    let found = try? context.fetch(fetchRequest)
    let wrapped = found?.compactMap { Song(managedObject: $0) }
    return wrapped ?? [Song]()
  }

  public struct PrefetchIdContainer {
    public var artworkIDs = Set<ArtworkRemoteInfo>()
    public var genreIDs = Set<String>()
    public var genreNames = Set<String>()
    public var artistIDs = Set<String>()
    public var localArtistNames = Set<String>()
    public var albumIDs = Set<String>()
    public var songIDs = Set<String>()
    public var podcastEpisodeIDs = Set<String>()
    public var radioIDs = Set<String>()
    public var musicFolderIDs = Set<String>()
    public var directoryIDs = Set<String>()
    public var podcastIDs = Set<String>()

    public var counts: Int {
      artworkIDs.count +
        genreIDs.count +
        genreNames.count +
        artistIDs.count +
        localArtistNames.count +
        albumIDs.count +
        songIDs.count +
        podcastEpisodeIDs.count +
        radioIDs.count +
        musicFolderIDs.count +
        directoryIDs.count +
        podcastIDs.count
    }
  }

  public class PrefetchElementContainer {
    public var prefetchedArtworkDict = [ArtworkRemoteInfo: Artwork]()
    public var prefetchedGenreDict = [String: Genre]()
    public var prefetchedArtistDict = [String: Artist]()
    public var prefetchedLocalArtistDict = [String: Artist]()
    public var prefetchedAlbumDict = [String: Album]()
    public var prefetchedSongDict = [String: Song]()
    public var prefetchedPodcastEpisodeDict = [String: PodcastEpisode]()
    public var prefetchedRadioDict = [String: Radio]()
    public var prefetchedMusicFolderDict = [String: MusicFolder]()
    public var prefetchedDirectoryDict = [String: Directory]()
    public var prefetchedPodcastDict = [String: Podcast]()

    public var counts: Int {
      prefetchedArtworkDict.count +
        prefetchedGenreDict.count +
        prefetchedArtistDict.count +
        prefetchedLocalArtistDict.count +
        prefetchedAlbumDict.count +
        prefetchedSongDict.count +
        prefetchedPodcastEpisodeDict.count +
        prefetchedRadioDict.count +
        prefetchedMusicFolderDict.count +
        prefetchedDirectoryDict.count +
        prefetchedPodcastDict.count
    }
  }

  public func getElements(
    account: Account,
    prefetchIDs: PrefetchIdContainer
  )
    -> PrefetchElementContainer {
    let elementContainer = PrefetchElementContainer()

    if !prefetchIDs.artworkIDs.isEmpty {
      elementContainer.prefetchedArtworkDict = getArtworks(
        account: account,
        remoteInfos: prefetchIDs.artworkIDs
      )
    }

    if !prefetchIDs.genreIDs.isEmpty {
      elementContainer.prefetchedGenreDict = getGenresDict(
        account: account,
        ids: prefetchIDs.genreIDs
      )
    } else if !prefetchIDs.genreNames.isEmpty {
      elementContainer.prefetchedGenreDict = getGenresDict(
        account: account,
        names: prefetchIDs.genreNames
      )
    }

    if !prefetchIDs.artistIDs.isEmpty {
      elementContainer.prefetchedArtistDict = getArtistsDict(
        account: account,
        ids: prefetchIDs.artistIDs
      )
    }
    if !prefetchIDs.localArtistNames.isEmpty {
      elementContainer
        .prefetchedLocalArtistDict = getLocalArtists(
          account: account,
          names: prefetchIDs.localArtistNames
        )
    }
    if !prefetchIDs.albumIDs.isEmpty {
      elementContainer.prefetchedAlbumDict = getAlbumsDict(
        account: account,
        ids: prefetchIDs.albumIDs
      )
    }
    if !prefetchIDs.songIDs.isEmpty {
      elementContainer.prefetchedSongDict = getSongsDict(account: account, ids: prefetchIDs.songIDs)
    }
    if !prefetchIDs.podcastEpisodeIDs.isEmpty {
      elementContainer
        .prefetchedPodcastEpisodeDict = getPodcastEpisodesDict(
          account: account,
          ids: prefetchIDs.podcastEpisodeIDs
        )
    }
    if !prefetchIDs.radioIDs.isEmpty {
      elementContainer.prefetchedRadioDict = getRadiosDict(
        account: account,
        ids: prefetchIDs.radioIDs
      )
    }
    if !prefetchIDs.musicFolderIDs.isEmpty {
      elementContainer.prefetchedMusicFolderDict = getMusicFolders(
        account: account,
        ids: prefetchIDs.musicFolderIDs
      )
    }
    if !prefetchIDs.directoryIDs.isEmpty {
      elementContainer.prefetchedDirectoryDict = getDirectories(
        account: account,
        ids: prefetchIDs.directoryIDs
      )
    }
    if !prefetchIDs.podcastIDs.isEmpty {
      elementContainer.prefetchedPodcastDict = getPodcastsDict(
        account: account,
        ids: prefetchIDs.podcastIDs
      )
    }
    return elementContainer
  }

  private func getArtworks(
    account: Account,
    remoteInfos: Set<ArtworkRemoteInfo>
  )
    -> [ArtworkRemoteInfo: Artwork] {
    let allIDsDespiteOfType = remoteInfos.compactMap { $0.id }
    let fetchRequest: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(ArtworkMO.id),
        allIDsDespiteOfType
      ),
    ])
    let artworkMOs = try? context.fetch(fetchRequest)

    var artworkDict = [ArtworkRemoteInfo: Artwork]()
    guard let artworkMOs else { return artworkDict }
    for artworkMO in artworkMOs {
      let artwork = Artwork(managedObject: artworkMO)
      let remoteInfo = artwork.remoteInfo
      artworkDict[remoteInfo] = artwork
    }
    return artworkDict
  }

  private func getPodcasts(account: Account, ids: Set<String>) -> [Podcast] {
    let fetchRequest: NSFetchRequest<PodcastMO> = PodcastMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(PodcastMO.id),
        ids
      ),
    ])
    let podcastMOs = try? context.fetch(fetchRequest)
    return podcastMOs?.compactMap { Podcast(managedObject: $0) } ?? [Podcast]()
  }

  private func getPodcastsDict(account: Account, ids: Set<String>) -> [String: Podcast] {
    let podcasts = getPodcasts(account: account, ids: ids)

    var podcastDict = [String: Podcast]()
    for podcast in podcasts {
      podcastDict[podcast.id] = podcast
    }
    return podcastDict
  }

  private func getPodcastsDictList(account: Account, ids: Set<String>) -> [String: [Podcast]] {
    let podcasts = getPodcasts(account: account, ids: ids)

    var podcastDict = [String: [Podcast]]()
    for podcast in podcasts {
      if podcastDict[podcast.id] == nil {
        podcastDict[podcast.id] = [Podcast]()
      }
      podcastDict[podcast.id]!.append(podcast)
    }
    return podcastDict
  }

  private func getMusicFolders(account: Account, ids: Set<String>) -> [String: MusicFolder] {
    let fetchRequest: NSFetchRequest<MusicFolderMO> = MusicFolderMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(MusicFolderMO.id),
        ids
      ),
    ])
    let musicFolderMOs = try? context.fetch(fetchRequest)

    var musicFolderDict = [String: MusicFolder]()
    guard let musicFolderMOs else { return musicFolderDict }
    for musicFolderMO in musicFolderMOs {
      let musicFolder = MusicFolder(managedObject: musicFolderMO)
      musicFolderDict[musicFolder.id] = musicFolder
    }
    return musicFolderDict
  }

  public func getDirectories(account: Account, ids: Set<String>) -> [String: Directory] {
    let fetchRequest: NSFetchRequest<DirectoryMO> = DirectoryMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(DirectoryMO.id),
        ids
      ),
    ])
    let directoryMOs = try? context.fetch(fetchRequest)

    var directoryDict = [String: Directory]()
    guard let directoryMOs else { return directoryDict }
    for directoryMO in directoryMOs {
      let directory = Directory(managedObject: directoryMO)
      directoryDict[directory.id] = directory
    }
    return directoryDict
  }

  private func getGenres(account: Account, ids: Set<String>) -> [Genre] {
    let fetchRequest: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(GenreMO.id),
        ids
      ),
    ])
    let mos = try? context.fetch(fetchRequest)
    return mos?.compactMap { Genre(managedObject: $0) } ?? [Genre]()
  }

  private func getGenresDict(account: Account, ids: Set<String>) -> [String: Genre] {
    let genres = getGenres(account: account, ids: ids)

    var genreDict = [String: Genre]()
    for genre in genres {
      genreDict[genre.id] = genre
    }
    return genreDict
  }

  private func getGenresDictList(account: Account, ids: Set<String>) -> [String: [Genre]] {
    let genres = getGenres(account: account, ids: ids)

    var genreDict = [String: [Genre]]()
    for genre in genres {
      if genreDict[genre.id] == nil {
        genreDict[genre.id] = [Genre]()
      }
      genreDict[genre.id]!.append(genre)
    }
    return genreDict
  }

  private func getGenres(account: Account, names: Set<String>) -> [Genre] {
    let fetchRequest: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(format: "%K == %@", #keyPath(GenreMO.id), ""),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(GenreMO.name),
        names
      ),
    ])
    let mos = try? context.fetch(fetchRequest)
    return mos?.compactMap { Genre(managedObject: $0) } ?? [Genre]()
  }

  private func getGenresDict(account: Account, names: Set<String>) -> [String: Genre] {
    let genres = getGenres(account: account, names: names)

    var genreDict = [String: Genre]()
    for genre in genres {
      genreDict[genre.name] = genre
    }
    return genreDict
  }

  private func getGenresDictList(account: Account, names: Set<String>) -> [String: [Genre]] {
    let genres = getGenres(account: account, names: names)

    var genreDict = [String: [Genre]]()
    for genre in genres {
      if genreDict[genre.name] == nil {
        genreDict[genre.name] = [Genre]()
      }
      genreDict[genre.name]!.append(genre)
    }
    return genreDict
  }

  private func getArtists(account: Account, ids: Set<String>) -> [Artist] {
    let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(ArtistMO.id),
        ids
      ),
    ])
    let artistMOs = try? context.fetch(fetchRequest)
    return artistMOs?.compactMap { Artist(managedObject: $0) } ?? [Artist]()
  }

  private func getArtistsDict(account: Account, ids: Set<String>) -> [String: Artist] {
    let artists = getArtists(account: account, ids: ids)

    var artistDict = [String: Artist]()
    for artist in artists {
      artistDict[artist.id] = artist
    }
    return artistDict
  }

  private func getArtistsDictList(account: Account, ids: Set<String>) -> [String: [Artist]] {
    let artists = getArtists(account: account, ids: ids)

    var artistDict = [String: [Artist]]()
    for artist in artists {
      if artistDict[artist.id] == nil {
        artistDict[artist.id] = [Artist]()
      }
      artistDict[artist.id]!.append(artist)
    }
    return artistDict
  }

  private func getLocalArtists(account: Account, names: Set<String>) -> [String: Artist] {
    let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(format: "%K == %@", #keyPath(ArtistMO.id), ""),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(ArtistMO.name),
        names
      ),
    ])
    let artistMOs = try? context.fetch(fetchRequest)

    var artistDict = [String: Artist]()
    guard let artistMOs else { return artistDict }
    for artistMO in artistMOs {
      let artist = Artist(managedObject: artistMO)
      artistDict[artist.name] = artist
    }
    return artistDict
  }

  private func getAlbums(account: Account, ids: Set<String>) -> [Album] {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(AlbumMO.id),
        ids
      ),
    ])
    let albumMOs = try? context.fetch(fetchRequest)
    return albumMOs?.compactMap { Album(managedObject: $0) } ?? [Album]()
  }

  private func getAlbumsDict(account: Account, ids: Set<String>) -> [String: Album] {
    let albums = getAlbums(account: account, ids: ids)

    var albumDict = [String: Album]()
    for album in albums {
      albumDict[album.id] = album
    }
    return albumDict
  }

  private func getAlbumsDictList(account: Account, ids: Set<String>) -> [String: [Album]] {
    let albums = getAlbums(account: account, ids: ids)

    var albumDict = [String: [Album]]()
    for album in albums {
      if albumDict[album.id] == nil {
        albumDict[album.id] = [Album]()
      }
      albumDict[album.id]!.append(album)
    }
    return albumDict
  }

  private func getSongs(account: Account, ids: Set<String>) -> [Song] {
    let fetchRequest: NSFetchRequest<SongMO> = SongMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(SongMO.id),
        ids
      ),
    ])
    let songMOs = try? context.fetch(fetchRequest)
    return songMOs?.compactMap { Song(managedObject: $0) } ?? [Song]()
  }

  private func getSongsDict(account: Account, ids: Set<String>) -> [String: Song] {
    let songs = getSongs(account: account, ids: ids)

    var songDict = [String: Song]()
    for song in songs {
      songDict[song.id] = song
    }
    return songDict
  }

  private func getSongsDictList(account: Account, ids: Set<String>) -> [String: [Song]] {
    let songs = getSongs(account: account, ids: ids)

    var songDict = [String: [Song]]()
    for song in songs {
      if songDict[song.id] == nil {
        songDict[song.id] = [Song]()
      }
      songDict[song.id]!.append(song)
    }
    return songDict
  }

  private func getPodcastEpisodes(account: Account, ids: Set<String>) -> [PodcastEpisode] {
    let fetchRequest: NSFetchRequest<PodcastEpisodeMO> = PodcastEpisodeMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(PodcastEpisodeMO.id),
        ids
      ),
    ])
    let podcastEpisodeMOs = try? context.fetch(fetchRequest)
    return podcastEpisodeMOs?.compactMap { PodcastEpisode(managedObject: $0) } ?? [PodcastEpisode]()
  }

  private func getPodcastEpisodesDict(
    account: Account,
    ids: Set<String>
  )
    -> [String: PodcastEpisode] {
    let podcastEpisodes = getPodcastEpisodes(account: account, ids: ids)

    var podcastEpisodeDict = [String: PodcastEpisode]()
    for podcastEpisode in podcastEpisodes {
      podcastEpisodeDict[podcastEpisode.id] = podcastEpisode
    }
    return podcastEpisodeDict
  }

  private func getPodcastEpisodesDictList(
    account: Account,
    ids: Set<String>
  )
    -> [String: [PodcastEpisode]] {
    let podcastEpisodes = getPodcastEpisodes(account: account, ids: ids)

    var podcastEpisodeDict = [String: [PodcastEpisode]]()
    for podcastEpisode in podcastEpisodes {
      if podcastEpisodeDict[podcastEpisode.id] == nil {
        podcastEpisodeDict[podcastEpisode.id] = [PodcastEpisode]()
      }
      podcastEpisodeDict[podcastEpisode.id]!.append(podcastEpisode)
    }
    return podcastEpisodeDict
  }

  private func getRadios(account: Account, ids: Set<String>) -> [Radio] {
    let fetchRequest: NSFetchRequest<RadioMO> = RadioMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(RadioMO.id),
        ids
      ),
    ])
    let radioMOs = try? context.fetch(fetchRequest)
    return radioMOs?.compactMap { Radio(managedObject: $0) } ?? [Radio]()
  }

  private func getRadiosDict(account: Account, ids: Set<String>) -> [String: Radio] {
    let radios = getRadios(account: account, ids: ids)

    var radioDict = [String: Radio]()
    for radio in radios {
      radioDict[radio.id] = radio
    }
    return radioDict
  }

  private func getRadiosDictList(account: Account, ids: Set<String>) -> [String: [Radio]] {
    let radios = getRadios(account: account, ids: ids)

    var radioDict = [String: [Radio]]()
    for radio in radios {
      if radioDict[radio.id] == nil {
        radioDict[radio.id] = [Radio]()
      }
      radioDict[radio.id]!.append(radio)
    }
    return radioDict
  }

  private func getPlaylists(account: Account, ids: Set<String>) -> [Playlist] {
    let fetchRequest: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      getFetchPredicate(forAccount: account),
      NSPredicate(
        format: "%K IN %@",
        #keyPath(PlaylistMO.id),
        ids
      ),
    ])
    let playlistMOs = try? context.fetch(fetchRequest)
    return playlistMOs?.compactMap { Playlist(library: self, managedObject: $0) } ?? [Playlist]()
  }

  private func getPlaylistsDict(account: Account, ids: Set<String>) -> [String: Playlist] {
    let playlists = getPlaylists(account: account, ids: ids)

    var playlistDict = [String: Playlist]()
    for playlist in playlists {
      playlistDict[playlist.id] = playlist
    }
    return playlistDict
  }

  private func getPlaylistsDictList(account: Account, ids: Set<String>) -> [String: [Playlist]] {
    let playlists = getPlaylists(account: account, ids: ids)

    var playlistDict = [String: [Playlist]]()
    for playlist in playlists {
      if playlistDict[playlist.id] == nil {
        playlistDict[playlist.id] = [Playlist]()
      }
      playlistDict[playlist.id]!.append(playlist)
    }
    return playlistDict
  }

  func getFileURL(forPlayable playable: AbstractPlayable) -> URL? {
    var absFileURL: URL?
    if let relFilePath = playable.relFilePath {
      absFileURL = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath)
    } else {
      os_log(
        "File URL was not able to retrieve for: %s",
        log: log,
        type: .error,
        playable.displayString
      )
    }
    return absFileURL
  }

  public func cleanStorageOfObsoleteAccountEntries(account: Account) {
    // Genres
    do {
      let request: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Artists
    do {
      let request: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Albums
    do {
      let request: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Songs
    do {
      let request: NSFetchRequest<SongMO> = SongMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Artworks
    do {
      let request: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Embedded Artworks
    do {
      let request: NSFetchRequest<EmbeddedArtworkMO> = EmbeddedArtworkMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Playlists
    do {
      let request: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Playlist Items
    do {
      let request: NSFetchRequest<PlaylistItemMO> = PlaylistItemMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Music Folders
    do {
      let request: NSFetchRequest<MusicFolderMO> = MusicFolderMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Directories
    do {
      let request: NSFetchRequest<DirectoryMO> = DirectoryMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Podcasts
    do {
      let request: NSFetchRequest<PodcastMO> = PodcastMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Podcast Episodes
    do {
      let request: NSFetchRequest<PodcastEpisodeMO> = PodcastEpisodeMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Radios
    do {
      let request: NSFetchRequest<RadioMO> = RadioMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Downloads
    do {
      let request: NSFetchRequest<DownloadMO> = DownloadMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Scrobble Entries
    do {
      let request: NSFetchRequest<ScrobbleEntryMO> = ScrobbleEntryMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // Search History Items
    do {
      let request: NSFetchRequest<SearchHistoryItemMO> = SearchHistoryItemMO.fetchRequest()
      request.predicate = getFetchPredicate(forAccount: account)
      clearStorage(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }
  }

  public func cleanStorage() {
    for entityToDelete in LibraryStorage.entitiesToDelete {
      clearStorage(ofType: entityToDelete)
    }
    saveContext()
  }

  private func clearStorage(ofType entityToDelete: String) {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityToDelete)
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    do {
      try context.execute(deleteRequest)
    } catch let error as NSError {
      os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
    }
  }

  private func clearStorage(fetchRequest: NSFetchRequest<NSFetchRequestResult>) {
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    do {
      try context.execute(deleteRequest)
    } catch let error as NSError {
      os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
    }
  }

  public func saveContext() {
    if context.hasChanges {
      do {
        try context.save()
      } catch {
        // Log the error and attempt recovery instead of crashing
        let nserror = error as NSError
        os_log(
          "CoreData Save Context Error: %s",
          log: log,
          type: .error,
          nserror.localizedDescription
        )

        // Attempt to reset the context to a clean state
        context.rollback()
      }
    }
  }
}
