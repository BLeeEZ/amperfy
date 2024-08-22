//
//  ControlBarButton.swift
//  Amperfy
//
//  Created by David Klopp on 22.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import AmperfyKit
import UIKit

#if targetEnvironment(macCatalyst)

class ControlBarButton: CustomBarButton, MusicPlayable {
    var player: PlayerFacade?

    init(player: PlayerFacade, image: UIImage) {
        self.player = player
        super.init(image: image)
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
        self.updateImage(image: .pause)
    }

    override func didPause() {
        self.updateImage(image: .play)
    }

    override func didStopPlaying() {
        self.updateImage(image: .play)
    }

    override func reload() {
        if player?.isPlaying ?? false {
            self.updateImage(image: .pause)
        } else {
            self.updateImage(image: .play)
        }
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

#endif
