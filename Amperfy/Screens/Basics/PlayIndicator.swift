//
//  PlayIndicator.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 21.04.22.
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
import Foundation
import VYPlayIndicator

// MARK: - OverlayLayer

class OverlayLayer: CALayer {}

// MARK: - PlayIndicatorHandler

@MainActor
class PlayIndicatorHandler {
  public static let shared = PlayIndicatorHandler()

  private var indicatorDict = [String: VYPlayIndicator]()
  private var imageOverlayDict = [String: OverlayLayer]()

  static private var imageOverlayColor: CGColor {
    UIColor.imageOverlayBackground.cgColor
  }

  private init() {}

  func getIndicator(for viewControllerTypeName: String) -> VYPlayIndicator {
    var indicator = indicatorDict[viewControllerTypeName]
    if indicator == nil {
      indicator = VYPlayIndicator()
      indicatorDict[viewControllerTypeName] = indicator
      indicator!.indicatorStyle = .legacy
    }
    return indicator!
  }

  func getImageOverlay(for viewControllerTypeName: String) -> OverlayLayer {
    var imageOverlay = imageOverlayDict[viewControllerTypeName]
    if imageOverlay == nil {
      imageOverlay = OverlayLayer()
      imageOverlay?.backgroundColor = Self.imageOverlayColor
      imageOverlayDict[viewControllerTypeName] = imageOverlay
    }
    return imageOverlay!
  }
}

// MARK: - PlayIndicator

@MainActor
class PlayIndicator {
  static private let frameHeight = 20.0

  var willDisplayIndicatorCB: VoidFunctionCallback?
  var willHideIndicatorCB: VoidFunctionCallback?
  private var appDelegate: AppDelegate
  private(set) var rootViewTypeName: String
  private var rootView: UIView?
  private var playable: AbstractPlayable?
  private var isDisplayedOnImage = false
  private var isNotificationRegistered = false

  init(rootViewTypeName: String) {
    self.rootViewTypeName = rootViewTypeName
    self.appDelegate = (UIApplication.shared.delegate as! AppDelegate)
  }

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

  private func unregister() {
    guard isNotificationRegistered else { return }
    appDelegate.notificationHandler.remove(self, name: .playerPlay, object: nil)
    appDelegate.notificationHandler.remove(self, name: .playerPause, object: nil)
    appDelegate.notificationHandler.remove(self, name: .playerStop, object: nil)
    isNotificationRegistered = false
  }

  func reset() {
    unregister()
    removeIndicatorIfNeeded(force: true)
    rootView = nil
    playable = nil
  }

  func display(playable: AbstractPlayable, rootView: UIView, isOnImage: Bool = false) {
    register()
    self.playable = playable
    self.rootView = rootView
    isDisplayedOnImage = isOnImage
    applyStyle()
  }

  private func calcIndicatorFrame(rootFrame: CGRect) -> CGRect {
    var indicatorX = 0.0
    var indicatorY = 0.0
    var indicatorWidth = rootFrame.width
    var indicatorHeight = rootFrame.height
    if rootFrame.width > Self.frameHeight {
      indicatorX = (rootFrame.width - Self.frameHeight) / 2
      indicatorWidth = Self.frameHeight
    }
    if rootFrame.height > Self.frameHeight {
      indicatorY = (rootFrame.height - Self.frameHeight) / 2
      indicatorHeight = Self.frameHeight
    }
    return CGRect(x: indicatorX, y: indicatorY, width: indicatorWidth, height: indicatorHeight)
  }

  private func addIndicatorIfNeeded() {
    guard let rootView = rootView else { return }

    if playable == appDelegate.player.currentlyPlaying {
      var isAlreadyInSublayers = false
      if let rootSublayers = rootView.layer.sublayers,
         rootSublayers.contains(where: { $0 is VYPlayIndicator }) {
        isAlreadyInSublayers = true
      }
      willDisplayIndicatorCB?()
      if !isAlreadyInSublayers {
        let indicator = PlayIndicatorHandler.shared.getIndicator(for: rootViewTypeName)
        indicator.frame = calcIndicatorFrame(rootFrame: rootView.bounds)
        let imageOverlay = PlayIndicatorHandler.shared.getImageOverlay(for: rootViewTypeName)
        imageOverlay.frame = rootView.bounds

        if isDisplayedOnImage {
          rootView.layer.addSublayer(imageOverlay)
        }
        rootView.layer.addSublayer(indicator)
      }
    }
  }

  private func removeIndicatorIfNeeded(force: Bool = false) {
    guard let rootView = rootView else { return }
    if playable != appDelegate.player.currentlyPlaying || force {
      willHideIndicatorCB?()
      rootView.layer.sublayers = rootView.layer.sublayers?.filter { !($0 is VYPlayIndicator) }
      if isDisplayedOnImage {
        rootView.layer.sublayers = rootView.layer.sublayers?.filter { !($0 is OverlayLayer) }
      }
    }
  }

  func applyStyle() {
    addIndicatorIfNeeded()
    removeIndicatorIfNeeded()

    if playable == appDelegate.player.currentlyPlaying, let accountInfo = playable?.account?.info {
      let indicator = PlayIndicatorHandler.shared.getIndicator(for: rootViewTypeName)
      indicator.color = isDisplayedOnImage ? .white : appDelegate.storage.settings.accounts
        .getSetting(accountInfo).read.themePreference
        .asColor
      if appDelegate.player.isPlaying {
        if indicator.state != .playing {
          indicator.state = .playing
        }
      } else {
        if indicator.state != .paused {
          indicator.state = .paused
        }
      }
    }
  }

  @objc
  private func playerPlay(notification: Notification) {
    applyStyle()
  }

  @objc
  private func playerPause(notification: Notification) {
    applyStyle()
  }

  @objc
  private func playerStop(notification: Notification) {
    applyStyle()
  }
}
