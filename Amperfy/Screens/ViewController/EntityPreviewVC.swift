//
//  EntityPreviewVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 12.02.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import AmperfyKit
import Foundation
import MarqueeLabel
import UIKit

typealias GetPlayContextCallback = () -> PlayContext?
typealias GetPlayerIndexCallback = () -> PlayerIndex?

// MARK: - EntityPreviewActionBuilder

@MainActor
class EntityPreviewActionBuilder {
  private var entityContainer: PlayableContainable
  private var rootView: UIViewController
  private var playContextCb: GetPlayContextCallback?
  private var playerIndexCb: GetPlayerIndexCallback?
  private var appDelegate: AppDelegate

  private var entityPlayables: [AbstractPlayable] {
    let playables = entityContainer.playables
      .filterCached(dependigOn: appDelegate.storage.settings.user.isOfflineMode)
    switch entityContainer.playContextType {
    case .music:
      return playables
        .filter { $0.asSong?.isAvailableToUser() ?? $0.asRadio?.isAvailableToUser() ?? false }
    case .podcast:
      return playables
    }
  }

  // configure states
  private var isPlay = false
  private var isShuffle = false
  private var isMusicQueue = false
  private var isPodcastQueue = false
  private var isShowAlbum = false
  private var isShowArtist = false
  private var isAddToPlaylist = false
  private var isDownloadPossible: Bool {
    !(
      entityContainer.playables.isCachedCompletely ||
        appDelegate.storage.settings.user.isOfflineMode ||
        !entityContainer.isDownloadAvailable
    )
  }

  private var isDeleteOnServer = false
  private var isGoToSiteUrl = false
  private var isShowPodcastDetails = false
  private var isShowSongDetails = false

  init(
    container: PlayableContainable,
    on rootView: UIViewController,
    playContextCb: GetPlayContextCallback? = nil,
    playerIndexCb: GetPlayerIndexCallback? = nil
  ) {
    self.appDelegate = (UIApplication.shared.delegate as! AppDelegate)
    self.entityContainer = container
    self.rootView = rootView
    self.playContextCb = playContextCb
    self.playerIndexCb = playerIndexCb
  }

  public func createMenu() -> UIMenu {
    UIMenu(children: createMenuActions())
  }

  public func createMenuActions() -> [UIMenuElement] {
    var menuActions = [UIMenuElement]()

    configureUI()

    var playActions = [UIMenuElement]()
    var gotoActions = [UIMenuElement]()
    var ratingFavActions = [UIMenuElement]()
    var elementHandlingActions = [UIMenuElement]()

    if isPlay {
      playActions.append(createPlayAction())
    }
    if isShuffle {
      playActions.append(createPlayShuffledAction())
    }
    if !playActions.isEmpty {
      menuActions.append(UIMenu(options: .displayInline, children: playActions))
    }
    if isMusicQueue {
      menuActions.append(createMusicQueueAction())
    }
    if isPodcastQueue {
      menuActions.append(createPodcastQueueAction())
    }
    if isShowAlbum {
      gotoActions.append(createShowAlbumAction())
    }
    if isShowArtist {
      gotoActions.append(createShowArtistAction())
    }
    if isShowSongDetails,
       let song = (entityContainer as? AbstractPlayable)?.asSong,
       let lyricsShowAction = createShowLyricsAction(song: song) {
      gotoActions.append(lyricsShowAction)
    }
    if isShowPodcastDetails,
       let podcastEpisode = (entityContainer as? AbstractPlayable)?.asPodcastEpisode {
      gotoActions.append(createShowEpisodeDetailsAction(podcastEpisode: podcastEpisode))
    }
    if isShowPodcastDetails, let podcast = entityContainer as? Podcast {
      gotoActions.append(createShowPodcastDetailsAction(podcast: podcast))
    }
    if !gotoActions.isEmpty {
      menuActions.append(UIMenu(options: .displayInline, children: gotoActions))
    }
    if let libraryEntity = entityContainer as? AbstractLibraryEntity, entityContainer.isFavoritable,
       appDelegate.storage.settings.user.isOnlineMode {
      ratingFavActions.append(createFavoriteMenu(libraryEntity: libraryEntity))
    }
    if let libraryEntity = entityContainer as? AbstractLibraryEntity, entityContainer.isRateable,
       appDelegate.storage.settings.user.isOnlineMode {
      ratingFavActions.append(createRatingMenu(libraryEntity: libraryEntity))
    }
    if !ratingFavActions.isEmpty {
      menuActions.append(UIMenu(options: .displayInline, children: ratingFavActions))
    }
    if isAddToPlaylist {
      elementHandlingActions.append(createAddToPlaylistAction())
    }
    if isDownloadPossible {
      elementHandlingActions.append(createDownloadAction())
    }
    if entityContainer.playables.hasCachedItems {
      elementHandlingActions.append(createDeleteCacheAction())
    }
    if isDeleteOnServer {
      elementHandlingActions.append(createDeleteOnServerAction())
    }
    if isGoToSiteUrl, let url = (entityContainer as? AbstractPlayable)?.asRadio?.siteURL {
      elementHandlingActions.append(createGoToSiteUrl(url: url))
    }
    if !elementHandlingActions.isEmpty {
      menuActions.append(UIMenu(options: .displayInline, children: elementHandlingActions))
    }
    if appDelegate.storage.settings.user.isShowDetailedInfo {
      menuActions.append(createCopyIdToClipboardAction())
    }

    return menuActions
  }

