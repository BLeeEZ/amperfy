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

import UIKit
import AmperfyKit

class GenericTableCell: BasicTableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    static let rowHeightWithoutImage: CGFloat = 28.0 + margin.bottom + margin.top
    
    private var container: PlayableContainable?
    private var rootView: UITableViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(container: PlayableContainable, rootView: UITableViewController) {
        self.container = container
        self.rootView = rootView
        titleLabel.text = container.name
        subtitleLabel.isHidden = container.subtitle == nil
        subtitleLabel.text = container.subtitle
        entityImage.display(container: container)
        let infoText = container.info(for: appDelegate.backendApi.selectedApi, details: DetailInfoType(type: .short, settings: appDelegate.storage.settings))
        infoLabel.isHidden = infoText.isEmpty
        infoLabel.text = infoText
    }

    @objc func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
        if gesture.state == .began {
            displayMenu()
        }
    }
    
    func displayMenu() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let container = container, let rootView = rootView else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: container, on: rootView)
        rootView.present(detailVC, animated: true)
    }
    
}
