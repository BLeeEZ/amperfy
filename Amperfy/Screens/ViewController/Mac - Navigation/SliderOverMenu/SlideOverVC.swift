//
//  SlideOverVC.swift
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
import UIKit

#if targetEnvironment(macCatalyst)

  // ViewController representing a single item in the slide over menu
  class SlideOverItemVC: UIViewController {
    override func viewDidLoad() {
      super.viewDidLoad()
      view.setBackgroundBlur(style: .prominent)

      let backgroundTintView = UIView()
      backgroundTintView.backgroundColor = .slideOverBackgroundColor
      backgroundTintView.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(backgroundTintView)

      NSLayoutConstraint.activate([
        backgroundTintView.topAnchor.constraint(equalTo: view.topAnchor),
        backgroundTintView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        backgroundTintView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        backgroundTintView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      ])
    }
  }

  // ViewController used to manage the slide over menu in macOS.
  class SlideOverVC: UINavigationController {
    lazy var queueVC = QueueVC()
    lazy var lyricsVC = LyricsVC()

    private(set) var viewController: [SlideOverItemVC] = []

    private var segmentedControl: UISegmentedControl?

    // We could use this rootVC as a placeholder e.g if no music is playing
    private let rootVC: UIViewController

    var isLyricsButtonAllowedToDisplay: Bool {
      !appDelegate.storage.settings.isAlwaysHidePlayerLyricsButton &&
        appDelegate.player.playerMode == .music &&
        appDelegate.backendApi.selectedApi != .ampache
    }

    init() {
      self.rootVC = UIViewController()
      super.init(rootViewController: rootVC)

      if #available(macCatalyst 16.0, *) {
        self.navigationBar.preferredBehavioralStyle = .pad
      }

      // Configure navigation bar appearance
      let defaultAppearance = UINavigationBarAppearance()
      defaultAppearance.backgroundColor = .slideOverBackgroundColor
      defaultAppearance.backgroundEffect = UIBlurEffect(style: .prominent)
      navigationBar.standardAppearance = defaultAppearance
      navigationBar.compactAppearance = defaultAppearance
      navigationBar.scrollEdgeAppearance = defaultAppearance
      navigationBar.compactScrollEdgeAppearance = defaultAppearance

      // Add all view controllers and create the segmented control to select them
      updateNavigationItem()
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      view.addLeftSideBorder()
    }

    private func updateNavigationItem() {
      var newVC: [SlideOverItemVC] = [queueVC]
      if isLyricsButtonAllowedToDisplay {
        newVC += [lyricsVC]
      }

      guard newVC != viewController else { return }
      viewController = newVC

      segmentedControl = UISegmentedControl(items: viewController.enumerated().map { i, vc in
        vc.title ?? "View: \(i)"
      })
      segmentedControl?.addTarget(self, action: #selector(selectionChanged(_:)), for: .valueChanged)
      segmentedControl?.selectedSegmentIndex = UISegmentedControl.noSegment

      segmentedControl?.selectedSegmentIndex = 0
      selectionChanged(segmentedControl)
    }

    @objc
    private func selectionChanged(_ sender: UISegmentedControl?) {
      guard let index = sender?.selectedSegmentIndex, index != UISegmentedControl.noSegment else {
        popToRootViewController(animated: false)
        return
      }
      let vc = viewController[index]
      vc.navigationItem.hidesBackButton = true
      vc.navigationItem.titleView = sender
      popViewController(animated: false)
      pushViewController(vc, animated: false)
    }

    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    func settingsDidChange() {
      updateNavigationItem()
    }
  }

#endif