  public func performPreviewTransition() {
    if let playable = entityContainer as? AbstractPlayable {
      if let _ = playable.asSong, !(rootView is AlbumDetailVC) {
        showAlbum()
      } else if let _ = playable.asPodcastEpisode, !(rootView is PodcastDetailVC) {
        showArtist()
      }
    } else if let album = entityContainer as? Album, let account = album.account {
      rootView.navigationController?.pushViewController(
        AppStoryboard.Main.segueToAlbumDetail(account: account, album: album),
        animated: true
      )
    } else if let artist = entityContainer as? Artist, let account = artist.account {
      rootView.navigationController?.pushViewController(
        AppStoryboard.Main.segueToArtistDetail(account: account, artist: artist),
        animated: true
      )
    } else if let genre = entityContainer as? Genre, let account = genre.account {
      rootView.navigationController?.pushViewController(
        AppStoryboard.Main.segueToGenreDetail(account: account, genre: genre),
        animated: true
      )
    } else if let playlist = entityContainer as? Playlist, let account = playlist.account {
      rootView.navigationController?.pushViewController(
        AppStoryboard.Main.segueToPlaylistDetail(account: account, playlist: playlist),
        animated: true
      )
    } else if let podcast = entityContainer as? Podcast, let account = podcast.account {
      rootView.navigationController?.pushViewController(
        AppStoryboard.Main.segueToPodcastDetail(account: account, podcast: podcast),
        animated: true
      )
    } else if let directory = entityContainer as? Directory, let account = directory.account {
      rootView.navigationController?.pushViewController(
        AppStoryboard.Main.segueToDirectories(account: account, directory: directory),
        animated: true
      )
    }
  }

  private func configureUI() {
    if let playable = entityContainer as? AbstractPlayable {
      if let song = playable.asSong {
        configureFor(song: song)
      } else if let podcastEpisode = playable.asPodcastEpisode {
        configureFor(podcastEpisode: podcastEpisode)
      } else if let radio = playable.asRadio {
        configureFor(radio: radio)
      }
    } else if let album = entityContainer as? Album {
      configureFor(album: album)
    } else if let artist = entityContainer as? Artist {
      configureFor(artist: artist)
    } else if let genre = entityContainer as? Genre {
      configureFor(genre: genre)
    } else if let playlist = entityContainer as? Playlist {
      configureFor(playlist: playlist)
    } else if let podcast = entityContainer as? Podcast {
      configureFor(podcast: podcast)
    } else if let directory = entityContainer as? Directory {
      configureFor(directory: directory)
    }
  }

