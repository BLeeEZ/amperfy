//
//  PlaylistDetailVC.swift
//  Amperfy
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

import AmperfyKit
import CoreData
import UIKit

// MARK: - PlaylistDetailDiffableDataSource

class PlaylistDetailDiffableDataSource: BasicUITableViewDiffableDataSource {
  var playlist: Playlist!
  var isMoveAllowed = false
  var isEditAllowed = true

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the item to be re-orderable.
    isMoveAllowed
  }

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Return true to be enable swipe
    isEditAllowed
  }

  override func tableView(
    _ tableView: UITableView,
    moveRowAt sourceIndexPath: IndexPath,
    to destinationIndexPath: IndexPath
  ) {
    exectueAfterAnimation {
      self.playlist?.movePlaylistItem(fromIndex: sourceIndexPath.row, to: destinationIndexPath.row)

      guard self.appDelegate.storage.settings.user.isOnlineMode,
            let account = self.playlist.account else { return }
      Task { @MainActor in do {
        try await self.appDelegate.getMeta(account.info).librarySyncer
          .syncUpload(playlistToUpdateOrder: self.playlist)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Playlist Upload Order Update", error: error)
      }}
    }
    super.tableView(tableView, moveRowAt: sourceIndexPath, to: destinationIndexPath)
  }

  override func tableView(
    _ tableView: UITableView,
    commit editingStyle: UITableViewCell.EditingStyle,
    forRowAt indexPath: IndexPath
  ) {
    guard editingStyle == .delete else { return }
    exectueAfterAnimation {
      self.playlist?.remove(at: indexPath.row)
      guard self.appDelegate.storage.settings.user.isOnlineMode,
            let account = self.playlist.account else { return }
      Task { @MainActor in do {
        try await self.appDelegate.getMeta(account.info).librarySyncer.syncUpload(
          playlistToDeleteSong: self.playlist,
          index: indexPath.row
        )
      } catch {
        self.appDelegate.eventLogger.report(topic: "Playlist Upload Entry Remove", error: error)
      }}
    }
    super.tableView(tableView, commit: editingStyle, forRowAt: indexPath)
  }
}

// MARK: - PlaylistPlaybackControlsView

@MainActor
private final class PlaylistPlaybackControlsView: UIView {
  static let frameHeight: CGFloat = 112

  var visibilityChangedCB: VoidFunctionCallback?

  private let player: PlayerFacade
  private let playerHandler: PlayerUIHandler
  private let previousButton = UIButton(type: .system)
  private let playButton = UIButton(type: .system)
  private let nextButton = UIButton(type: .system)
  private let volumeDownButton = UIButton(type: .system)
  private let volumeUpButton = UIButton(type: .system)
  private let volumeSlider = UISlider()
  private let volumeValueLabel = UILabel()
  private let separatorView = UIView()

  var shouldDisplay: Bool {
    player.currentlyPlaying != nil ||
      player.prevQueueCount > 0 ||
      player.userQueueCount > 0 ||
      player.nextQueueCount > 0
  }

