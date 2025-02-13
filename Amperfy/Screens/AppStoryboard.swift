//
//  AppStoryboard.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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
import UIKit

// MARK: - AppStoryboard

@MainActor
enum AppStoryboard: String {
  case Main

  var instance: UIStoryboard {
    UIStoryboard(name: rawValue, bundle: Bundle.main)
  }

  func viewController<T: UIViewController>(viewControllerClass: T.Type) -> T {
    instance.instantiateViewController(withIdentifier: viewControllerClass.storyboardID) as! T
  }

  func createAlbumsVC(
    style: AlbumsDisplayStyle,
    category: DisplayCategoryFilter
  )
    -> UIViewController {
    switch style {
    case .table:
      let vc = AlbumsVC.instantiateFromAppStoryboard()
      vc.displayFilter = category
      return vc
    case .grid:
      let vc = AlbumsCollectionVC.instantiateFromAppStoryboard()
      vc.displayFilter = category
      return vc
    }
  }
}

extension UIViewController {
  class var storyboardID: String {
    "\(self)"
  }

  static func instantiateFromAppStoryboard(appStoryboard: AppStoryboard = .Main) -> Self {
    appStoryboard.viewController(viewControllerClass: self)
  }
}