  private func configureFor(song: Song) {
    isPlay = !(
      (playContextCb == nil) ||
        (!song.isCached && appDelegate.storage.settings.user.isOfflineMode)
    )
    isShuffle = !(
      (playContextCb == nil) ||
        playerIndexCb != nil ||
        (!song.isCached && appDelegate.storage.settings.user.isOfflineMode)
    ) &&
      appDelegate.storage.settings.user.isPlayerShuffleButtonEnabled
    isMusicQueue = !(
      (playContextCb == nil) ||
        playerIndexCb != nil ||
        (!song.isCached && appDelegate.storage.settings.user.isOfflineMode)
    )
    isPodcastQueue = false
    isShowAlbum = !(rootView is AlbumDetailVC)
    isShowArtist = !(rootView is ArtistDetailVC)
    isAddToPlaylist = appDelegate.storage.settings.user.isOnlineMode
    isDeleteOnServer = false
    isGoToSiteUrl = false
    isShowPodcastDetails = false
    isShowSongDetails = true
  }

  private func configureFor(podcastEpisode: PodcastEpisode) {
    isPlay = !(
      (playContextCb == nil) ||
        (!podcastEpisode.isAvailableToUser() && appDelegate.storage.settings.user.isOnlineMode) ||
        (!podcastEpisode.isCached && appDelegate.storage.settings.user.isOfflineMode)
    )
    isShuffle = false
    isMusicQueue = false
    isPodcastQueue = !(
      (playContextCb == nil) ||
        (playerIndexCb != nil) ||
        (!podcastEpisode.isAvailableToUser() && appDelegate.storage.settings.user.isOnlineMode) ||
        (!podcastEpisode.isCached && appDelegate.storage.settings.user.isOfflineMode)
    )
    isShowAlbum = false
    isShowArtist = !(rootView is PodcastDetailVC)
    isAddToPlaylist = false
    isDeleteOnServer = podcastEpisode.podcastStatus != .deleted && appDelegate.storage.settings.user
      .isOnlineMode
    isGoToSiteUrl = false
    isShowPodcastDetails = true
    isShowSongDetails = false
  }

  private func configureFor(radio: Radio) {
    isPlay = !((playContextCb == nil) || appDelegate.storage.settings.user.isOfflineMode)
    isShuffle = false
    isMusicQueue = !(
      (playContextCb == nil) ||
        playerIndexCb != nil ||
        (appDelegate.storage.settings.user.isOfflineMode)
    )
    isPodcastQueue = false
    isAddToPlaylist = false
    isDeleteOnServer = false
    isGoToSiteUrl = radio.siteURL != nil
    isShowPodcastDetails = false
    isShowSongDetails = false
  }

  private func configureFor(playlist: Playlist) {
    isPlay = appDelegate.storage.settings.user.isOnlineMode || entityContainer.playables
      .hasCachedItems
    isShuffle = (
      appDelegate.storage.settings.user.isOnlineMode || entityContainer.playables
        .hasCachedItems
    ) &&
      appDelegate.storage.settings.user.isPlayerShuffleButtonEnabled
    isMusicQueue = true
    isPodcastQueue = false
    isShowAlbum = false
    isShowArtist = false
    isAddToPlaylist = appDelegate.storage.settings.user.isOnlineMode
    isDeleteOnServer = false
    isGoToSiteUrl = false
    isShowPodcastDetails = false
    isShowSongDetails = false
  }

  private func configureFor(genre: Genre) {
    isPlay = appDelegate.storage.settings.user.isOnlineMode || entityContainer.playables
      .hasCachedItems
    isShuffle = (
      appDelegate.storage.settings.user.isOnlineMode || entityContainer.playables
        .hasCachedItems
    ) &&
      appDelegate.storage.settings.user.isPlayerShuffleButtonEnabled
    isMusicQueue = true
    isPodcastQueue = false
    isShowAlbum = false
    isShowArtist = false
    isAddToPlaylist = appDelegate.storage.settings.user.isOnlineMode
    isDeleteOnServer = false
    isGoToSiteUrl = false
    isShowPodcastDetails = false
    isShowSongDetails = false
  }

