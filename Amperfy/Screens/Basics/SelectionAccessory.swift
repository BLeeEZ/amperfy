//
//  SelectionAccessory.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 28.02.24.
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

import AmperfyKit
import UIKit

@MainActor
extension UICellAccessory.CustomViewConfiguration {
  public static func createUnSelected() -> UICellAccessory.CustomViewConfiguration {
    let icon = UIImageView(image: .unSelected)
    return UICellAccessory.CustomViewConfiguration(
      customView: icon,
      placement: .leading(displayed: .whenEditing)
    )
  }

  public static func createIsSelected() -> UICellAccessory.CustomViewConfiguration {
    let icon = UIImageView(image: .isSelected)
    return UICellAccessory.CustomViewConfiguration(
      customView: icon,
      placement: .leading(displayed: .whenEditing)
    )
  }

  public static func createEdit(target: Any?, action: Selector?) -> UICellAccessory
    .CustomViewConfiguration {
    let label = UILabel()
    label.text = "Edit"
    label.textColor = .secondaryLabel
    label.isUserInteractionEnabled = true
    let gestureRecognizer = UITapGestureRecognizer(target: target, action: action)
    label.addGestureRecognizer(gestureRecognizer)
    return UICellAccessory.CustomViewConfiguration(
      customView: label,
      placement: .trailing(displayed: .whenNotEditing)
    )
  }

  public static func createDone(target: Any?, action: Selector?) -> UICellAccessory
    .CustomViewConfiguration {
    let label = UILabel()
    label.text = "Done"
    label.textColor = .secondaryLabel
    label.isUserInteractionEnabled = true
    let gestureRecognizer = UITapGestureRecognizer(target: target, action: action)
    label.addGestureRecognizer(gestureRecognizer)
    return UICellAccessory.CustomViewConfiguration(
      customView: label,
      placement: .trailing(displayed: .whenEditing)
    )
  }
}
