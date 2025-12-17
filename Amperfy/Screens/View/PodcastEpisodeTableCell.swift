//
//  PodcastEpisodeTableCell.swift
//  Amperfy
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

import AmperfyKit
import UIKit

class PodcastEpisodeTableCell: BasicTableCell {
  @IBOutlet
  weak var podcastEpisodeLabel: UILabel!
  @IBOutlet
  weak var entityImage: EntityImageView!
  @IBOutlet
  weak var infoLabel: UILabel!
  @IBOutlet
  weak var descriptionLabel: UILabel!
  @IBOutlet
  weak var playEpisodeButton: UIButton!
  @IBOutlet
  weak var optionsButton: UIButton!
  @IBOutlet
  weak var showDescriptionButton: UIButton!
  @IBOutlet
  weak var cacheIconImage: UIImageView!
  @IBOutlet
  weak var playProgressBar: UIProgressView!
  @IBOutlet
  weak var playProgressLabel: UILabel!
  @IBOutlet
  weak var playProgressLabelPlayButtonDistance: NSLayoutConstraint!

  static let rowHeight: CGFloat = 143.0 + margin.bottom + margin.top

  private var episode: PodcastEpisode?
  private var rootView: UIViewController?
  private var playIndicator: PlayIndicator?

  func display(episode: PodcastEpisode, rootView: UIViewController) {
    if playIndicator == nil {
      playIndicator = PlayIndicator(rootViewTypeName: rootView.typeName)
    }
    self.episode = episode
    self.rootView = rootView
    optionsButton.showsMenuAsPrimaryAction = true
    optionsButton.menu = UIMenu.lazyMenu { EntityPreviewActionBuilder(
      container: episode,
      on: rootView,
      playContextCb: { () in PlayContext(containable: episode) }
    ).createMenuActions() }
    refresh()
  }

  func refresh() {
    guard let episode = episode else { return }
    configurePlayEpisodeButton()
    playIndicator?.display(playable: episode, rootView: playEpisodeButton)
    playIndicator?.willDisplayIndicatorCB = { [weak self] () in
      guard let self = self else { return }
      configurePlayEpisodeButton()
    }
    playIndicator?.willHideIndicatorCB = { [weak self] () in
      guard let self = self else { return }
      configurePlayEpisodeButton()
    }
    podcastEpisodeLabel.text = episode.title
    entityImage.display(
      theme: appDelegate.storage.settings.accounts.getSetting(episode.account?.info).read
        .themePreference,
      container: episode
    )

    infoLabel.text = "\(episode.publishDate.asShortDayMonthString)"
    descriptionLabel.text = episode.depiction ?? ""

    var progressText = ""
    if let remainingTime = episode.remainingTimeInSec,
       let playProgressPercent = episode.playProgressPercent {
      progressText = "\(remainingTime.asDurationString) left"
      playProgressBar.isHidden = false
      playProgressLabelPlayButtonDistance.constant = (2 * 8.0) + playProgressBar.frame.width
      playProgressBar.progress = playProgressPercent
    } else {
      progressText = "\(episode.duration.asDurationString)"
      playProgressBar.isHidden = true
      playProgressLabelPlayButtonDistance.constant = 8.0
    }
    if !episode.isAvailableToUser() {
      progressText += " \(CommonString.oneMiddleDot) \(episode.userStatus.description)"
    }
    playProgressLabel.text = progressText
    if episode.isCached {
      cacheIconImage.isHidden = false
      playProgressLabel.textColor = .secondaryLabelColor
    } else {
      cacheIconImage.isHidden = true
      playProgressLabel.textColor = .secondaryLabelColor
    }
    backgroundColor = .systemBackground
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    playIndicator?.reset()
  }

  private func configurePlayEpisodeButton() {
    guard let episode = episode else { return }
    if episode == appDelegate.player.currentlyPlaying {
      playEpisodeButton.setImage(nil, for: .normal)
      playEpisodeButton.isEnabled = false
    } else if episode.isAvailableToUser() {
      playEpisodeButton.setImage(.play, for: .normal)
      playEpisodeButton.isEnabled = true
    } else {
      playEpisodeButton.setImage(.ban, for: .normal)
      playEpisodeButton.isEnabled = false
    }
  }

  @IBAction
  func playEpisodeButtonPressed(_ sender: Any) {
    guard let episode = episode else { return }
    appDelegate.player.play(context: PlayContext(containable: episode))
  }

  @IBAction
  func showDescriptionButtonPressed(_ sender: Any) {
    Haptics.light.vibrate(isHapticsEnabled: appDelegate.storage.settings.user.isHapticsEnabled)
    guard let episode = episode, let rootView = rootView else { return }
    let showDescriptionVC = PlainDetailsVC()
    showDescriptionVC.display(podcastEpisode: episode, on: rootView)
    rootView.present(showDescriptionVC, animated: true)
  }
}
