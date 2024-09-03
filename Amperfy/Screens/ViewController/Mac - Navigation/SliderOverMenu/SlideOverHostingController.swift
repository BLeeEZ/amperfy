//
//  MacToolbarHostingViewController.swift
//  Amperfy
//
//  Created by David Klopp on 29.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import UIKit

#if targetEnvironment(macCatalyst)

// A view controller with a primary view controller and a slide over view controller that can be displayed
// from the right hand side as an overlay.
class SlideOverHostingController: UIViewController {
    var sliderOverWidth: CGFloat = 300 {
        didSet(newValue) {
            self.slideOverWidthConstraint?.constant = newValue
            self.slideOverTrailingConstraint?.constant = newValue
        }
    }

    var _primaryViewController: UIViewController?

    var primaryViewController: UIViewController? {
        get { return self._primaryViewController }
        set(newValue) {
            self._primaryViewController?.view.removeFromSuperview()
            self._primaryViewController?.removeFromParent()
            self._primaryViewController?.didMove(toParent: nil)

            guard let vc = newValue else { return }

            self.addChild(vc)
            self.view.insertSubview(vc.view, at: 0)
            vc.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                vc.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                vc.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                vc.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                vc.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
            vc.didMove(toParent: self)

            self._primaryViewController = vc
        }
    }

    let slideOverViewController: SlideOverVC

    private var slideOverWidthConstraint: NSLayoutConstraint?
    private var slideOverTrailingConstraint: NSLayoutConstraint?
    private var isPresentingSlideOver: Bool {
        self.slideOverTrailingConstraint?.constant == 0
    }

    init(slideOverViewController: SlideOverVC) {
        self.slideOverViewController = slideOverViewController
        super.init(nibName: nil, bundle: nil)

        // Add the slide over view controller
        self.addChild(slideOverViewController)
        self.view.addSubview(slideOverViewController.view)
        self.slideOverViewController.view.translatesAutoresizingMaskIntoConstraints = false

        let wc = self.slideOverViewController.view.widthAnchor.constraint(equalToConstant: self.sliderOverWidth)
        let tc = self.slideOverViewController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: self.sliderOverWidth)

        NSLayoutConstraint.activate([
            self.slideOverViewController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.slideOverViewController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            wc,
            tc
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

        // Listen for setting changes to adjust the toolbar and slide over menu
        NotificationCenter.default.addObserver(self, selector: #selector(self.settingsDidChange), name: UserDefaults.didChangeNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupToolbar()
    }

    private lazy var shuffleButton: UIBarButtonItem = {
        let player = appDelegate.player
        return ShuffleBarButton(player: player)
    }()

    private func setupToolbar() {
        guard let splitViewController = self.splitViewController as? SplitVC else { return }
        let player = appDelegate.player

        // Add the media player controls to the view's navigation item
        self.navigationItem.leftItemsSupplementBackButton = false
        let defaultSpacing: CGFloat = 10
        self.navigationItem.leftBarButtonItems = [
                SpaceBarItem(fixedSpace: defaultSpacing),
                self.shuffleButton,
                PreviousBarButton(player: player),
                PlayBarButton(player: player),
                NextBarButton(player: player),
                RepeatBarButton(player: player),
                SpaceBarItem(minSpace: defaultSpacing),
                NowPlayingBarItem(player: player, splitViewController: splitViewController),
                SpaceBarItem(),
                AirplayBarButton(),
                QueueBarButton(splitViewController: splitViewController),
                SpaceBarItem(fixedSpace: defaultSpacing),
            ]
        self.updateShuffleVisibility()
        self.navigationItem.leftBarButtonItems?.forEach { ($0 as? Refreshable)?.reload() }
    }

    private func updateShuffleVisibility() {
        let shuffleEnabled = appDelegate.storage.settings.isPlayerShuffleButtonEnabled
        if #available(macCatalyst 16.0, *) {
            // We can not remove toolbar items in `mac` style, therefore we hide them
            self.shuffleButton.isHidden = !shuffleEnabled
        } else {
            // Below 16.0 there is no `mac` style and .isHidden is not available.
            if (shuffleEnabled) {
                self.navigationItem.leftBarButtonItems?.insert(self.shuffleButton, at: 1)
            } else {
                self.navigationItem.leftBarButtonItems?.remove(at: 1)
            }
        }
    }

    @objc func settingsDidChange() {
        self.navigationItem.leftBarButtonItems?.forEach { ($0 as? Refreshable)?.reload() }
        self.updateShuffleVisibility()
        self.slideOverViewController.settingsDidChange()
    }

    func showSlideOverView() {
        self.slideOverTrailingConstraint?.constant = 0
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    func hideSlideOverView() {
        self.slideOverTrailingConstraint?.constant = self.sliderOverWidth
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    func toggleSlideOverView() {
        if self.isPresentingSlideOver {
            self.hideSlideOverView()
        } else {
            self.showSlideOverView()
        }
    }

    override func viewWillLayoutSubviews() {
        self.extendSafeAreaToAccountForTabbar()
        super.viewWillLayoutSubviews()
    }
}
#endif