  private func configureFor(podcast: Podcast) {
    isPlay = (
      appDelegate.storage.settings.user.isOnlineMode || entityContainer.playables
        .hasCachedItems
    ) &&
      appDelegate.storage.settings.user.isPlayerShuffleButtonEnabled
    isShuffle = false
    isMusicQueue = false
    isShowAlbum = false
    isShowArtist = false
    isPodcastQueue = true
    isAddToPlaylist = false
    isDeleteOnServer = false
    isGoToSiteUrl = false
    isShowPodcastDetails = true
    isShowSongDetails = false
  }

  private func configureFor(artist: Artist) {
    isPlay = appDelegate.storage.settings.user.isOnlineMode || entityContainer.playables
      .hasCachedItems
    isShuffle = (
      appDelegate.storage.settings.user.isOnlineMode || entityContainer.playables
        .hasCachedItems
    ) &&
      appDelegate.storage.settings.user.isPlayerShuffleButtonEnabled
    isMusicQueue = true
    isPodcastQueue = false
    isShowAlbum = false
    isShowArtist = false
    isAddToPlaylist = appDelegate.storage.settings.user.isOnlineMode
    isDeleteOnServer = false
    isGoToSiteUrl = false
    isShowPodcastDetails = false
    isShowSongDetails = false
  }

  private func configureFor(album: Album) {
    isPlay = appDelegate.storage.settings.user.isOnlineMode || entityContainer.playables
      .hasCachedItems
    isShuffle = (
      appDelegate.storage.settings.user.isOnlineMode || entityContainer.playables
        .hasCachedItems
    ) &&
      appDelegate.storage.settings.user.isPlayerShuffleButtonEnabled
    isMusicQueue = true
    isPodcastQueue = false
    isShowAlbum = false
    isShowArtist = !(rootView is ArtistDetailVC)
    isAddToPlaylist = appDelegate.storage.settings.user.isOnlineMode
    isDeleteOnServer = false
    isGoToSiteUrl = false
    isShowPodcastDetails = false
    isShowSongDetails = false
  }

  private func configureFor(directory: Directory) {
    isPlay = appDelegate.storage.settings.user.isOnlineMode || entityContainer.playables
      .hasCachedItems
    isShuffle = (
      appDelegate.storage.settings.user.isOnlineMode || entityContainer.playables
        .hasCachedItems
    ) &&
      appDelegate.storage.settings.user.isPlayerShuffleButtonEnabled
    isMusicQueue = true
    isPodcastQueue = false
    isShowAlbum = false
    isShowArtist = false
    isAddToPlaylist = appDelegate.storage.settings.user.isOnlineMode && !entityContainer.playables
      .isEmpty
    isDeleteOnServer = false
    isGoToSiteUrl = false
    isShowPodcastDetails = false
    isShowSongDetails = false
  }

  private func createPlayAction() -> UIAction {
    UIAction(title: "Play", image: .play) { action in
      guard !self.entityPlayables.isEmpty else { return }
      if let playerIndex = self.playerIndexCb?() {
        self.appDelegate.player.play(playerIndex: playerIndex)
      } else if let context = self.playContextCb?() {
        self.appDelegate.player.play(context: context)
      } else {
        self.appDelegate.player.play(context: PlayContext(
          containable: self.entityContainer,
          playables: self.entityPlayables
        ))
      }
    }
  }

  private func createPlayShuffledAction() -> UIAction {
    UIAction(title: "Shuffle", image: .shuffle) { action in
      guard !self.entityPlayables.isEmpty else { return }
      if let context = self.playContextCb?() {
        self.appDelegate.player.playShuffled(context: context)
      } else {
        self.appDelegate.player.playShuffled(context: PlayContext(
          containable: self.entityContainer,
          playables: self.entityPlayables
        ))
      }
    }
  }

  private func createMusicQueueAction() -> UIMenuElement {
    UIMenu(title: "Music Queue", image: .listBullet, children: [
      UIAction(title: "Insert Context Queue", image: .contextQueueInsert) { action in
        guard !self.entityPlayables.isEmpty else { return }
        self.appDelegate.player.insertContextQueue(playables: self.entityPlayables)
      },
      UIAction(title: "Append Context Queue", image: .contextQueueAppend) { action in
        guard !self.entityPlayables.isEmpty else { return }
        self.appDelegate.player.appendContextQueue(playables: self.entityPlayables)
      },
      UIAction(title: "Insert User Queue", image: .userQueueInsert) { action in
        guard !self.entityPlayables.isEmpty else { return }
        self.appDelegate.player.insertUserQueue(playables: self.entityPlayables)
      },
      UIAction(title: "Append User Queue", image: .userQueueAppend) { action in
        guard !self.entityPlayables.isEmpty else { return }
        self.appDelegate.player.appendUserQueue(playables: self.entityPlayables)
      },
    ])
  }

