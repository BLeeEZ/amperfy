//
//  MacToolbarHostingViewController.swift
//  Amperfy
//
//  Created by David Klopp on 29.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import UIKit

#if targetEnvironment(macCatalyst)
class MacToolbarHostingViewController: UIViewController {
    override var sceneTitle: String? {
        self.children.first?.sceneTitle
    }

    var sliderOverWidth: CGFloat = 300 {
        didSet(newValue) {
            self.slideOverWidthConstraint?.constant = newValue
            self.slideOverTrailingConstraint?.constant = newValue
        }
    }

    let primaryViewController: UIViewController

    let slideOverViewController: UIViewController

    private var slideOverWidthConstraint: NSLayoutConstraint?
    private var slideOverTrailingConstraint: NSLayoutConstraint?
    private var isPresentingSlideOver: Bool {
        self.slideOverTrailingConstraint?.constant == 0
    }

    init(primaryViewController: UIViewController, slideOverViewController: UIViewController) {
        self.primaryViewController = primaryViewController
        self.slideOverViewController = slideOverViewController
        super.init(nibName: nil, bundle: nil)

        // Add the primary view controller
        self.addChild(primaryViewController)
        self.view.addSubview(self.primaryViewController.view)
        self.primaryViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.primaryViewController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.primaryViewController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.primaryViewController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.primaryViewController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        self.primaryViewController.didMove(toParent: self)

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
