//
//  UserQueueSectionHeader.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 22.11.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

import MarqueeLabel
import UIKit

class UserQueueSectionHeader: UIView {
  @IBOutlet
  weak var nameLabel: MarqueeLabel!
  @IBOutlet
  weak var rightButton: UIButton!

  static let frameHeight: CGFloat = 28.0 + margin.top + margin.bottom
  static let margin = UIEdgeInsets(
    top: 8,
    left: UIView.defaultMarginX,
    bottom: 8,
    right: UIView.defaultMarginX
  )

  private var buttonPressAction: (() -> ())?

  override init(frame: CGRect) {
    super.init(frame: frame)
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.layoutMargins = Self.margin
  }

  func hide() {
    nameLabel.text = ""
    nameLabel.isHidden = true
    rightButton.isHidden = true
    rightButton.isEnabled = false
  }

  func display(name: String, buttonPressAction: @escaping (() -> ())) {
    nameLabel.text = name
    nameLabel.isHidden = false
    nameLabel.applyAmperfyStyle()
    rightButton.isHidden = false
    rightButton.isEnabled = true
    self.buttonPressAction = buttonPressAction
  }

  @IBAction
  func rightButtonPressed(_ sender: Any) {
    if let buttonAction = buttonPressAction {
      buttonAction()
    }
  }
}
