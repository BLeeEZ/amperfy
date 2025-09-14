//
//  CommonCollectionSectionHeader.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 27.09.22.
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

import AmperfyKit
import UIKit

class CommonCollectionSectionHeader: UICollectionReusableView {
  static let frameHeight: CGFloat = 30.0

  @IBOutlet
  weak var titleLabel: UILabel!

  private var detailHeader: LibraryElementDetailTableHeaderView?

  func display(title: String?) {
    titleLabel.text = title
    titleLabel.isHidden = (title == nil)
  }

  func displayPlayHeader(configuration: PlayShuffleInfoConfiguration) {
    detailHeader = ViewCreator<LibraryElementDetailTableHeaderView>
      .createFromNib(withinFixedFrame: CGRect(
        x: 0,
        y: 0,
        width: bounds.size.width,
        height: LibraryElementDetailTableHeaderView.frameHeight
      ))
    detailHeader?.prepare(configuration: configuration)
    detailHeader?.refresh()
    if let detailHeader = detailHeader {
      addSubview(detailHeader)
    }
  }

  override func prepareForReuse() {
    detailHeader?.removeFromSuperview()
    detailHeader?.isHidden = true
    detailHeader = nil

    registerForTraitChanges(
      [UITraitUserInterfaceStyle.self, UITraitHorizontalSizeClass.self],
      handler: { (self: Self, previousTraitCollection: UITraitCollection) in
        self.detailHeader?.refresh()
      }
    )
  }
}
