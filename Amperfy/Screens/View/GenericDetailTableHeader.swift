//
//  GenericDetailTableHeader.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 19.02.22.
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

import AmperfyKit
import UIKit

// MARK: - DetailHeaderConfiguration

struct DetailHeaderConfiguration {
  var entityContainer: PlayableContainable
  var rootView: UIViewController
  var tableView: UITableView
  var playShuffleInfoConfig: PlayShuffleInfoConfiguration?
  var descriptionText: String?
}

// MARK: - GenericDetailTableHeader

class GenericDetailTableHeader: UIView {
  @IBOutlet
  weak var entityImage: EntityImageView!
  @IBOutlet
  weak var titleLabel: UILabel!
  @IBOutlet
  weak var nameTextField: UITextField!
  @IBOutlet
  weak var subtitleView: UIView!
  @IBOutlet
  weak var subtitleLabel: UILabel!
  @IBOutlet
  weak var infoLabel: UILabel!
  @IBOutlet
  weak var playShuffleInfoPlaceholderStack: UIStackView!
  @IBOutlet
  weak var descriptionLabel: UILabel!
  @IBOutlet
  weak var playShuffleInfoContainerView: UIView!

  @IBOutlet
  weak var titlePlayButtonContainerHeightConstraint: NSLayoutConstraint!

  var playShuffleInfoView: LibraryElementDetailTableHeaderView?
  var isEditing = false

  static let frameHeightCompact: CGFloat = 400.0
  static let frameHeightRegular: CGFloat = 240.0
  static func frameHeight(traitCollection: UITraitCollection) -> CGFloat {
    if traitCollection.horizontalSizeClass == .compact {
      return GenericDetailTableHeader.frameHeightCompact
    } else {
      return GenericDetailTableHeader.frameHeightRegular
    }
  }

  static let frameHeightForDescription: CGFloat = 85.0
  private static let titlePlayButtonContainerHeightCompact: CGFloat = 155.0
  private static let titlePlayButtonContainerHeightWithoutButtons: CGFloat =
    titlePlayButtonContainerHeightCompact - LibraryElementDetailTableHeaderView.frameHeight

  private var config: DetailHeaderConfiguration?

  public static func createTableHeader(configuration: DetailHeaderConfiguration)
    -> GenericDetailTableHeader? {
    configuration.tableView.tableHeaderView = UIView(frame: CGRect(
      x: 0,
      y: 0,
      width: configuration.rootView.view.bounds.size.width,
      height: GenericDetailTableHeader
        .frameHeight(traitCollection: configuration.rootView.traitCollection)
    ))
    let genericDetailTableHeaderView = ViewCreator<GenericDetailTableHeader>
      .createFromNib(withinFixedFrame: CGRect(
        x: 0,
        y: 0,
        width: configuration.rootView.view.bounds.size.width,
        height: GenericDetailTableHeader
          .frameHeight(traitCollection: configuration.rootView.traitCollection)
      ))!
    genericDetailTableHeaderView.prepare(configuration: configuration)
    configuration.tableView.tableHeaderView?.addSubview(genericDetailTableHeaderView)
    return genericDetailTableHeaderView
  }

  func prepare(configuration: DetailHeaderConfiguration) {
    config = configuration
    config?.playShuffleInfoConfig?.isEmbeddedInOtherView = true
    titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    nameTextField.setContentCompressionResistancePriority(.required, for: .vertical)
    subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    // Fix attributed text ignores tint
    subtitleLabel.textColor = .tintColor
    infoLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    layoutMargins = UIView.defaultMarginTopElement
    if let playShuffleInfoConfig = config?.playShuffleInfoConfig {
      playShuffleInfoView = ViewCreator<LibraryElementDetailTableHeaderView>.createFromNib()
      playShuffleInfoPlaceholderStack.addArrangedSubview(playShuffleInfoView!)
      playShuffleInfoView?.prepare(configuration: playShuffleInfoConfig)
      playShuffleInfoContainerView.isHidden = false
    } else {
      playShuffleInfoContainerView.isHidden = true
    }
    if let descriptionText = configuration.descriptionText {
      descriptionLabel.text = descriptionText
      descriptionLabel.isHidden = false
    } else {
      descriptionLabel.isHidden = true
    }
    refresh()
    registerForTraitChanges(
      [UITraitUserInterfaceStyle.self, UITraitHorizontalSizeClass.self],
      handler: { (self: Self, previousTraitCollection: UITraitCollection) in
        self.applyTraitCollectionChange()
      }
    )
  }

