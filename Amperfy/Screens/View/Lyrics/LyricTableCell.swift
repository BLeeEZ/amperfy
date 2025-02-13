//
//  LyricTableCell.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 17.06.24.
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

import AmperfyKit
import CoreData
import UIKit

// MARK: - LyricTableCellModel

@MainActor
class LyricTableCellModel {
  var lyric: LyricsLine? {
    didSet {
      cell?.refresh()
    }
  }

  var isActiveLine = false {
    didSet {
      cell?.refresh()
    }
  }

  private var attributedString: NSAttributedString?
  private var highlightedAttributedString: NSAttributedString?

  internal weak var cell: LyricTableCell?

  var displayString: NSAttributedString? {
    if isActiveLine {
      return highlightedAttributedString
    } else {
      return attributedString
    }
  }

  init(lyric: LyricsLine) {
    self.lyric = lyric
    self.isActiveLine = false
    self.attributedString = NSAttributedString(
      string: lyric.value,
      attributes:
      [
        .font: UIFont.systemFont(ofSize: 20),
        .foregroundColor: UIColor.gray,
      ]
    )
    self.highlightedAttributedString = NSAttributedString(
      string: lyric.value,
      attributes:
      [
        .font: UIFont.boldSystemFont(ofSize: 20),
        .foregroundColor: UIColor.label,
      ]
    )
  }

  public func calcHeight(containerWidth: CGFloat) -> CGFloat {
    let boundingSize = CGSize(
      width: LyricTableCell.adjustContainerWidthForMargins(containerWidth: containerWidth),
      height: 9_999
    )
    if isActiveLine {
      return highlightedAttributedString?.boundingRect(
        with: boundingSize,
        options: .usesLineFragmentOrigin,
        context: nil
      ).height ?? 0
    } else {
      return attributedString?.boundingRect(
        with: boundingSize,
        options: .usesLineFragmentOrigin,
        context: nil
      ).height ?? 0
    }
  }
}

// MARK: - LyricTableCell

class LyricTableCell: UITableViewCell {
  private weak var viewModel: LyricTableCellModel? = nil

  private var lyricLabel: UILabel!
  override var layoutMargins: UIEdgeInsets { get { BasicTableCell.margin } set {} }

  static func adjustContainerWidthForMargins(containerWidth: CGFloat) -> CGFloat {
    containerWidth - (2 * BasicTableCell.margin.right)
  }

  public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    lyricLabel = UILabel(frame: CGRect(
      x: layoutMargins.left,
      y: 0,
      width: bounds.width - (2 * layoutMargins.right),
      height: bounds.height
    ))
    lyricLabel.textAlignment = .center
    lyricLabel.lineBreakMode = .byWordWrapping
    lyricLabel.numberOfLines = 5
    selectionStyle = .none
    contentView.addSubview(lyricLabel)
    backgroundColor = .clear
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    lyricLabel.frame = CGRect(
      x: layoutMargins.left,
      y: 0,
      width: bounds.width - (2 * layoutMargins.right),
      height: bounds.height
    )
  }

  func display(model: LyricTableCellModel) {
    viewModel = model
    model.cell = self
    refresh()
  }

  func refresh() {
    guard let model = viewModel else { return }
    lyricLabel.attributedText = model.displayString
    lyricLabel.sizeThatFits(CGSize(width: bounds.width, height: bounds.height))
  }
}
