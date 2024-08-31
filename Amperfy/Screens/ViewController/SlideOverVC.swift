//
//  QueueViewController.swift
//  Amperfy
//
//  Created by David Klopp on 29.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import UIKit

#if targetEnvironment(macCatalyst)

// ViewController representing a single item in the slide over menu
class SliderOverItemVC: UIViewController {
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
    private(set) var viewController: [SliderOverItemVC] = []

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
        self.initializeViewController()

        self.segmentedControl = UISegmentedControl(items: self.viewController.enumerated().map { (i, vc) in
            vc.title ?? "View: \(i)"
        })
        self.segmentedControl?.addTarget(self, action: #selector(self.selectionChanged(_:)), for: .valueChanged)
        self.segmentedControl?.selectedSegmentIndex = UISegmentedControl.noSegment
    }

    private func initializeViewController() {
        self.viewController = [QueueVC()]
        if (isLyricsButtonAllowedToDisplay) {
            self.viewController += [LyricsVC()]
        }
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard self.segmentedControl?.selectedSegmentIndex == UISegmentedControl.noSegment else {
            return
        }
        self.segmentedControl?.selectedSegmentIndex = 0
        self.selectionChanged(self.segmentedControl)
    }
}

#endif
