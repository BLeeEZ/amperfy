//
//  QueueViewController.swift
//  Amperfy
//
//  Created by David Klopp on 29.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import UIKit

fileprivate class UserQueueViewController: UIViewController {
    override var title: String? {
        get { return "User Queue" }
        set {}
    }

    override func viewDidLoad() {
        self.view.backgroundColor = .systemBackground
    }
}

fileprivate class ContextQueueViewController: UIViewController {
    override var title: String? {
        get { return "Context Queue" }
        set {}
    }

    override func viewDidLoad() {
        self.view.backgroundColor = .secondarySystemBackground
    }
}

// ViewController used in the slider over menu on macOS.
class QueueVC: UINavigationController {
    private let userQueueViewController: UIViewController = {
        let vc = UserQueueViewController()
        return vc
    }()

    private let contextQueueViewController: UIViewController = {
        let vc = ContextQueueViewController()
        return vc
    }()

    private(set) var viewController: [UIViewController] = []

    private var segmentedControl: UISegmentedControl?

    // TODO: Use this rootVC as a placeholder e.g. if no music is playing
    private let rootVC: UIViewController


    init() {
        self.rootVC = UIViewController()
        super.init(rootViewController: self.rootVC)
        
        #if targetEnvironment(macCatalyst)
        if #available(macCatalyst 16.0, *) {
            self.navigationBar.preferredBehavioralStyle = .pad
        }
        #endif

        /*let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        self.navigationBar.standardAppearance = appearance
        self.navigationBar.scrollEdgeAppearance = appearance
        self.navigationBar.compactAppearance = appearance*/

        self.viewController = [self.userQueueViewController, self.contextQueueViewController]

        self.segmentedControl = UISegmentedControl(items: self.viewController.enumerated().map { (i, vc) in
            vc.title ?? "View: \(i)"
        })
        self.segmentedControl?.addTarget(self, action: #selector(self.selectionChanged(_:)), for: .valueChanged)
        self.segmentedControl?.selectedSegmentIndex = UISegmentedControl.noSegment
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