  func refresh() {
    guard let config = config else { return }
    let entityContainer = config.entityContainer
    entityImage.display(
      theme: appDelegate.storage.settings.accounts.getSetting(entityContainer.account?.info).read
        .themePreference,
      container: entityContainer
    )
    titleLabel.text = entityContainer.name
    subtitleView.isHidden = entityContainer.subtitle == nil
    subtitleLabel.text = entityContainer.subtitle

    var isCountInfoHidden = false
    if let playShuffleInfoConfig = config.playShuffleInfoConfig {
      isCountInfoHidden = !playShuffleInfoConfig.isInfoAlwaysHidden && playShuffleInfoConfig
        .isShuffleHidden && (traitCollection.horizontalSizeClass == .regular)
    }
    let detailLevel = isCountInfoHidden ? DetailType.noCountInfo : DetailType.long

    let infoText = entityContainer.info(
      for: entityContainer.account?.apiType.asServerApiType,
      details: DetailInfoType(type: detailLevel, settings: appDelegate.storage.settings)
    )
    infoLabel.isHidden = infoText.isEmpty
    infoLabel.text = infoText

    titleLabel.textAlignment = (traitCollection.horizontalSizeClass == .compact) ? .center : .left
    nameTextField
      .textAlignment = (traitCollection.horizontalSizeClass == .compact) ? .center : .left
    subtitleLabel
      .textAlignment = (traitCollection.horizontalSizeClass == .compact) ? .center : .left
    infoLabel.textAlignment = (traitCollection.horizontalSizeClass == .compact) ? .center : .left

    if isEditing {
      titleLabel.isHidden = true
      nameTextField.isHidden = false
      nameTextField.text = entityContainer.name
    } else {
      titleLabel.isHidden = false
      nameTextField.isHidden = true
    }

    playShuffleInfoView?.refresh()
  }

  func applyTraitCollectionChange() {
    guard let config = config else { return }
    let rootView = config.rootView

    var height = (traitCollection.horizontalSizeClass == .compact) ?
      GenericDetailTableHeader.frameHeightCompact :
      GenericDetailTableHeader.frameHeightRegular
    if traitCollection.horizontalSizeClass == .compact {
      if config.playShuffleInfoConfig == nil {
        titlePlayButtonContainerHeightConstraint.constant = Self
          .titlePlayButtonContainerHeightWithoutButtons
        height -=
          (
            Self.titlePlayButtonContainerHeightCompact - Self
              .titlePlayButtonContainerHeightWithoutButtons
          )
      } else {
        titlePlayButtonContainerHeightConstraint.constant = Self
          .titlePlayButtonContainerHeightCompact
      }
    }
    if config.descriptionText != nil {
      height += GenericDetailTableHeader.frameHeightForDescription
    }
    config.tableView.tableHeaderView?.frame = CGRect(
      x: 0,
      y: 0,
      width: rootView.view.bounds.size.width,
      height: height
    )
    frame = CGRect(x: 0, y: 0, width: rootView.view.bounds.size.width, height: height)
  }

  func startEditing() {
    isEditing = true
    refresh()
  }

  func endEditing() {
    isEditing = false
    defer { refresh() }
    guard let nameText = nameTextField.text, let playlist = config?.entityContainer as? Playlist,
          nameText != playlist.name, let account = playlist.account else { return }
    playlist.name = nameText
    titleLabel.text = nameText
    guard appDelegate.storage.settings.user.isOnlineMode else { return }

    Task { @MainActor in do {
      try await self.appDelegate.getMeta(account.info).librarySyncer
        .syncUpload(playlistToUpdateName: playlist)
    } catch {
      self.appDelegate.eventLogger.report(topic: "Playlist Update Name", error: error)
    }}
  }

  @IBAction
  func subtitleButtonPressed(_ sender: Any) {
    guard let album = config?.entityContainer as? Album,
          let artist = album.artist,
          let account = album.account,
          let navController = config?.rootView.navigationController
    else { return }
    appDelegate.userStatistics.usedAction(.alertGoToAlbum)
    navController.pushViewController(
      AppStoryboard.Main.segueToArtistDetail(account: account, artist: artist),
      animated: true
    )
  }
}
