//
//  SlideOverHostingController.swift
//  Amperfy
//
//  Created by David Klopp on 29.08.24.
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
import MediaPlayer
import UIKit

#if targetEnvironment(macCatalyst)

  // A view controller with a primary view controller and a slide over view controller that can be displayed
  // from the right hand side as an overlay.
  class SlideOverHostingController: UIViewController {
    var sliderOverWidth: CGFloat = 300 {
      didSet(newValue) {
        slideOverWidthConstraint?.constant = newValue
        slideOverTrailingConstraint?.constant = newValue
      }
    }

    var _primaryViewController: UIViewController?

    var primaryViewController: UIViewController? {
      get { _primaryViewController }
      set(newValue) {
        _primaryViewController?.view.removeFromSuperview()
        _primaryViewController?.removeFromParent()
        _primaryViewController?.didMove(toParent: nil)

        guard let vc = newValue else { return }

        addChild(vc)
        view.insertSubview(vc.view, at: 0)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
          vc.view.topAnchor.constraint(equalTo: view.topAnchor),
          vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
          vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
          vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        vc.didMove(toParent: self)

        _primaryViewController = vc
      }
    }

    let slideOverViewController: SlideOverVC

    private var slideOverWidthConstraint: NSLayoutConstraint?
    private var slideOverTrailingConstraint: NSLayoutConstraint?
    private var isPresentingSlideOver: Bool {
      slideOverTrailingConstraint?.constant == 0
    }

    init(slideOverViewController: SlideOverVC) {
      self.slideOverViewController = slideOverViewController
      super.init(nibName: nil, bundle: nil)

      // Add the slide over view controller
      addChild(slideOverViewController)
      view.addSubview(slideOverViewController.view)
      self.slideOverViewController.view.translatesAutoresizingMaskIntoConstraints = false

      let wc = self.slideOverViewController.view.widthAnchor
        .constraint(equalToConstant: sliderOverWidth)
      let tc = self.slideOverViewController.view.trailingAnchor.constraint(
        equalTo: view.trailingAnchor,
        constant: sliderOverWidth
      )

      NSLayoutConstraint.activate([
        self.slideOverViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
        self.slideOverViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        wc,
        tc,
      ])

      self.slideOverWidthConstraint = wc
      self.slideOverTrailingConstraint = tc

      self.slideOverViewController.didMove(toParent: self)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
      super.viewDidLoad()

      appDelegate.player.addNotifier(notifier: self)

      // Listen for setting changes to adjust the toolbar and slide over menu
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(settingsDidChange),
        name: UserDefaults.didChangeNotification,
        object: nil
      )
    }

    override func viewIsAppearing(_ animated: Bool) {
      super.viewIsAppearing(animated)
      setupToolbar()
    }

    private lazy var skipBackwardBarButton: UIBarButtonItem = {
      let player = appDelegate.player
      return SkipBackwardBarButton(player: player)
    }()

    private lazy var previousBarButton: UIBarButtonItem = {
      let player = appDelegate.player
      return PreviousBarButton(player: player)
    }()

    private lazy var nextBarButton: UIBarButtonItem = {
      let player = appDelegate.player
      return NextBarButton(player: player)
    }()

    private lazy var skipForwardBarButton: UIBarButtonItem = {
      let player = appDelegate.player
      return SkipForwardBarButton(player: player)
    }()

    private lazy var shuffleButton: UIBarButtonItem = {
      let player = appDelegate.player
      return ShuffleBarButton(player: player)
    }()

    private lazy var shufflePlaceholderButton: UIBarButtonItem = {
      SpaceBarItem(fixedSpace: CustomBarButton.defaultSize.width)
    }()

    private lazy var repeatButton: UIBarButtonItem = {
      let player = appDelegate.player
      return RepeatBarButton(player: player)
    }()

    private lazy var repeatPlaceholderButton: UIBarButtonItem = {
      SpaceBarItem(fixedSpace: CustomBarButton.defaultSize.width)
    }()

    private func setupToolbar() {
      guard let splitViewController = splitViewController as? SplitVC else { return }
      let player = appDelegate.player

      // Add the media player controls to the view's navigation item
      navigationItem.leftItemsSupplementBackButton = false
      let defaultSpacing: CGFloat = 10

      navigationItem.leftBarButtonItems = [
        SpaceBarItem(fixedSpace: defaultSpacing),
        shuffleButton,
        shufflePlaceholderButton,
        skipBackwardBarButton,
        previousBarButton,
        PlayBarButton(player: player),
        nextBarButton,
        skipForwardBarButton,
        repeatButton,
        repeatPlaceholderButton,
        SpaceBarItem(minSpace: defaultSpacing),
        NowPlayingBarItem(player: player, splitViewController: splitViewController),
        SpaceBarItem(),
        VolumeBarItem(player: player),
        SpaceBarItem(),
        AirplayBarButton(),
        QueueBarButton(splitViewController: splitViewController),
        SpaceBarItem(fixedSpace: defaultSpacing),
      ]

      updateButtonVisibility()
      navigationItem.leftBarButtonItems?.forEach { ($0 as? Refreshable)?.reload() }
    }

    private func updateButtonVisibility() {
      let isShuffleEnabled = appDelegate.storage.settings.isPlayerShuffleButtonEnabled &&
        (appDelegate.player.playerMode == .music)
      let isRepeatEnabled = appDelegate.player.playerMode == .music

      if #available(macCatalyst 16.0, *) {
        // We can not remove toolbar items in `mac` style, therefore we hide them
        self.skipBackwardBarButton.isHidden = appDelegate.player.playerMode == .music
        self.previousBarButton.isHidden = appDelegate.player.playerMode == .podcast
        self.nextBarButton.isHidden = appDelegate.player.playerMode == .podcast
        self.skipForwardBarButton.isHidden = appDelegate.player.playerMode == .music

        self.shuffleButton.isHidden = !isShuffleEnabled
        self.shufflePlaceholderButton.isHidden = isShuffleEnabled
        self.repeatButton.isHidden = !isRepeatEnabled
        self.repeatPlaceholderButton.isHidden = isRepeatEnabled
      } else {
        // Below 16.0 there is no `mac` style and .isHidden is not available.
        if let index = navigationItem.leftBarButtonItems?.firstIndex(of: skipBackwardBarButton) {
          navigationItem.leftBarButtonItems?.remove(at: index)
        }
        if let index = navigationItem.leftBarButtonItems?.firstIndex(of: previousBarButton) {
          navigationItem.leftBarButtonItems?.remove(at: index)
        }
        if let index = navigationItem.leftBarButtonItems?.firstIndex(of: nextBarButton) {
          navigationItem.leftBarButtonItems?.remove(at: index)
        }
        if let index = navigationItem.leftBarButtonItems?.firstIndex(of: skipForwardBarButton) {
          navigationItem.leftBarButtonItems?.remove(at: index)
        }

        if let index = navigationItem.leftBarButtonItems?.firstIndex(of: shuffleButton) {
          navigationItem.leftBarButtonItems?.remove(at: index)
        }
        if let index = navigationItem.leftBarButtonItems?.firstIndex(of: shufflePlaceholderButton) {
          navigationItem.leftBarButtonItems?.remove(at: index)
        }
        if let index = navigationItem.leftBarButtonItems?.firstIndex(of: repeatButton) {
          navigationItem.leftBarButtonItems?.remove(at: index)
        }
        if let index = navigationItem.leftBarButtonItems?.firstIndex(of: repeatPlaceholderButton) {
          navigationItem.leftBarButtonItems?.remove(at: index)
        }

        if isShuffleEnabled {
          navigationItem.leftBarButtonItems?.insert(shuffleButton, at: 1)
        } else {
          navigationItem.leftBarButtonItems?.insert(shufflePlaceholderButton, at: 1)
        }

        switch appDelegate.player.playerMode {
        case .music:
          navigationItem.leftBarButtonItems?.insert(previousBarButton, at: 2)
          navigationItem.leftBarButtonItems?.insert(nextBarButton, at: 4)
        case .podcast:
          navigationItem.leftBarButtonItems?.insert(skipBackwardBarButton, at: 2)
          navigationItem.leftBarButtonItems?.insert(skipForwardBarButton, at: 4)
        }

        if isRepeatEnabled {
          navigationItem.leftBarButtonItems?.insert(repeatButton, at: 5)
        } else {
          navigationItem.leftBarButtonItems?.insert(repeatPlaceholderButton, at: 5)
        }
      }
    }

    @objc
    func settingsDidChange() {
      Task { @MainActor in
        self.navigationItem.leftBarButtonItems?.forEach { ($0 as? Refreshable)?.reload() }
        self.updateButtonVisibility()
        self.slideOverViewController.settingsDidChange()
      }
    }

    func showSlideOverView() {
      slideOverTrailingConstraint?.constant = 0
      UIView.animate(withDuration: 0.25) {
        self.view.layoutIfNeeded()
      }
    }

    func hideSlideOverView() {
      slideOverTrailingConstraint?.constant = sliderOverWidth
      UIView.animate(withDuration: 0.25) {
        self.view.layoutIfNeeded()
      }
    }

    func toggleSlideOverView() {
      if isPresentingSlideOver {
        hideSlideOverView()
      } else {
        showSlideOverView()
      }
    }

    override func viewWillLayoutSubviews() {
      extendSafeAreaToAccountForTabbar()
      super.viewWillLayoutSubviews()
    }
  }

  extension SlideOverHostingController: MusicPlayable {
    func didStartPlayingFromBeginning() {}
    func didStartPlaying() {}
    func didLyricsTimeChange(time: CMTime) {}
    func didPause() {}
    func didStopPlaying() {}
    func didElapsedTimeChange() {}
    func didPlaylistChange() {
      settingsDidChange()
    }

    func didArtworkChange() {}
    func didShuffleChange() {}
    func didRepeatChange() {}
    func didPlaybackRateChange() {}
  }

#endif