  private func createPodcastQueueAction() -> UIMenuElement {
    UIMenu(image: .listBullet, options: .displayInline, children: [
      UIAction(title: "Insert Podcast Queue", image: .podcastQueueInsert) { action in
        guard !self.entityPlayables.isEmpty else { return }
        self.appDelegate.player.insertPodcastQueue(playables: self.entityPlayables)
      },
      UIAction(title: "Append Podcast Queue", image: .podcastQueueAppend) { action in
        guard !self.entityPlayables.isEmpty else { return }
        self.appDelegate.player.appendPodcastQueue(playables: self.entityPlayables)
      },
    ])
  }

  private func createFavoriteMenu(libraryEntity: AbstractLibraryEntity) -> UIAction {
    libraryEntity.isFavorite ?
      UIAction(title: "Unmark favorite", image: .heartSlash) { action in self.toggleFavorite() } :
      UIAction(title: "Favorite", image: .heartEmpty) { action in self.toggleFavorite() }
  }

  private func toggleFavorite() {
    guard appDelegate.storage.settings.user.isOnlineMode,
          let account = entityContainer.account else { return }
    Task { @MainActor in
      do {
        try await entityContainer
          .remoteToggleFavorite(
            syncer: self.appDelegate.getMeta(account.info)
              .librarySyncer
          )
      } catch {
        self.appDelegate.eventLogger.report(topic: "Toggle Favorite", error: error)
      }
      self.reloadRootView()
    }
  }

  private func createRatingMenu(libraryEntity: AbstractLibraryEntity) -> UIMenu {
    let rating = libraryEntity
      .rating == 0 ? "Not rated" :
      "\(libraryEntity.rating) Star\(libraryEntity.rating > 1 ? "s" : "")"
    let menuIcon = libraryEntity
      .rating == 0 ? UIImage.starEmpty : UIImage.starFill
    let children = [
      UIAction(title: "No Rating", image: .ban) { action in self.setRating(rating: 0) },
      UIAction(
        title: "1 Star",
        image: libraryEntity.rating >= 1 ? .starFill : .starEmpty
      ) { action in
        self.setRating(rating: 1)
      },
      UIAction(
        title: "2 Stars",
        image: libraryEntity.rating >= 2 ? .starFill : .starEmpty
      ) { action in self
        .setRating(rating: 2)
      },
      UIAction(
        title: "3 Stars",
        image: libraryEntity.rating >= 3 ? .starFill : .starEmpty
      ) { action in self
        .setRating(rating: 3)
      },
      UIAction(
        title: "4 Stars",
        image: libraryEntity.rating >= 4 ? .starFill : .starEmpty
      ) { action in self
        .setRating(rating: 4)
      },
      UIAction(
        title: "5 Stars",
        image: libraryEntity.rating >= 5 ? .starFill : .starEmpty
      ) { action in self
        .setRating(rating: 5)
      },
    ]

    return UIMenu(
      title: "Rating: \(rating)",
      image: menuIcon,
      options: .displayAsPalette,
      children: children
    )
  }

