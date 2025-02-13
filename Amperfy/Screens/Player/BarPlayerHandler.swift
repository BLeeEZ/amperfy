//
//  BarPlayerHandler.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 25.02.24.
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
import LNPopupController
import UIKit

// MARK: - BarPlayerHandler

@MainActor
class BarPlayerHandler {
  let player: PlayerFacade
  var isPopupBarDisplayed = false
  let splitVC: SplitVC
  var activeViewContainer: UIViewController?

  init(player: PlayerFacade, splitVC: SplitVC) {
    self.player = player
    self.splitVC = splitVC
    self.player.addNotifier(notifier: self)
  }

  func changeTo(vc: UIViewController) {
    hidePopupPlayer()
    activeViewContainer = vc
    configureBar(vc: vc)
  }

  private func configureBar(vc: UIViewController) {
    let appDelegate = (UIApplication.shared.delegate as! AppDelegate)
    vc.popupBar.tintColor = appDelegate.storage.settings.themePreference.asColor
    vc.popupBar.imageView.layer.cornerRadius = 5
    vc.popupBar.progressViewStyle = .bottom
    if #available(iOS 17, *) {
      vc.popupBar.barStyle = .floating
    } else {
      vc.popupBar.barStyle = .prominent
    }

    let appearance = LNPopupBarAppearance()
    appearance.subtitleTextAttributes = AttributeContainer()
      .foregroundColor(.label)
    vc.popupBar.standardAppearance = appearance
    vc.popupContentView.popupCloseButtonStyle = .chevron
    vc.popupInteractionStyle = .snap
    isPopupBarDisplayed = false
    handlePopupBar()
  }

  private func handlePopupBar() {
    if player.isPopupBarAllowedToHide {
      hidePopupPlayer()
    } else {
      displayPopupBar()
    }
  }

  private func displayPopupBar() {
    guard !isPopupBarDisplayed,
          !player.isPopupBarAllowedToHide,
          let vc = activeViewContainer
    else { return }
    let popupPlayer = PopupPlayerVC()
    popupPlayer.hostingSplitVC = splitVC
    isPopupBarDisplayed = true
    vc.presentPopupBar(with: popupPlayer, animated: true, completion: nil)
  }

  private func hidePopupPlayer() {
    guard isPopupBarDisplayed else { return }
    isPopupBarDisplayed = false
    guard let vc = activeViewContainer else { return }
    vc.dismissPopupBar(animated: false, completion: nil)
  }
}

// MARK: MusicPlayable

extension BarPlayerHandler: MusicPlayable {
  func didStartPlayingFromBeginning() {}
  func didStartPlaying() {
    handlePopupBar()
  }

  func didPause() {
    handlePopupBar()
  }

  func didStopPlaying() {
    handlePopupBar()
  }

  func didElapsedTimeChange() {}
  func didPlaylistChange() {
    handlePopupBar()
  }

  func didArtworkChange() {}
  func didShuffleChange() {}
  func didRepeatChange() {}
  func didPlaybackRateChange() {}
}