  override init(frame: CGRect) {
    let player = (UIApplication.shared.delegate as! AppDelegate).player
    self.player = player
    self.playerHandler = PlayerUIHandler(player: player, style: .popupPlayer)
    super.init(frame: frame)
    setup()
    player.addNotifier(notifier: self)
    refreshDisplayState()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup() {
    backgroundColor = .secondarySystemBackground
    directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 10,
      leading: UIView.defaultMarginCellX,
      bottom: 12,
      trailing: UIView.defaultMarginCellX
    )

    separatorView.backgroundColor = .separator
    separatorView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(separatorView)

    configureTransportButton(
      previousButton,
      image: .backwardFill,
      label: "Previous Track",
      action: #selector(previousButtonPushed)
    )
    configureTransportButton(
      playButton,
      image: .play,
      label: "Play or Pause",
      action: #selector(playButtonPushed)
    )
    configureTransportButton(
      nextButton,
      image: .forwardFill,
      label: "Next Track",
      action: #selector(nextButtonPushed)
    )
    configureVolumeButton(
      volumeDownButton,
      image: .volumeMin,
      label: "Volume Down",
      action: #selector(volumeDownButtonPushed)
    )
    configureVolumeButton(
      volumeUpButton,
      image: .volumeMax,
      label: "Volume Up",
      action: #selector(volumeUpButtonPushed)
    )

    volumeSlider.minimumValue = 1
    volumeSlider.maximumValue = 100
    volumeSlider.isContinuous = true
    volumeSlider.tintColor = .label
    volumeSlider.translatesAutoresizingMaskIntoConstraints = false
    volumeSlider.addTarget(
      self,
      action: #selector(volumeSliderChanged),
      for: .valueChanged
    )

    volumeValueLabel.font = .preferredFont(forTextStyle: .footnote)
    volumeValueLabel.adjustsFontForContentSizeCategory = true
    volumeValueLabel.textAlignment = .right
    volumeValueLabel.textColor = .secondaryLabel
    volumeValueLabel.translatesAutoresizingMaskIntoConstraints = false

    let transportStack = UIStackView(arrangedSubviews: [
      previousButton,
      playButton,
      nextButton,
    ])
    transportStack.axis = .horizontal
    transportStack.alignment = .center
    transportStack.distribution = .equalCentering
    transportStack.translatesAutoresizingMaskIntoConstraints = false

    let volumeStack = UIStackView(arrangedSubviews: [
      volumeDownButton,
      volumeSlider,
      volumeValueLabel,
      volumeUpButton,
    ])
    volumeStack.axis = .horizontal
    volumeStack.alignment = .center
    volumeStack.spacing = 10
    volumeStack.translatesAutoresizingMaskIntoConstraints = false

    addSubview(transportStack)
    addSubview(volumeStack)

    NSLayoutConstraint.activate([
      separatorView.topAnchor.constraint(equalTo: topAnchor),
      separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
      separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
      separatorView.heightAnchor.constraint(equalToConstant: 0.5),

      transportStack.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
      transportStack.centerXAnchor.constraint(equalTo: centerXAnchor),
      transportStack.widthAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.widthAnchor),
      transportStack.heightAnchor.constraint(equalToConstant: 44),

      previousButton.widthAnchor.constraint(equalToConstant: 72),
      playButton.widthAnchor.constraint(equalToConstant: 80),
      nextButton.widthAnchor.constraint(equalToConstant: 72),

      volumeStack.topAnchor.constraint(equalTo: transportStack.bottomAnchor, constant: 8),
      volumeStack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
      volumeStack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
      volumeStack.bottomAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor),

      volumeDownButton.widthAnchor.constraint(equalToConstant: 36),
      volumeDownButton.heightAnchor.constraint(equalToConstant: 36),
      volumeUpButton.widthAnchor.constraint(equalToConstant: 36),
      volumeUpButton.heightAnchor.constraint(equalToConstant: 36),
      volumeValueLabel.widthAnchor.constraint(equalToConstant: 36),
    ])
  }

  private func configureTransportButton(
    _ button: UIButton,
    image: UIImage,
    label: String,
    action: Selector
  ) {
    button.setImage(
      image.withConfiguration(UIImage.SymbolConfiguration(pointSize: 32, weight: .regular)),
      for: .normal
    )
    button.tintColor = .label
    button.accessibilityLabel = label
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: action, for: .touchUpInside)
  }

  private func configureVolumeButton(
    _ button: UIButton,
    image: UIImage,
    label: String,
    action: Selector
  ) {
    button.setImage(
      image.withConfiguration(UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)),
      for: .normal
    )
    button.tintColor = .label
    button.accessibilityLabel = label
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: action, for: .touchUpInside)
  }

  func refreshDisplayState() {
    let newHiddenValue = !shouldDisplay
    if isHidden != newHiddenValue {
      isHidden = newHiddenValue
      visibilityChangedCB?()
    }
    refreshControls()
  }

  private func refreshControls() {
    playerHandler.refreshPlayButton(playButton)
    playerHandler.refreshPrevNextButtons(previousButton: previousButton, nextButton: nextButton)

    let volumeLevel = max(1, min(100, Int(round(player.volume * 100))))
    volumeSlider.setValue(Float(volumeLevel), animated: false)
    volumeValueLabel.text = "\(volumeLevel)"
  }

  @objc
  private func previousButtonPushed() {
    playerHandler.previousButtonPushed()
    refreshControls()
  }

  @objc
  private func playButtonPushed() {
    playerHandler.playButtonPushed()
    refreshControls()
  }

  @objc
  private func nextButtonPushed() {
    playerHandler.nextButtonPushed()
    refreshControls()
  }

  @objc
  private func volumeDownButtonPushed() {
    setVolumeLevel(Int(volumeSlider.value) - 1)
  }

  @objc
  private func volumeUpButtonPushed() {
    setVolumeLevel(Int(volumeSlider.value) + 1)
  }

  @objc
  private func volumeSliderChanged() {
    setVolumeLevel(Int(round(volumeSlider.value)))
  }

  private func setVolumeLevel(_ level: Int) {
    let clampedLevel = max(1, min(100, level))
    player.volume = Float(clampedLevel) / 100.0
    volumeSlider.setValue(Float(clampedLevel), animated: false)
    volumeValueLabel.text = "\(clampedLevel)"
  }
}

