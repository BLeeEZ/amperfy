//
//  SongTableCell.swift
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

class SongTableCell: BasicTableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak private var cacheIconImage: UIImageView!
    @IBOutlet weak private var artistLabelLeadingConstraint: NSLayoutConstraint!
    
    static let rowHeight: CGFloat = 48 + margin.bottom + margin.top
    
    var song: Song?
    var rootView: UITableViewController?
    var playContextCb: GetPlayContextFromTableCellCallback?
    var playIndicator: PlayIndicator!
    private var isAlertPresented = false

    override func awakeFromNib() {
        super.awakeFromNib()
        playContextCb = nil
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(song: Song, playContextCb: @escaping GetPlayContextFromTableCellCallback, rootView: UITableViewController) {
        if playIndicator == nil {
            playIndicator = PlayIndicator(rootViewTypeName: rootView.typeName)
        }
        self.song = song
        self.playContextCb = playContextCb
        self.rootView = rootView
        refresh()
    }
    
    func refresh() {
        guard let song = song else { return }
        playIndicator.display(playable: song, rootView: self.entityImage, isOnImage: true)
        titleLabel.attributedText = NSMutableAttributedString(string: song.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        artistLabel.text = song.creatorName
        
        entityImage.display(container: song)

        if song.isCached {
            cacheIconImage.isHidden = false
            artistLabelLeadingConstraint.constant = 20
        } else {
            cacheIconImage.isHidden = true
            artistLabelLeadingConstraint.constant = 0
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        playIndicator.reset()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let song = song, let context = playContextCb?(self) else { return }

        if !isAlertPresented && (song.isCached || appDelegate.storage.settings.isOnlineMode) {
            hideSearchBarKeyboardInRootView()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            appDelegate.player.play(context: context)
        }
        isAlertPresented = false
    }
    
    private func hideSearchBarKeyboardInRootView() {
        if let basicRootView = rootView as? BasicTableViewController {
            basicRootView.searchController.searchBar.endEditing(true)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isAlertPresented = false
    }
    
    @objc func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
        if gesture.state == .began {
            displayMenu()
        }
    }
    
    func displayMenu() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let song = song, let rootView = rootView else { return }
        isAlertPresented = true
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: song, on: rootView, playContextCb: {() in self.playContextCb?(self)})
        rootView.present(detailVC, animated: true)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        playIndicator.applyStyle()
    }

}
