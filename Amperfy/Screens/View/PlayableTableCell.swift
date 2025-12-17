//
//  SongTableCell.swift
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
import UIKit

typealias GetPlayContextFromTableCellCallback = (UITableViewCell) -> PlayContext?
typealias GetPlayerIndexFromTableCellCallback = (PlayableTableCell) -> PlayerIndex?

// MARK: - DisplayMode

enum DisplayMode {
  case normal
  case selection
  case reorder
  case add
}

// MARK: - PlayableTableCellStyle

enum PlayableTableCellStyle {
  case none
  case trackNumber
  case artwork
}

// MARK: - PlayableTableCell

@MainActor
class PlayableTableCell: BasicTableCell {
  @IBOutlet
  weak var titleLabel: UILabel!
  @IBOutlet
  weak var artistLabel: UILabel!
  @IBOutlet
  weak var durationLabel: UILabel!
  @IBOutlet
  weak var entityImage: EntityImageView!
  @IBOutlet
  weak var trackNumberLabel: UILabel!
  @IBOutlet
  weak var downloadProgress: UIProgressView! // depricated: replaced with a spinner in the accessoryView
  @IBOutlet
  weak private var cacheIconImage: UIImageView!
  @IBOutlet
  weak private var favoriteIconImage: UIImageView!

  @IBOutlet
  weak var titleContainerLeadingConstraint: NSLayoutConstraint!
  @IBOutlet
  weak var labelTrailingCellConstraint: NSLayoutConstraint!
  @IBOutlet
  weak var cacheTrailingCellConstaint: NSLayoutConstraint!
  @IBOutlet
  weak var durationTrailingCellConstraint: NSLayoutConstraint!
  @IBOutlet
  weak var optionsButton: UIButton!
  @IBOutlet
  weak var deleteButton: UIButton!
  @IBOutlet
  weak var playOverArtworkButton: UIButton!
  @IBOutlet
  weak var playOverNumberButton: UIButton!

  static let rowHeight: CGFloat = 48 + margin.bottom + margin.top
  private static let touchAnimation = 0.4

  private var style = PlayableTableCellStyle.none
  private var playerIndexCb: GetPlayerIndexFromTableCellCallback?
  private var playContextCb: GetPlayContextFromTableCellCallback?
  private var playable: AbstractPlayable?
  private var download: Download?
  private var rootView: UIViewController?
  private var playIndicator: PlayIndicator?
  private var isDislayAlbumTrackNumberStyle: Bool = false
  private var displayMode: DisplayMode = .normal
  #if targetEnvironment(macCatalyst) // ok
    private var hoverGestureRecognizer: UIHoverGestureRecognizer!
    private var doubleTapGestureRecognizer: UITapGestureRecognizer!
    private var isHovered = false
    private var isNotificationRegistered = false
  #else
    private var singleTapGestureRecognizer: UITapGestureRecognizer!
  #endif

  public var isMarked = false
  private var isDeleteButtonAllowedToBeVisible: Bool {
    (traitCollection.userInterfaceIdiom == .mac) && (playerIndexCb != nil)
  }

