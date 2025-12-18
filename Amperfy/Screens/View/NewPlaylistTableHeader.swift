//
//  NewPlaylistTableHeader.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

typealias PlaylistCreationResponder = (_ playlist: Playlist) -> ()

// MARK: - NewPlaylistTableHeader

class NewPlaylistTableHeader: UIView {
  @IBOutlet
  weak var nameTextField: UITextField!

  var account: Account!

  static let frameHeight: CGFloat = 30.0 + margin.top + margin.bottom
  static let margin = UIEdgeInsets(
    top: 10,
    left: UIView.defaultMarginX,
    bottom: 5,
    right: UIView.defaultMarginX
  )

  override init(frame: CGRect) {
    super.init(frame: frame)
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.layoutMargins = Self.margin
  }

  @IBAction
  func createPlaylistButtonPressed(_ sender: Any) {
    guard let playlistName = nameTextField.text, !playlistName.isEmpty else {
      return
    }
    let playlist = appDelegate.storage.main.library.createPlaylist(account: account)
    appDelegate.storage.main.saveContext()
    playlist.name = playlistName
    nameTextField.text = ""
    appDelegate.storage.main.saveContext()
  }
}