  private func setRating(rating: Int) {
    guard appDelegate.storage.settings.user.isOnlineMode,
          let account = entityContainer.account else { return }
    if let song = (entityContainer as? AbstractPlayable)?.asSong {
      song.rating = rating
      appDelegate.storage.main.saveContext()
      Task { @MainActor in do {
        try await self.appDelegate.getMeta(account.info).librarySyncer.setRating(
          song: song,
          rating: rating
        )
      } catch {
        self.appDelegate.eventLogger.report(topic: "Song Rating Sync", error: error)
      }}
    } else if let album = entityContainer as? Album {
      album.rating = rating
      appDelegate.storage.main.saveContext()
      Task { @MainActor in do {
        try await self.appDelegate.getMeta(account.info).librarySyncer.setRating(
          album: album,
          rating: rating
        )
      } catch {
        self.appDelegate.eventLogger.report(topic: "Album Rating Sync", error: error)
      }}
    } else if let artist = entityContainer as? Artist {
      artist.rating = rating
      appDelegate.storage.main.saveContext()
      Task { @MainActor in do {
        try await self.appDelegate.getMeta(account.info).librarySyncer.setRating(
          artist: artist,
          rating: rating
        )
      } catch {
        self.appDelegate.eventLogger.report(topic: "Artist Rating Sync", error: error)
      }}
    }
  }

  private func createAddToPlaylistAction() -> UIAction {
    UIAction(title: "Add to Playlist", image: .playlistPlus) { action in
      guard !self.entityPlayables.isEmpty,
            let account = self.entityContainer.account else { return }
      let selectPlaylistVC = AppStoryboard.Main
        .segueToPlaylistSelector(account: account, itemsToAdd: self.entityPlayables.filterSongs())
      let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
      self.rootView.present(selectPlaylistNav, animated: true)
    }
  }

  private func createShowAlbumAction() -> UIAction {
    UIAction(title: "Show Album", image: .album) { action in
      self.showAlbum()
    }
  }

  private func showAlbum() {
    let playable = entityContainer as? AbstractPlayable
    let album = playable?.asSong?.album
    guard let album = album, let account = album.account else { return }
    appDelegate.userStatistics.usedAction(.alertGoToAlbum)
    let albumDetailVC = AppStoryboard.Main.segueToAlbumDetail(
      account: account,
      album: album,
      songToScrollTo: playable?.asSong
    )
    if let popupPlayer = rootView as? PopupPlayerVC {
      popupPlayer.closePopupPlayerAndDisplayInLibraryTab(vc: albumDetailVC)
    } else if let navController = rootView.navigationController {
      navController.pushViewController(albumDetailVC, animated: true)
    } else {
      guard let hostingSplitVC = AppDelegate.mainWindowHostVC else { return }
      hostingSplitVC.pushNavLibrary(vc: albumDetailVC)
    }
  }

  private func createShowArtistAction() -> UIAction {
    let title = ((entityContainer as? AbstractPlayable)?.isPodcastEpisode ?? false) ?
      "Show Podcast" : "Show Artist"
    let image = ((entityContainer as? AbstractPlayable)?.isPodcastEpisode ?? false) ? UIImage
      .squareArrow : UIImage.artist
    return UIAction(title: title, image: image) { action in
      self.showArtist()
    }
  }

  private func showArtist() {
    let playable = entityContainer as? AbstractPlayable
    let album = entityContainer as? Album
    if let artist = playable?.asSong?.artist ?? album?.artist, let account = artist.account {
      appDelegate.userStatistics.usedAction(.alertGoToArtist)
      let artistDetailVC = AppStoryboard.Main.segueToArtistDetail(
        account: account,
        artist: artist,
        albumToScrollTo: album
      )
      if let popupPlayer = rootView as? PopupPlayerVC {
        popupPlayer.closePopupPlayerAndDisplayInLibraryTab(vc: artistDetailVC)
      } else if let navController = rootView.navigationController {
        navController.pushViewController(artistDetailVC, animated: true)
      } else {
        guard let hostingSplitVC = AppDelegate.mainWindowHostVC else { return }
        hostingSplitVC.pushNavLibrary(vc: artistDetailVC)
      }
    } else if let podcast = playable?.asPodcastEpisode?.podcast, let account = podcast.account {
      appDelegate.userStatistics.usedAction(.alertGoToPodcast)
      let podcastDetailVC = AppStoryboard.Main.segueToPodcastDetail(
        account: account,
        podcast: podcast,
        episodeToScrollTo: playable?.asPodcastEpisode
      )
      if let popupPlayer = rootView as? PopupPlayerVC {
        popupPlayer.closePopupPlayerAndDisplayInLibraryTab(vc: podcastDetailVC)
      } else if let navController = rootView.navigationController {
        navController.pushViewController(podcastDetailVC, animated: true)
      } else {
        guard let hostingSplitVC = AppDelegate.mainWindowHostVC else { return }
        hostingSplitVC.pushNavLibrary(vc: podcastDetailVC)
      }
    }
  }

