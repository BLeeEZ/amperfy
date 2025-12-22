//
//  DirectoryTableCell.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 25.05.21.
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

@MainActor
class DirectoryTableCell: BasicTableCell {
  @IBOutlet
  weak var infoLabel: UILabel!
  @IBOutlet
  weak var artworkImage: LibraryEntityImage!
  @IBOutlet
  weak var iconImage: UIImageView!

  static let rowHeight: CGFloat = 40.0 + margin.bottom + margin.top

  private var folder: MusicFolder?
  private var directory: Directory?
  var entity: AbstractLibraryEntity? {
    directory
  }

  private var accountNotificationHandler: AccountNotificationHandler?

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.accountNotificationHandler = AccountNotificationHandler(
      storage: appDelegate.storage,
      notificationHandler: appDelegate.notificationHandler
    )
    accountNotificationHandler?.registerCallbackForAllAccounts { [weak self] accountInfo in
      guard let self else { return }
      appDelegate.notificationHandler.register(
        self,
        selector: #selector(artworkDownloadFinishedSuccessful(notification:)),
        name: .downloadFinishedSuccess,
        object: appDelegate.getMeta(accountInfo).artworkDownloadManager
      )
    }
  }

  func display(folder: MusicFolder) {
    self.folder = folder
    directory = nil
    refresh()
  }

  func display(directory: Directory) {
    folder = nil
    self.directory = directory
    if let artwork = directory.artwork, let accountInfo = artwork.account?.info {
      appDelegate.getMeta(accountInfo).artworkDownloadManager.download(object: artwork)
    }
    refresh()
  }

  @objc
  private func artworkDownloadFinishedSuccessful(notification: Notification) {
    if let downloadNotification = DownloadNotification.fromNotification(notification),
       let artwork = entity?.artwork,
       artwork.uniqueID == downloadNotification.id {
      refresh()
    }
  }

  private func refresh() {
    iconImage.isHidden = true
    artworkImage.isHidden = true

    if let directory = directory {
      infoLabel.text = directory.name
      artworkImage.display(entity: directory)
      if let artwork = directory.artwork, artwork.imagePath != nil {
        artworkImage.isHidden = false
      } else {
        iconImage.isHidden = false
      }
    } else if let folder = folder {
      infoLabel.text = folder.name
      iconImage.isHidden = false
    }
    accessoryType = .disclosureIndicator
    backgroundColor = .systemBackground
  }
}