  override func awakeFromNib() {
    super.awakeFromNib()
    // This must be called in Main thread
    MainActor.assumeIsolated {
      playContextCb = nil
      #if targetEnvironment(macCatalyst) // ok
        hoverGestureRecognizer = UIHoverGestureRecognizer(
          target: self,
          action: #selector(hovering(_:))
        )
        self.addGestureRecognizer(hoverGestureRecognizer)
        isHovered = false
        doubleTapGestureRecognizer = UITapGestureRecognizer(
          target: self,
          action: #selector(doubleTap)
        )
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTapGestureRecognizer)
      #else
        singleTapGestureRecognizer = UITapGestureRecognizer(
          target: self,
          action: #selector(singleTap)
        )
        singleTapGestureRecognizer.numberOfTapsRequired = 1
        // to handle double and single tap recognizer in parallel:
        // singleTapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
        self.addGestureRecognizer(singleTapGestureRecognizer)
      #endif

      style = PlayableTableCellStyle.none
      deleteButton.tintColor = .red
      playOverArtworkButton.layer.backgroundColor = UIColor.imageOverlayBackground.cgColor
      playOverArtworkButton.layer.cornerRadius = CornerRadius.small.asCGFloat
      selectionStyle = .none
      downloadProgress.isHidden = true
      resetForReuse()
    }
  }

  func resetForReuse() {
    playIndicator?.reset()
    deleteButton.isHidden = true
    playOverArtworkButton.isHidden = true
    playOverNumberButton.isHidden = true
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    resetForReuse()
  }

  #if targetEnvironment(macCatalyst) // ok
    private func register() {
      guard !isNotificationRegistered else { return }
      appDelegate.notificationHandler.register(
        self,
        selector: #selector(playerPlay(notification:)),
        name: .playerPlay,
        object: nil
      )
      appDelegate.notificationHandler.register(
        self,
        selector: #selector(playerPause(notification:)),
        name: .playerPause,
        object: nil
      )
      appDelegate.notificationHandler.register(
        self,
        selector: #selector(playerStop(notification:)),
        name: .playerStop,
        object: nil
      )
      isNotificationRegistered = true
    }
  #endif

  func display(
    playable: AbstractPlayable,
    displayMode: DisplayMode = .normal,
    playContextCb: GetPlayContextFromTableCellCallback?,
    rootView: UIViewController,
    playerIndexCb: GetPlayerIndexFromTableCellCallback? = nil,
    isDislayAlbumTrackNumberStyle: Bool = false,
    download: Download? = nil,
    isMarked: Bool = false
  ) {
    if playIndicator?.rootViewTypeName != rootView.typeName {
      playIndicator = PlayIndicator(rootViewTypeName: rootView.typeName)
    }

    self.playable = playable
    self.displayMode = displayMode
    self.playContextCb = playContextCb
    self.playerIndexCb = playerIndexCb
    self.rootView = rootView
    self.isDislayAlbumTrackNumberStyle = isDislayAlbumTrackNumberStyle
    self.download = download
    self.isMarked = isMarked

    #if targetEnvironment(macCatalyst) // ok
      hoverGestureRecognizer.isEnabled = (displayMode == .normal)
      isHovered = false
      doubleTapGestureRecognizer.isEnabled = (displayMode == .normal)
      register()
    #else
      singleTapGestureRecognizer.isEnabled = (displayMode == .normal)
    #endif
    backgroundColor = .systemBackground
    refresh()
  }

  private func configureStyle(playable: AbstractPlayable, newStyle: PlayableTableCellStyle) {
    // adjust style only if it has changed
    guard newStyle != style else { return }

    switch newStyle {
    case .trackNumber:
      configureTrackNumberLabel()
      playIndicator?.willDisplayIndicatorCB = { [weak self] () in
        guard let self = self else { return }
        trackNumberLabel.text = ""
      }
      playIndicator?.willHideIndicatorCB = { [weak self] () in
        guard let self = self else { return }
        configureTrackNumberLabel()
      }
      trackNumberLabel.isHidden = false
      entityImage.isHidden = true
      titleContainerLeadingConstraint.constant = 10 + 21 + 16 // heart + track lable width + offset
    case .artwork:
      playIndicator?.willDisplayIndicatorCB = nil
      playIndicator?.willHideIndicatorCB = nil
      trackNumberLabel.isHidden = true
      entityImage.isHidden = false
      titleContainerLeadingConstraint.constant = 10 + 48 + 8 // heart + artwork width + offset
    case .none:
      break // do nothing
    }
  }

  private func configurePlayIndicator(playable: AbstractPlayable?) {
    guard let playable = playable else {
      playIndicator?.reset()
      return
    }

    if isDislayAlbumTrackNumberStyle {
      playIndicator?.display(playable: playable, rootView: trackNumberLabel)
    } else {
      if playerIndexCb == nil {
        playIndicator?.display(playable: playable, rootView: entityImage, isOnImage: true)
      } else {
        // don't show play indicator on PopupPlayer
        playIndicator?.reset()
      }
    }
  }

  func refresh() {
    guard let playable = playable else { return }
    titleLabel.text = playable.title
    artistLabel.text = playable.creatorName

    configureStyle(
      playable: playable,
      newStyle: isDislayAlbumTrackNumberStyle ? .trackNumber : .artwork
    )
    entityImage.display(
      theme: appDelegate.storage.settings.accounts.getSetting(playable.account?.info).read
        .themePreference,
      container: playable
    )
    configurePlayIndicator(playable: playable)

    if displayMode == .selection {
      let img = UIImageView(image: isMarked ? .checkmark : .circle)
      img.tintColor = isMarked ? appDelegate.storage.settings.accounts
        .getSetting(playable.account?.info).read
        .themePreference
        .asColor : .secondaryLabelColor
      accessoryView = img
    } else if displayMode == .add {
      let img = UIImageView(image: isMarked ? .checkmark : .plusCircle)
      img.tintColor = appDelegate.storage.settings.accounts.getSetting(playable.account?.info).read
        .themePreference
        .asColor
      accessoryView = img
    } else if displayMode == .reorder || playerIndexCb != nil {
      let img = UIImageView(image: .bars)
      img.tintColor = .labelColor
      accessoryView = img
    } else if let download = download {
      if download.error != nil {
        let img = UIImageView(image: .exclamation)
        img.tintColor = .labelColor
        accessoryView = img
      } else if download.isFinishedSuccessfully {
        let img = UIImageView(image: .check)
        img.tintColor = .labelColor
        accessoryView = img
      } else if download.isDownloading {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        spinner.tintColor = .labelColor
        accessoryView = spinner
      } else {
        accessoryView = nil
      }
    } else {
      accessoryView = nil
    }

    refreshSubtitleColor()
    refreshCacheAndDuration()
  }

  private func configureTrackNumberLabel() {
    guard let playable = playable else { return }
    trackNumberLabel.text = playable.track > 0 ? "\(playable.track)" : ""
  }

  func refreshCacheAndDuration() {
    guard let playable = playable else { return }
    favoriteIconImage.isHidden = !playable.isFavorite
    favoriteIconImage.tintColor = .red

    let isDurationVisible = !playable.isRadio &&
      (
        appDelegate.storage.settings.user
          .isShowSongDuration || (traitCollection.horizontalSizeClass == .regular)
      )
    let cacheIconWidth = (traitCollection.horizontalSizeClass == .regular) ? 17.0 : 15.0
    let durationWidth = (
      traitCollection.horizontalSizeClass == .regular &&
        traitCollection.userInterfaceIdiom != .mac
    ) ? 49.0 : 40.0
    let isDisplayOptionButton = (playContextCb != nil) && (playerIndexCb == nil)
    let durationTrailing = isDisplayOptionButton ?
      ((traitCollection.horizontalSizeClass == .regular) ? 30 : 30.0) : 0.0

    optionsButton.isHidden = !isDisplayOptionButton
    if isDisplayOptionButton {
      optionsButton.showsMenuAsPrimaryAction = true
      optionsButton.imageView?.tintColor = .label
      if let rootView = rootView {
        let playContext = playContextCb != nil ? { self.playContextCb?(self) } : nil
        let playIndex = playerIndexCb != nil ? { self.playerIndexCb?(self) } : nil
        optionsButton.menu = UIMenu.lazyMenu {
          EntityPreviewActionBuilder(
            container: playable,
            on: rootView,
            playContextCb: playContext,
            playerIndexCb: playIndex
          ).createMenuActions()
        }
      }
    }

    // macOS & iPadOS regular
    // |title|x|Cache|4|Duration| ... |
    // |title|        80        | 30  |
    // compact
    // |title|4|Cache|4|Duration| ... |
    // |title|4|  15 |4|   40   | 30  |
    // |title|4|  15 |-|   --   | 30  |
    // |title|8|  -- |-|   40   | 30  |
    if traitCollection.horizontalSizeClass == .regular {
      labelTrailingCellConstraint.constant = 80 + durationTrailing
    } else {
      var lableTrailing = durationTrailing
      if playable.isCached, isDurationVisible {
        lableTrailing += 4 + cacheIconWidth + 4 + durationWidth
      } else if playable.isCached {
        lableTrailing += 4 + cacheIconWidth
      } else if isDurationVisible {
        lableTrailing += 8 + durationWidth
      }
      labelTrailingCellConstraint.constant = lableTrailing
    }

    durationTrailingCellConstraint.constant = durationTrailing
    cacheIconImage.isHidden = !playable.isCached
    cacheTrailingCellConstaint
      .constant = durationTrailing + (isDurationVisible ? (4.0 + durationWidth) : 0.0)
    durationLabel.isHidden = !isDurationVisible
    if isDurationVisible {
      durationLabel.text = playable.duration.asColonDurationString
    }
  }

  private func refreshSubtitleColor() {
    if playerIndexCb != nil {
      cacheIconImage.tintColor = UIColor.labelColor
      artistLabel.textColor = UIColor.labelColor
      durationLabel.textColor = UIColor.labelColor
    } else {
      cacheIconImage.tintColor = UIColor.secondaryLabelColor
      artistLabel.textColor = UIColor.secondaryLabelColor
      durationLabel.textColor = UIColor.secondaryLabelColor
    }
  }

  func playThisSong() {
    guard let playable = playable else { return }
    if let playerIndex = playerIndexCb?(self) {
      appDelegate.player.play(playerIndex: playerIndex)
    } else if let context = playContextCb?(self),
              playable.isCached || appDelegate.storage.settings.user.isOnlineMode {
      animateActivation()
      hideSearchBarKeyboardInRootView()
      Haptics.success.vibrate(isHapticsEnabled: appDelegate.storage.settings.user.isHapticsEnabled)
      appDelegate.player.play(context: context)
    }
  }

  private func hideSearchBarKeyboardInRootView() {
    if let basicRootView = rootView as? BasicTableViewController {
      basicRootView.searchController.searchBar.endEditing(true)
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    playIndicator?.applyStyle()
  }

  #if targetEnvironment(macCatalyst) // ok
    @IBAction
    func deleteButtonPressed(_ sender: Any) {
      if let playerIndexCb = playerIndexCb,
         let playerIndex = playerIndexCb(self),
         let queueVC = rootView as? QueueVC,
         let tableView = queueVC.tableView {
        queueVC.tableView(tableView, commit: .delete, forRowAt: playerIndex.asIndexPath)
      }
      if let playerIndexCb = playerIndexCb,
         let playerIndex = playerIndexCb(self),
         let popupPlayerVC = rootView as? PopupPlayerVC,
         let tableView = popupPlayerVC.tableView {
        popupPlayerVC.tableView(tableView, commit: .delete, forRowAt: playerIndex.asIndexPath)
      }
    }

    @IBAction
    func playButtonPressed(_ sender: Any) {
      if appDelegate.player.currentlyPlaying == playable,
         appDelegate.player.isPlaying {
        appDelegate.player.pause()
      } else if appDelegate.player.currentlyPlaying == playable {
        appDelegate.player.play()
      } else {
        playThisSong()
      }
      refreshHoverStyle()
    }

    func refreshHoverStyle() {
      if isHovered {
        playIndicator?.reset()
        if isDeleteButtonAllowedToBeVisible {
          deleteButton.isHidden = false
        } else {
          var buttonImg = UIImage()
          if appDelegate.player.currentlyPlaying == playable,
             appDelegate.player.isPlaying {
            if appDelegate.player.isStopInsteadOfPause {
              buttonImg = UIImage.stop
            } else {
              buttonImg = UIImage.pause
            }
          } else {
            buttonImg = UIImage.play
          }
          if isDislayAlbumTrackNumberStyle {
            trackNumberLabel.isHidden = true
            playOverNumberButton.isHidden = false
            playOverNumberButton.imageView?.tintColor = appDelegate.storage.settings.accounts
              .getSetting(playable?.account?.info).read.themePreference
              .asColor
            playOverNumberButton.setImage(buttonImg, for: UIControl.State.normal)
            playOverArtworkButton.isHidden = true
          } else {
            playOverArtworkButton.isHidden = false
            playOverArtworkButton.imageView?.tintColor = .white
            playOverArtworkButton.setImage(buttonImg, for: UIControl.State.normal)
            playOverNumberButton.isHidden = true
          }
        }
        cacheIconImage.tintColor = appDelegate.storage.settings.accounts
          .getSetting(playable?.account?.info).read.themePreference.asColor
        optionsButton.imageView?.tintColor = appDelegate.storage.settings.accounts
          .getSetting(playable?.account?.info).read.themePreference.asColor
        backgroundColor = (rootView is PopupPlayerVC) ?
          .secondarySystemGroupedBackground.withAlphaComponent(0.2) :
          .secondarySystemGroupedBackground
      } else {
        playOverArtworkButton.isHidden = true
        playOverNumberButton.isHidden = true
        if isDislayAlbumTrackNumberStyle {
          trackNumberLabel.isHidden = false
        }
        configurePlayIndicator(playable: playable)
        deleteButton.isHidden = true
        refreshSubtitleColor()
        optionsButton.imageView?.tintColor = .label
        backgroundColor = .clear
      }
    }

    @objc
    func hovering(_ recognizer: UIHoverGestureRecognizer) {
      switch recognizer.state {
      case .began:
        isHovered = true
        refreshHoverStyle()
      case .ended:
        isHovered = false
        refreshHoverStyle()
      default:
        if !isHovered {
          isHovered = true
          refreshHoverStyle()
        }
      }
    }

    @objc
    func doubleTap(sender: UITapGestureRecognizer) {
      switch sender.state {
      case .ended:
        if displayMode == .normal {
          playThisSong()
        }
      default:
        break
      }
    }

    @objc
    private func playerPlay(notification: Notification) {
      guard isHovered else { return }
      refreshHoverStyle()
    }

    @objc
    private func playerPause(notification: Notification) {
      guard isHovered else { return }
      refreshHoverStyle()
    }

    @objc
    private func playerStop(notification: Notification) {
      guard isHovered else { return }
      refreshHoverStyle()
    }

  #else

    @objc
    func singleTap(sender: UITapGestureRecognizer) {
      switch sender.state {
      case .ended:
        if displayMode == .normal {
          playThisSong()
        }
      default:
        break
      }
    }
  #endif
}