  private func createDownloadAction() -> UIAction {
    UIAction(title: "Download", image: .download) { action in
      if !self.entityPlayables.isEmpty,
         let accountInfo = self.entityPlayables.first?.account?.info {
        self.appDelegate.getMeta(accountInfo).playableDownloadManager
          .download(objects: self.entityPlayables)
      }
    }
  }

  private func createDeleteCacheAction() -> UIAction {
    UIAction(title: "Delete Cache", image: .trash) { action in
      guard self.entityPlayables.hasCachedItems,
            let account = self.entityContainer.account else { return }

      let alert = UIAlertController(
        title: nil,
        message: "Are you sure to delete the cached file\(self.entityPlayables.count > 1 ? "s" : "")?",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
        self.appDelegate.getMeta(account.info).playableDownloadManager
          .removeFinishedDownload(for: self.entityPlayables)
        self.appDelegate.storage.main.library.deleteCache(of: self.entityPlayables)
        self.appDelegate.storage.main.saveContext()
        self.reloadRootView()
      }))
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
        // do nothing
      }))
      self.rootView.present(alert, animated: true, completion: nil)
    }
  }

  private func createDeleteOnServerAction() -> UIAction {
    UIAction(title: "Delete on Server", image: .cloudX) { action in
      guard let playable = self.entityContainer as? AbstractPlayable,
            let podcastEpisode = playable.asPodcastEpisode,
            let account = podcastEpisode.account
      else { return }

      let alert = UIAlertController(
        title: nil,
        message: "Are you sure to delete the podcast episode on the server?",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
        Task { @MainActor in do {
          try await self.appDelegate.getMeta(account.info).librarySyncer
            .requestPodcastEpisodeDelete(podcastEpisode: podcastEpisode)
          guard let podcast = podcastEpisode.podcast else { return }
          try await self.appDelegate.getMeta(account.info).librarySyncer
            .sync(podcast: podcast)
        } catch {
          self.appDelegate.eventLogger.report(topic: "Podcast Episode Delete Sync", error: error)
        }}
      }))
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
        // do nothing
      }))
      self.rootView.present(alert, animated: true, completion: nil)
    }
  }

  private func createGoToSiteUrl(url: URL) -> UIAction {
    UIAction(title: "Go to Site", image: .followLink) { action in
      UIApplication.shared.open(url)
    }
  }

  private func createShowPodcastDetailsAction(podcast: Podcast) -> UIAction {
    UIAction(title: "Show Podcast Description", image: .info) { action in
      self.showPodcastDetails()
    }
  }

  private func createShowEpisodeDetailsAction(podcastEpisode: PodcastEpisode) -> UIAction {
    UIAction(title: "Show Episode Description", image: .info) { action in
      self.showPodcastDetails()
    }
  }

  private func showPodcastDetails() {
    var descriptionVC: PlainDetailsVC?
    if let playable = entityContainer as? AbstractPlayable,
       let podcastEpisode = playable.asPodcastEpisode {
      descriptionVC = PlainDetailsVC()
      descriptionVC?.display(podcastEpisode: podcastEpisode, on: rootView)
    } else if let podcast = entityContainer as? Podcast {
      descriptionVC = PlainDetailsVC()
      descriptionVC?.display(podcast: podcast, on: rootView)
    }

    if let descriptionVC = descriptionVC {
      rootView.present(descriptionVC, animated: true)
    }
  }

  private func createShowLyricsAction(song: Song) -> UIAction? {
    guard let playable = entityContainer as? AbstractPlayable,
          let song = playable.asSong,
          let lyricsRelFilePath = song.lyricsRelFilePath,
          let lyricsAccount = song.account
    else { return nil }

    return UIAction(title: "Show Lyrics", image: .lyrics) { action in
      self.showLyrics(lyricsRelFilePath: lyricsRelFilePath, lyricsAccount: lyricsAccount)
    }
  }

  private func showLyrics(lyricsRelFilePath: URL, lyricsAccount: Account) {
    let lyricsVC = PlainDetailsVC()
    lyricsVC.display(
      lyricsRelFilePath: lyricsRelFilePath,
      lyricsAccount: lyricsAccount,
      on: rootView
    )
    rootView.present(lyricsVC, animated: true)
  }

  private func createCopyIdToClipboardAction() -> UIMenu {
    UIMenu(
      options: .displayInline,
      children: [UIAction(title: "Copy ID to Clipboard", image: .clipboard) { action in
        if !self.entityContainer.id.isEmpty {
          UIPasteboard.general.string = self.entityContainer.id
        }
      }]
    )
  }

  private func reloadRootView() {
    if let rootTableView = rootView as? UITableViewController {
      rootTableView.tableView.reloadData()
    } else if let popupPlayer = rootView as? PopupPlayerVC {
      popupPlayer.tableView.reloadData()
    }
    if let splitVC = rootView as? SplitVC,
       let queueVC = splitVC.viewController(for: .inspector) as? QueueVC {
      queueVC.tableView?.reloadData()
    }
  }
}

