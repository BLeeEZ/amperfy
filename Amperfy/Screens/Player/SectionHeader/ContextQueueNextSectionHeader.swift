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
  private var playerHandler: PlayerUIHandler?

  @IBOutlet
  weak var queueNameLabel: UILabel!
  @IBOutlet
  weak var contextNameLabel: MarqueeLabel!

  @IBOutlet
  weak var shuffleButton: UIButton!
  @IBOutlet
  weak var repeatButton: UIButton!
  
  private var clearQueueButton: UIButton!

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.layoutMargins = Self.margin
    self.player = appDelegate.player
    player.addNotifier(notifier: self)
    self.playerHandler = PlayerUIHandler(player: player, style: .popupPlayer)
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    setupClearQueueButton()
  }
  
  private func setupClearQueueButton() {
    clearQueueButton = UIButton(type: .system)
    clearQueueButton.translatesAutoresizingMaskIntoConstraints = false
    
    let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
    clearQueueButton.setImage(UIImage(systemName: "trash", withConfiguration: config), for: .normal)
    clearQueueButton.tintColor = .label
    
    clearQueueButton.addTarget(self, action: #selector(pressedClearQueue), for: .touchUpInside)
    
    addSubview(clearQueueButton)
    
    NSLayoutConstraint.activate([
      clearQueueButton.widthAnchor.constraint(equalToConstant: 28),
      clearQueueButton.heightAnchor.constraint(equalToConstant: 28),
      clearQueueButton.centerYAnchor.constraint(equalTo: shuffleButton.centerYAnchor),
      clearQueueButton.trailingAnchor.constraint(equalTo: shuffleButton.leadingAnchor, constant: -16),
    ])
  }

  func prepare(toWorkOnRootView: PopupPlayerVC?) {
    rootView = toWorkOnRootView
    contextNameLabel.applyAmperfyStyle()
    refresh()
  }

  func refresh() {
    contextNameLabel.text = "\(player.contextName)"
    refreshCurrentlyPlayingInfo()
    playerHandler?.refreshRepeatButton(repeatButton: repeatButton)
    playerHandler?.refreshShuffleButton(shuffleButton: shuffleButton)
  }

  func refreshCurrentlyPlayingInfo() {
    switch player.playerMode {
    case .music:
      repeatButton.isHidden = false
      shuffleButton.isHidden = false
      clearQueueButton?.isHidden = false
    case .podcast:
      repeatButton.isHidden = true
      shuffleButton.isHidden = true
      clearQueueButton?.isHidden = true
    }
  }

  @IBAction
  func pressedShuffle(_ sender: Any) {
    playerHandler?.shuffleButtonPushed()
    playerHandler?.refreshShuffleButton(shuffleButton: shuffleButton)
    rootView?.scrollToCurrentlyPlayingRow()
  }

  @IBAction
  func pressedRepeat(_ sender: Any) {
    playerHandler?.repeatButtonPushed()
    playerHandler?.refreshRepeatButton(repeatButton: repeatButton)
  }
  
  @objc
  func pressedClearQueue(_ sender: Any) {
    let alert = UIAlertController(
      title: "Clear Queue",
      message: "Are you sure you want to clear the entire queue?",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
      self?.player.clearQueues()
      self?.rootView?.reloadData()
    })
    
    if let viewController = rootView ?? window?.rootViewController {
      viewController.present(alert, animated: true)
    }
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
    playerHandler?.refreshShuffleButton(shuffleButton: shuffleButton)
  }

  func didRepeatChange() {
    playerHandler?.refreshRepeatButton(repeatButton: repeatButton)
  }

  func didPlaybackRateChange() {}
}
