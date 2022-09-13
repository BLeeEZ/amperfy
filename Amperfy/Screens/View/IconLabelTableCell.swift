//
//  IconLabelTableCell.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 06.02.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

import UIKit
import AmperfyKit

class IconLabelTableCell: BasicTableCell {
    
    @IBOutlet weak var nameLabel: MarqueeLabel!
    @IBOutlet weak var actionImage: UIImageView!
    @IBOutlet weak var directoryIconLabel: UILabel!
    
    private var action: SwipeActionType?
    private var libraryDisplayType: LibraryDisplayType?
    
    static let rowHeight: CGFloat = 60.0
    
    func display(action: SwipeActionType) {
        self.action = action
        nameLabel.applyAmperfyStyle()
        nameLabel.text = action.settingsName
        refreshStyle()
    }
    
    func display(libraryDisplayType: LibraryDisplayType) {
        self.libraryDisplayType = libraryDisplayType
        nameLabel.applyAmperfyStyle()
        nameLabel.text = libraryDisplayType.displayName
        refreshStyle()
    }
    
    func refreshStyle() {
        if let action = action {
            if traitCollection.userInterfaceStyle == .dark {
                actionImage.image = action.image.invertedImage()
            } else {
                actionImage.image = action.image
            }
            nameLabel.font = nameLabel.font.withSize(16)
            directoryIconLabel.isHidden = true
        } else if let libraryDisplayType = libraryDisplayType {
            actionImage.image = libraryDisplayType.image.withTintColor(.defaultBlue)
            directoryIconLabel.isHidden = false
            nameLabel.font = nameLabel.font.withSize(20)
        }
    }

}
