//
//  GenericDetailTableHeader.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 19.02.22.
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

class GenericDetailTableHeader: UIView {
    
    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleView: UIView!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let frameHeight: CGFloat = 200.0
    static let margin = UIView.defaultMarginTopElement
    
    private var entityContainer: PlayableContainable?
    private var appDelegate: AppDelegate!
    private var rootView: BasicTableViewController?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOn entityContainer: PlayableContainable?, rootView: BasicTableViewController? ) {
        guard let entityContainer = entityContainer else { return }
        self.entityContainer = entityContainer
        self.rootView = rootView
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        infoLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        refresh()
    }
        
    func refresh() {
        guard let entityContainer = entityContainer else { return }
        entityImage.display(container: entityContainer)
        titleLabel.text = entityContainer.name
        subtitleView.isHidden = entityContainer.subtitle == nil
        subtitleLabel.text = entityContainer.subtitle
        let infoText = entityContainer.info(for: appDelegate.backendApi.selectedApi, details: DetailInfoType(type: .long, settings: appDelegate.storage.settings))
        infoLabel.isHidden = infoText.isEmpty
        infoLabel.text = infoText
    }
    
    @IBAction func subtitleButtonPressed(_ sender: Any) {
        guard let album = entityContainer as? Album,
              let artist = album.artist,
              let navController = self.rootView?.navigationController
        else { return }
        self.appDelegate.userStatistics.usedAction(.alertGoToAlbum)
        let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
        artistDetailVC.artist = artist
        navController.pushViewController(artistDetailVC, animated: true)
    }
    
}