// MARK: MusicPlayable

extension PlaylistPlaybackControlsView: MusicPlayable {
  func didStartPlayingFromBeginning() {
    refreshDisplayState()
  }

  func didStartPlaying() {
    refreshDisplayState()
  }

  func didPause() {
    refreshDisplayState()
  }

  func didStopPlaying() {
    refreshDisplayState()
  }

  func didElapsedTimeChange() {}

  func didPlaylistChange() {
    refreshDisplayState()
  }

  func didArtworkChange() {}

  func didShuffleChange() {}

  func didRepeatChange() {}

  func didPlaybackRateChange() {}
}

// MARK: - PlaylistDetailVC

class PlaylistDetailVC: SingleSnapshotFetchedResultsTableViewController<PlaylistItemMO> {
  override var sceneTitle: String? { playlist.name }

  private var fetchedResultsController: PlaylistItemsFetchedResultsController!
  let playlist: Playlist

  private var editButton: UIBarButtonItem!
  private var optionsButton: UIBarButtonItem!
  var detailOperationsView: GenericDetailTableHeader?
  private var fixedPlayerControlsView: PlaylistPlaybackControlsView?
  private var fixedPlayerControlsBottomConstraint: NSLayoutConstraint?

  init(account: Account, playlist: Playlist) {
    self.playlist = playlist
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func createDiffableDataSource() -> BasicUITableViewDiffableDataSource {
    let source =
      PlaylistDetailDiffableDataSource(tableView: tableView) { tableView, indexPath, objectID -> UITableViewCell? in
        guard let object = try? self.appDelegate.storage.main.context
          .existingObject(with: objectID),
          let playlistItemMO = object as? PlaylistItemMO
        else {
          return UITableViewCell()
        }
        let playlistItem = PlaylistItem(
          library: self.appDelegate.storage.main.library,
          managedObject: playlistItemMO
        )
        return self.createCell(tableView, forRowAt: indexPath, playlistItem: playlistItem)
      }
    source.playlist = playlist
    return source
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    #if !targetEnvironment(macCatalyst)
      refreshControl = UIRefreshControl()
    #endif

    appDelegate.userStatistics.visited(.playlistDetail)
    fetchedResultsController = PlaylistItemsFetchedResultsController(
      forPlaylist: playlist,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    singleFetchedResultsController = fetchedResultsController
    singleFetchedResultsController?.delegate = self
    singleFetchedResultsController?.fetch()

    tableView.register(nibName: PlayableTableCell.typeName)
    tableView.rowHeight = PlayableTableCell.rowHeight
    tableView.estimatedRowHeight = PlayableTableCell.rowHeight
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.backgroundColor = .backgroundColor

    // Use a single button, two buttons don't work on catalyst
    editButton = UIBarButtonItem(
      title: "Edit",
      style: .plain,
      target: self,
      action: #selector(openEditView)
    )
    optionsButton = UIBarButtonItem.createOptionsBarButton()
    optionsButton.menu = UIMenu.lazyMenu {
      EntityPreviewActionBuilder(container: self.playlist, on: self).createMenuActions()
    }

    let playShuffleInfoConfig = PlayShuffleInfoConfiguration(
      infoCB: { "\(self.playlist.songCount) Song\(self.playlist.songCount == 1 ? "" : "s")" },
      playContextCb: { () in PlayContext(
        containable: self.playlist,
        playables: self.fetchedResultsController
          .getContextSongs(onlyCachedSongs: self.appDelegate.storage.settings.user.isOfflineMode) ??
          []
      ) },
      player: appDelegate.player,
      isInfoAlwaysHidden: true
    )
    let detailHeaderConfig = DetailHeaderConfiguration(
      entityContainer: playlist,
      rootView: self,
      tableView: tableView,
      playShuffleInfoConfig: playShuffleInfoConfig
    )
    detailOperationsView = GenericDetailTableHeader
      .createTableHeader(configuration: detailHeaderConfig)
    refreshControl?.addTarget(
      self,
      action: #selector(Self.handleRefresh),
      for: UIControl.Event.valueChanged
    )

    snapshotDidChange = detailOperationsView?.refresh
    setupFixedPlayerControls()

    containableAtIndexPathCallback = { indexPath in
      self.fetchedResultsController.getWrappedEntity(at: indexPath).playable
    }
    playContextAtIndexPathCallback = { indexPath in
      self.convertIndexPathToPlayContext(songIndexPath: indexPath)
    }
    swipeCallback = { indexPath, completionHandler in
      let playlistItem = self.fetchedResultsController.getWrappedEntity(at: indexPath)
      let playContext = self.convertIndexPathToPlayContext(songIndexPath: indexPath)
      completionHandler(SwipeActionContext(
        containable: playlistItem.playable,
        playContext: playContext
      ))
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = false
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateBottomSafeAreaForFixedControls()
    if appDelegate.storage.settings.user.isOfflineMode {
      tableView.isEditing = false
    }
    refreshBarButtons()
    Task { @MainActor in
      do {
        try await playlist.fetch(
          storage: self.appDelegate.storage,
          librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
          playableDownloadManager: self.appDelegate.getMeta(self.account.info)
            .playableDownloadManager
        )
      } catch {
        self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
      }
      self.detailOperationsView?.refresh()
    }
  }

  func refreshBarButtons() {
    var edititingBarButton: UIBarButtonItem? = nil

    if appDelegate.storage.settings.user.isOnlineMode {
      edititingBarButton = editButton
      edititingBarButton?.title = "Edit"
      edititingBarButton?.style = .plain
      if playlist.isSmartPlaylist {
        edititingBarButton?.isEnabled = false
      }
    }

    navigationItem.rightBarButtonItems = [optionsButton, edititingBarButton].compactMap { $0 }
  }

  func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
    guard let songs = fetchedResultsController
      .getContextSongs(onlyCachedSongs: appDelegate.storage.settings.user.isOfflineMode)
    else { return nil }
    return PlayContext(containable: playlist, index: songIndexPath.row, playables: songs)
  }

  func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
    guard let indexPath = tableView.indexPath(for: cell)
    else { return nil }
    return convertIndexPathToPlayContext(songIndexPath: IndexPath(row: indexPath.row, section: 0))
  }

  @objc
  private func openEditView(sender: UIBarButtonItem) {
    let playlistDetailVC = AppStoryboard.Main.segueToPlaylistEdit(
      account: account,
      playlist: playlist
    )
    let playlistDetailNav = UINavigationController(rootViewController: playlistDetailVC)
    playlistDetailVC.onDoneCB = {
      self.detailOperationsView?.refresh()
      self.tableView.reloadData()
    }
    present(playlistDetailNav, animated: true, completion: nil)
  }

  func createCell(
    _ tableView: UITableView,
    forRowAt indexPath: IndexPath,
    playlistItem: PlaylistItem
  )
    -> UITableViewCell {
    let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
    if let song = playlistItem.playable.asSong {
      cell.display(playable: song, playContextCb: convertCellViewToPlayContext, rootView: self)
    }
    return cell
  }

  override func updateSearchResults(for searchController: UISearchController) {
    fetchedResultsController
      .search(onlyCachedSongs: appDelegate.storage.settings.user.isOfflineMode)
    tableView.reloadData()
  }

  @objc
  func handleRefresh(refreshControl: UIRefreshControl) {
    Task { @MainActor in
      do {
        try await self.appDelegate.getMeta(self.account.info).librarySyncer
          .syncDown(playlist: playlist)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
      }
      self.detailOperationsView?.refresh()
      self.refreshControl?.endRefreshing()
    }
  }

  private func setupFixedPlayerControls() {
    #if targetEnvironment(macCatalyst)
      return
    #else
    let fixedPlayerControlsView = PlaylistPlaybackControlsView()
    fixedPlayerControlsView.translatesAutoresizingMaskIntoConstraints = false
    fixedPlayerControlsView.visibilityChangedCB = { [weak self] in
      self?.updateBottomSafeAreaForFixedControls()
    }
    view.addSubview(fixedPlayerControlsView)
    let bottomConstraint = fixedPlayerControlsView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    NSLayoutConstraint.activate([
      fixedPlayerControlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      fixedPlayerControlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      fixedPlayerControlsView.heightAnchor.constraint(
        equalToConstant: PlaylistPlaybackControlsView.frameHeight
      ),
      bottomConstraint,
    ])
    self.fixedPlayerControlsView = fixedPlayerControlsView
    fixedPlayerControlsBottomConstraint = bottomConstraint
    #endif
  }

  private func updateBottomSafeAreaForFixedControls() {
    let miniPlayerSafeAreaExtension = AppDelegate.mainWindowHostVC?.getSafeAreaExtension() ?? 0
    let systemBottomSafeArea = max(0, view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom)
    fixedPlayerControlsBottomConstraint?.constant = -(systemBottomSafeArea + miniPlayerSafeAreaExtension)
    fixedPlayerControlsView?.refreshDisplayState()
    let controlsHeight = fixedPlayerControlsView?.shouldDisplay == true
      ? PlaylistPlaybackControlsView.frameHeight
      : 0
    additionalSafeAreaInsets = UIEdgeInsets(
      top: 0,
      left: 0,
      bottom: miniPlayerSafeAreaExtension + controlsHeight,
      right: 0
    )
  }
}
