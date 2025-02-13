//
//  InnerNavigationController.swift
//  Amperfy
//
//  Created by David Klopp on 03.09.24.
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

import Foundation
import UIKit

extension UIViewController {
  @objc
  var sceneTitle: String? { nil }
}

#if targetEnvironment(macCatalyst)

  class InnerNavigationController: UINavigationController {
    override func viewDidLoad() {
      super.viewDidLoad()

      // Hide the navigation title
      navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.clear]
      if #available(macCatalyst 16.0, *) {
        self.navigationBar.preferredBehavioralStyle = .pad
      }
    }

    override func viewIsAppearing(_ animated: Bool) {
      super.viewIsAppearing(animated)
      updateSceneTitle()
    }

    private func updateSceneTitle() {
      let windowScene = view.window?.windowScene
      guard windowScene != nil, let windowTitle = topViewController?.sceneTitle else {
        windowScene?.title = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String
        return
      }
      windowScene?.title = windowTitle
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
      super.pushViewController(viewController, animated: animated)
      updateSceneTitle()
    }

    override func popViewController(animated: Bool) -> UIViewController? {
      let poppedViewController = super.popViewController(animated: animated)
      updateSceneTitle()
      return poppedViewController
    }

    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
      super.setViewControllers(viewControllers, animated: animated)
      updateSceneTitle()
    }
  }
#endif
