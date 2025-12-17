//
//  GenericTableCell.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 20.02.22.
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

class GenericTableCell: BasicTableCell {
  @IBOutlet
  weak var titleLabel: UILabel!
  @IBOutlet
  weak var subtitleLabel: UILabel!
  @IBOutlet
  weak var entityImage: EntityImageView!
  @IBOutlet
  weak var infoLabel: UILabel!
  @IBOutlet
  weak var favoriteIconImage: UIImageView!

  @IBOutlet
  weak var infoLabelWidthConstraint: NSLayoutConstraint!

  static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
  static let rowHeightWithoutImage: CGFloat = 28.0 + margin.bottom + margin.top

  private var container: PlayableContainable?
  private var rootView: UITableViewController?

  func display(container: PlayableContainable, rootView: UITableViewController) {
    self.container = container
    self.rootView = rootView
    selectionStyle = .none
    titleLabel.text = container.name
    subtitleLabel.isHidden = container.subtitle == nil
    subtitleLabel.text = container.subtitle
    entityImage.display(
      theme: appDelegate.storage.settings.accounts.getSetting(container.account?.info).read
        .themePreference,
      container: container
    )
    let infoText = container.info(
      for: container.account?.apiType.asServerApiType,
      details: DetailInfoType(type: .short, settings: appDelegate.storage.settings)
    )
    infoLabel.isHidden = infoText.isEmpty
    infoLabel.text = infoText
    infoLabel.textAlignment = (traitCollection.horizontalSizeClass == .regular) ? .right : .left
    favoriteIconImage.isHidden = !container.isFavorite
    favoriteIconImage.tintColor = .red

    if container is Album {
      infoLabelWidthConstraint.constant = 75
    } else if container is Artist {
      infoLabelWidthConstraint.constant = 230
    } else if container is Genre {
      infoLabelWidthConstraint.constant = 260
    } else if container is Podcast {
      infoLabelWidthConstraint.constant = 140
    }
    accessoryType = .disclosureIndicator
    backgroundColor = .systemBackground
  }
}
