//
//  SpaceBarItem.swift
//  Amperfy
//
//  Created by David Klopp on 22.08.24.
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

#if targetEnvironment(macCatalyst)

  // Hack: built-in flexible space navigation bar item is not working, so we use this workaround
  class SpaceBarItem: UIBarButtonItem {
    convenience init(fixedSpace: CGFloat, priority: UILayoutPriority = .defaultHigh) {
      self.init(minSpace: fixedSpace, maxSpace: fixedSpace)
    }

    init(minSpace: CGFloat = 0, maxSpace: CGFloat = 10000) {
      super.init()

      let clearView = UIView(frame: .zero)
      clearView.backgroundColor = .clear

      clearView.translatesAutoresizingMaskIntoConstraints = false

      NSLayoutConstraint.activate([
        clearView.widthAnchor.constraint(lessThanOrEqualToConstant: maxSpace),
        clearView.widthAnchor.constraint(greaterThanOrEqualToConstant: minSpace),
        // This allows us to still grab and move the window when clicking the empty space
        clearView.heightAnchor.constraint(equalToConstant: 0),
      ])

      self.customView = clearView
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }

#endif
