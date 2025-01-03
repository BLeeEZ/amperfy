//
//  ControlBarButton.swift
//  Amperfy
//
//  Created by David Klopp on 22.08.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import Foundation
import AmperfyKit
import UIKit

#if targetEnvironment(macCatalyst)

class ControlBarButton: CustomBarButton, MusicPlayable {
    var player: PlayerFacade?

    init(player: PlayerFacade, image: UIImage, pointSize: CGFloat = ControlBarButton.defaultPointSize) {
        self.player = player
        super.init(image: image, pointSize: pointSize)
        self.player?.addNotifier(notifier: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func didStartPlaying() {}
    func didPause() {}
    func didStopPlaying() {}
    func didStartPlayingFromBeginning() { }
    func didElapsedTimeChange() {}
    func didPlaylistChange() {}
    func didArtworkChange() {}
    func didShuffleChange() {}
    func didRepeatChange() {}
    func didPlaybackRateChange() {}
}

class PlayBarButton: ControlBarButton {
    override var title: String? {
        get { return "Play / Pause" }
        set { }
    }

    init(player: PlayerFacade) {
        super.init(player: player, image: .play)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func clicked(_ sender: UIButton) {
        self.player?.togglePlayPause()
    }

    override func didStartPlaying() {
        setCorrectImage()
    }

    override func didPause() {
        setCorrectImage()
    }

    override func didStopPlaying() {
        setCorrectImage()
    }

    override func reload() {
        super.reload()
        setCorrectImage()
    }
    
    func setCorrectImage() {
        var image = UIImage.play
        if let player = player {
            if !player.isPlaying {
                image = .play
            } else if player.isStopInsteadOfPause {
                image = .stop
            } else {
                image = .pause
            }
        }
        self.updateImage(image: image)
    }
}

class NextBarButton: ControlBarButton {
    override var title: String? {
        get { return "Next" }
        set { }
    }

    init(player: PlayerFacade) {
        super.init(player: player, image: .forwardFill)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func createInUIButton(config: UIButton.Configuration, size: CGSize) -> UIButton? {
        // Increase the highlighted area
        var newSize = size
        newSize.width = 38
        return super.createInUIButton(config: config, size: newSize)
    }

    override func clicked(_ sender: UIButton) {
        self.player?.playNext()
    }
}

class PreviousBarButton: ControlBarButton {
    override var title: String? {
        get { return "Previous" }
        set { }
    }

    init(player: PlayerFacade) {
        super.init(player: player, image: .backwardFill)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func createInUIButton(config: UIButton.Configuration, size: CGSize) -> UIButton? {
        var newSize = size
        newSize.width = 38
        return super.createInUIButton(config: config, size: newSize)
    }

    override func clicked(_ sender: UIButton) {
        self.player?.playPreviousOrReplay()
    }
}

class SkipBackwardBarButton: ControlBarButton {
    override var title: String? {
        get { return "Skip Backward" }
        set { }
    }

    init(player: PlayerFacade) {
        super.init(player: player, image: .skipBackward15)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func createInUIButton(config: UIButton.Configuration, size: CGSize) -> UIButton? {
        // Increase the highlighted area
        var newSize = size
        newSize.width = 38
        return super.createInUIButton(config: config, size: newSize)
    }

    override func clicked(_ sender: UIButton) {
        guard let player = player else { return }
        player.skipForward(interval: player.skipBackwardInterval)
    }
}

class SkipForwardBarButton: ControlBarButton {
    override var title: String? {
        get { return "Skip Forward" }
        set { }
    }

    init(player: PlayerFacade) {
        super.init(player: player, image: .skipForward30)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func createInUIButton(config: UIButton.Configuration, size: CGSize) -> UIButton? {
        // Increase the highlighted area
        var newSize = size
        newSize.width = 38
        return super.createInUIButton(config: config, size: newSize)
    }

    override func clicked(_ sender: UIButton) {
        guard let player = player else { return }
        player.skipForward(interval: player.skipForwardInterval)
    }
}

class ShuffleBarButton: ControlBarButton {
    override var title: String? {
        get { return "Shuffle" }
        set { }
    }

    init(player: PlayerFacade) {
        super.init(player: player, image: .shuffle, pointSize: ControlBarButton.smallPointSize)
        self.reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var currentTintColor: UIColor {
        if (self.active) {
            appDelegate.storage.settings.themePreference.asColor
        } else {
            super.currentTintColor
        }
    }

    override var currentBackgroundColor: UIColor {
        if (self.hovered) {
            .hoveredBackgroundColor
        } else {
            .clear
        }
    }

    override func clicked(_ sender: UIButton) {
        self.player?.toggleShuffle()
        self.reload()
    }

    override func reload() {
        super.reload()
        self.active = self.player?.isShuffle ?? false
    }

    override func didShuffleChange() {
        self.reload()
    }
}

class RepeatBarButton: ControlBarButton {
    override var title: String? {
        get { return "Repeat" }
        set { }
    }

    init(player: PlayerFacade) {
        super.init(player: player, image: .repeatOff, pointSize: ControlBarButton.smallPointSize)
        self.reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var currentTintColor: UIColor {
        if (self.active) {
            appDelegate.storage.settings.themePreference.asColor
        } else {
            super.currentTintColor
        }
    }

    override var currentBackgroundColor: UIColor {
        if (self.hovered) {
            .hoveredBackgroundColor
        } else {
            .clear
        }
    }

    override func clicked(_ sender: UIButton) {
        guard let player = self.player else { return }
        player.setRepeatMode(player.repeatMode.nextMode)
        self.reload()
    }

    override func reload() {
        super.reload()
        guard let player = self.player else { return }
        self.active = player.repeatMode != .off
        switch (player.repeatMode) {
        case .off: self.updateImage(image: .repeatOff)
        case .single: self.updateImage(image: .repeatOne)
        case .all: self.updateImage(image: .repeatAll)
        }

    }

    override func didRepeatChange() {
        self.reload()
    }
}

#endif
