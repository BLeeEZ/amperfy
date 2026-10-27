//
//  BasicTableCell.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 06.03.21.
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

import UIKit

class BasicTableCell: UITableViewCell {
  static let margin = UIView.defaultMarginCell

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    self.layoutMargins = BasicTableCell.margin
  }

  override var layoutMargins: UIEdgeInsets { get { BasicTableCell.margin } set {} }

  override func prepareForReuse() {
    super.prepareForReuse()
    markAsUnfocused()
    #if targetEnvironment(macCatalyst)
      isSectionEndSeparatorVisible = false
    #endif
  }

  #if targetEnvironment(macCatalyst)
    // macOS does not draw the separator below the last row of a section (iOS does, as long as
    // there is no section footer). We draw it ourselves inside the last cell of each section.
    // Using a section footer instead does not work for plain table views: footers stick to the
    // bottom of the visible area while scrolling.
    // Grouped style does also not work, because that will draw a line from the left edge to the
    // right edge of the tableView (ignoring the separator inset) at the end of a section.
    private lazy var sectionEndSeparator: UIView = {
      let separator = UIView()
      separator.backgroundColor = .separator
      separator.isHidden = true
      separator.isUserInteractionEnabled = false
      addSubview(separator)
      return separator
    }()

    var isSectionEndSeparatorVisible = false {
      didSet {
        guard isSectionEndSeparatorVisible != oldValue else { return }
        sectionEndSeparator.isHidden = !isSectionEndSeparatorVisible
        setNeedsLayout()
      }
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      guard isSectionEndSeparatorVisible else { return }
      let height = 1.0
      sectionEndSeparator.frame = CGRect(
        x: separatorInset.left,
        y: bounds.height - height,
        width: max(0, bounds.width - separatorInset.left - separatorInset.right),
        height: height
      )
      bringSubviewToFront(sectionEndSeparator)
    }
  #endif
}
