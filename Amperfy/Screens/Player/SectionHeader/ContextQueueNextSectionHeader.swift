//
//  ContextQueueSectionHeader.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 07.02.24.
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
import MarqueeLabel
import UIKit

// MARK: - ContextQueueNextSectionHeader

class ContextQueueNextSectionHeader: UIView {
  static let frameHeight: CGFloat = 40.0 + margin.top + margin.bottom
  static let margin = UIEdgeInsets(
    top: 8,
    left: UIView.defaultMarginX,
    bottom: 8,
    right: UIView.defaultMarginX
  )

  private var player: PlayerFacade!
  private var rootView: PopupPlayerVC?

  @IBOutlet
  weak var queueNameLabel: UILabel!
  @IBOutlet
  weak var contextNameLabel: MarqueeLabel!

  @IBOutlet
  weak var shuffleButton: UIButton!
  @IBOutlet
  weak var repeatButton: UIButton!

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.layoutMargins = Self.margin
    self.player = appDelegate.player
    player.addNotifier(notifier: self)
  }

  func prepare(toWorkOnRootView: PopupPlayerVC?) {
    rootView = toWorkOnRootView
    contextNameLabel.applyAmperfyStyle()
    refresh()
  }

  func refresh() {
    contextNameLabel.text = "\(player.contextName)"
    refreshCurrentlyPlayingInfo()
    refreshRepeatButton()
    refreshShuffleButton()
  }

  func refreshCurrentlyPlayingInfo() {
    switch player.playerMode {
    case .music:
      repeatButton.isHidden = false
      shuffleButton.isHidden = false
    case .podcast:
      repeatButton.isHidden = true
      shuffleButton.isHidden = true
    }
  }

  func refreshRepeatButton() {
    repeatButton.isSelected = player.repeatMode != .off
    var config = UIButton.Configuration.player(isSelected: repeatButton.isSelected)
    switch player.repeatMode {
    case .off:
      config.image = .repeatOff
    case .all:
      config.image = .repeatAll
    case .single:
      config.image = .repeatOne
    }
    repeatButton.configuration = config
  }

  func refreshShuffleButton() {
    shuffleButton.isEnabled = appDelegate.storage.settings.isPlayerShuffleButtonEnabled
    shuffleButton.isSelected = player.isShuffle
    var config = UIButton.Configuration.player(isSelected: shuffleButton.isSelected)
    config.image = .shuffle
    shuffleButton.configuration = config
  }

  @IBAction
  func pressedShuffle(_ sender: Any) {
    player.toggleShuffle()
    refreshShuffleButton()
    rootView?.scrollToCurrentlyPlayingRow()
  }

  @IBAction
  func pressedRepeat(_ sender: Any) {
    player.setRepeatMode(player.repeatMode.nextMode)
    refreshRepeatButton()
  }
}

// MARK: MusicPlayable

extension ContextQueueNextSectionHeader: MusicPlayable {
  func didStartPlayingFromBeginning() {}

  func didStartPlaying() {}

  func didPause() {}

  func didStopPlaying() {
    refreshCurrentlyPlayingInfo()
  }

  func didElapsedTimeChange() {}

  func didPlaylistChange() {
    refresh()
  }

  func didArtworkChange() {}

  func didShuffleChange() {
    refreshShuffleButton()
  }

  func didRepeatChange() {
    refreshRepeatButton()
  }

  func didPlaybackRateChange() {}
}