// MARK: - EntityPreviewVC

class EntityPreviewVC: UIViewController {
  override var sceneTitle: String? { entityContainer?.name }

  static let margin = UIEdgeInsets(
    top: UIView.defaultMarginX,
    left: UIView.defaultMarginX,
    bottom: UIView.defaultMarginX,
    right: UIView.defaultMarginX
  )

  @IBOutlet
  weak var titleLabel: MarqueeLabel!
  @IBOutlet
  weak var artistLabel: MarqueeLabel!
  @IBOutlet
  weak var infoLabel: MarqueeLabel!
  @IBOutlet
  weak var entityImageView: EntityImageView!
  @IBOutlet
  weak var gotoDetailsSymbol: UIImageView!

  private var rootView: UIViewController?
  private var entityContainer: PlayableContainable?

  var isNavigationDisallowed: Bool {
    ((entityContainer as? AbstractPlayable)?.isSong ?? false) && (rootView is AlbumDetailVC) ||
      ((entityContainer as? AbstractPlayable)?.isPodcastEpisode ?? false) &&
      (rootView is PodcastDetailVC)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.setBackgroundBlur(style: .prominent)
    titleLabel.applyAmperfyStyle()
    artistLabel.applyAmperfyStyle()
    infoLabel.applyAmperfyStyle()
    gotoDetailsSymbol.isHidden = isNavigationDisallowed

    // The preview will size to the preferredContentSize, which can be useful
    // for displaying a preview with the dimension of an image, for example.
    // Unlike peek and pop, it doesn't seem to automatically scale down for you.

    if traitCollection.userInterfaceIdiom == .phone {
      preferredContentSize = CGSize(
        width: view.bounds.width,
        height: 150 + Self.margin.top + Self.margin.bottom
      )
    } else if traitCollection.userInterfaceIdiom == .pad {
      preferredContentSize = CGSize(
        width: view.bounds.width,
        height: 190 + Self.margin.top + Self.margin.bottom
      )
    } else {
      preferredContentSize = CGSize(
        width: view.bounds.width,
        height: 190 + Self.margin.top + Self.margin.bottom
      )
    }
  }

  override func viewIsAppearing(_ animated: Bool) {
    refresh()
  }

  func display(container: PlayableContainable, on rootView: UIViewController) {
    self.rootView = rootView
    entityContainer = container
  }

  func refresh() {
    guard let entityContainer = entityContainer else { return }
    entityImageView.display(
      theme: appDelegate.storage.settings.accounts.getSetting(entityContainer.account?.info).read
        .themePreference,
      container: entityContainer
    )
    titleLabel.text = entityContainer.name
    artistLabel.text = entityContainer.subtitle
    artistLabel.isHidden = entityContainer.subtitle == nil
    infoLabel.text = entityContainer.info(
      for: entityContainer.account?.apiType.asServerApiType,
      details: DetailInfoType(type: .long, settings: appDelegate.storage.settings)
    )
  }
}
