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
    private var shuffleContextCb: GetPlayContextCallback?
    private var isShuffleOnContextNeccessary: Bool = true
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
        shuffle()
    }
    
    private func play(isShuffled: Bool) {
        guard let playContext = playContextCb?(), let player = player else { return }
        isShuffled ? player.playShuffled(context: playContext) : player.play(context: playContext)
    }
    
    private func shuffle() {
        guard let player = player else { return }
        if let shuffleContext = shuffleContextCb?() {
            if isShuffleOnContextNeccessary {
                player.playShuffled(context: shuffleContext)
            } else {
                player.play(context: shuffleContext)
            }
        } else {
            play(isShuffled: true)
        }
    }
    
    /// isShuffleOnContextNeccessary: In AlbumsVC the albums are shuffled, keep the order when shuffle button is pressed
    func prepare(playContextCb: GetPlayContextCallback?, with player: PlayerFacade, isShuffleOnContextNeccessary: Bool = true, shuffleContextCb: GetPlayContextCallback? = nil) {
        self.playContextCb = playContextCb
        self.player = player
        self.isShuffleOnContextNeccessary = isShuffleOnContextNeccessary
        self.shuffleContextCb = shuffleContextCb
        playAllButton.setImage(UIImage.play.invertedImage(), for: .normal)
        playAllButton.imageView?.contentMode = .scaleAspectFit
        playShuffledButton.setImage(UIImage.shuffle.invertedImage(), for: .normal)
        playShuffledButton.imageView?.contentMode = .scaleAspectFit
        activate()
    }
    
    func activate() {
        playAllButton.isEnabled = true
        playAllButton.backgroundColor = .defaultBlue
        playShuffledButton.isEnabled = true
        playShuffledButton.backgroundColor = .defaultBlue
    }
    
    func deactivate() {
        playAllButton.isEnabled = false
        playAllButton.backgroundColor = .lightGray
        playShuffledButton.isEnabled = false
        playShuffledButton.backgroundColor = .lightGray
        
    }
    
}
