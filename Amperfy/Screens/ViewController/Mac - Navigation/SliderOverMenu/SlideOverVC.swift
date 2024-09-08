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
        self.view.setBackgroundBlur(style: .prominent)

        let backgroundTintView = UIView()
        backgroundTintView.backgroundColor = .slideOverBackgroundColor
        backgroundTintView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(backgroundTintView)

        NSLayoutConstraint.activate([
            backgroundTintView.topAnchor.constraint(equalTo: self.view.topAnchor),
            backgroundTintView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            backgroundTintView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            backgroundTintView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
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
        return !appDelegate.storage.settings.isAlwaysHidePlayerLyricsButton &&
            appDelegate.player.playerMode == .music &&
            appDelegate.backendApi.selectedApi != .ampache
    }

    init() {
        self.rootVC = UIViewController()
        super.init(rootViewController: self.rootVC)
        
        if #available(macCatalyst 16.0, *) {
            self.navigationBar.preferredBehavioralStyle = .pad
        }

        // Configure navigation bar appearance
        let defaultAppearance = UINavigationBarAppearance()
        defaultAppearance.backgroundColor = .slideOverBackgroundColor
        defaultAppearance.backgroundEffect = UIBlurEffect(style: .prominent)
        self.navigationBar.standardAppearance = defaultAppearance
        self.navigationBar.compactAppearance = defaultAppearance
        self.navigationBar.scrollEdgeAppearance = defaultAppearance
        self.navigationBar.compactScrollEdgeAppearance = defaultAppearance

        // Add all view controllers and create the segmented control to select them
        self.updateNavigationItem()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addLeftSideBorder()
    }

    private func updateNavigationItem() {
        var newVC: [SlideOverItemVC] = [self.queueVC]
        if (self.isLyricsButtonAllowedToDisplay) {
            newVC += [self.lyricsVC]
        }
        
        guard newVC != self.viewController else { return }
        self.viewController = newVC

        self.segmentedControl = UISegmentedControl(items: self.viewController.enumerated().map { (i, vc) in
            vc.title ?? "View: \(i)"
        })
        self.segmentedControl?.addTarget(self, action: #selector(self.selectionChanged(_:)), for: .valueChanged)
        self.segmentedControl?.selectedSegmentIndex = UISegmentedControl.noSegment

        self.segmentedControl?.selectedSegmentIndex = 0
        self.selectionChanged(self.segmentedControl)
    }

    @objc private func selectionChanged(_ sender: UISegmentedControl?) {
        guard let index = sender?.selectedSegmentIndex, index != UISegmentedControl.noSegment else {
            self.popToRootViewController(animated: false)
            return
        }
        let vc = self.viewController[index]
        vc.navigationItem.hidesBackButton = true
        vc.navigationItem.titleView = sender
        self.popViewController(animated: false)
        self.pushViewController(vc, animated: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func settingsDidChange() {
        self.updateNavigationItem()
    }
}

#endif
