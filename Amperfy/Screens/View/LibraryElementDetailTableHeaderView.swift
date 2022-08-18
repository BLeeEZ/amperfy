//
//  LibraryElementDetailTableHeaderView.swift
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

class LibraryElementDetailTableHeaderView: UIView {
    
    @IBOutlet weak var playAllButton: UIButton!
    @IBOutlet weak var playShuffledButton: UIButton!
    
    static let frameHeight: CGFloat = 40.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginMiddleElement
    
    private var appDelegate: AppDelegate!
    private var playContextCb: GetPlayContextCallback?
    private var player: PlayerFacade?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    @IBAction func playAllButtonPressed(_ sender: Any) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        play(isShuffled: false)
    }
    
    @IBAction func addAllShuffledButtonPressed(_ sender: Any) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        play(isShuffled: true)
    }
    
    private func play(isShuffled: Bool) {
        guard let playContext = playContextCb?(), let player = player else { return }
        isShuffled ? player.playShuffled(context: playContext) : player.play(context: playContext)
    }
    
    func prepare(playContextCb: GetPlayContextCallback?, with player: PlayerFacade) {
        self.playContextCb = playContextCb
        self.player = player
        playAllButton.setImage(UIImage.play.invertedImage(), for: .normal)
        playAllButton.imageView?.contentMode = .scaleAspectFit
        playShuffledButton.setImage(UIImage.shuffle.invertedImage(), for: .normal)
        playShuffledButton.imageView?.contentMode = .scaleAspectFit
    }
    
}
