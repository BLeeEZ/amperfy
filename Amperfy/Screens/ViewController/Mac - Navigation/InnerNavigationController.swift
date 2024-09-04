//
//  NestedNavigationController.swift
//  Amperfy
//
//  Created by David Klopp on 03.09.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    @objc var sceneTitle: String? { nil }
}


#if targetEnvironment(macCatalyst)

class InnerNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Hide the navigation title
        self.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.clear]
        if #available(macCatalyst 16.0, *) {
            self.navigationBar.preferredBehavioralStyle = .pad
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updateSceneTitle()
    }

    private func updateSceneTitle() {
        let windowScene = self.view.window?.windowScene
        guard windowScene != nil, let windowTitle = self.topViewController?.sceneTitle else {
            windowScene?.title = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String
            return
        }
        windowScene?.title = windowTitle
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        self.updateSceneTitle()
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        let poppedViewController = super.popViewController(animated: animated)
        self.updateSceneTitle()
        return poppedViewController
    }

    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        self.updateSceneTitle()
    }
}
#endif
