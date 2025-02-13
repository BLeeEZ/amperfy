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
  }
}
