//
//  PlaylistDetailTableHeader.swift
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

import UIKit
import AmperfyKit
import PromiseKit

class PlaylistDetailTableHeader: UIView {

    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let frameHeight: CGFloat = 200.0
    static let margin = UIView.defaultMarginTopElement
    
    private var playlist: Playlist?
    private var appDelegate: AppDelegate!
    private var rootView: PlaylistDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOnPlaylist playlist: Playlist?, rootView: PlaylistDetailVC) {
        guard let playlist = playlist else { return }
        self.playlist = playlist
        self.rootView = rootView
        nameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        nameTextField.setContentCompressionResistancePriority(.required, for: .vertical)
        infoLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        refresh()
    }
    
    func refresh() {
        guard let playlist = playlist, let rootView = rootView else { return }
        entityImage.display(container: playlist)
        nameLabel.text = playlist.name
        nameTextField.text = playlist.name
        infoLabel.text = playlist.info(for: appDelegate.backendApi.selectedApi, type: .long)
        if rootView.tableView.isEditing {
            nameLabel.isHidden = true
            nameTextField.isHidden = false
            nameTextField.text = playlist.name
        } else {
            nameLabel.isHidden = false
            nameTextField.isHidden = true
        }
    }

    func startEditing() {
        refresh()
    }
    
    func endEditing() {
        defer { refresh() }
        guard let nameText = nameTextField.text, let playlist = playlist, nameText != playlist.name else { return }
        playlist.name = nameText
        nameLabel.text = nameText
        guard appDelegate.storage.settings.isOnlineMode else { return }
     
        firstly {
            self.appDelegate.librarySyncer.syncUpload(playlistToUpdateName: playlist)
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Playlist Update Name", error: error)
        }

    }

}
