//
//  PlayerControlView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 07.02.24.
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

import UIKit
import MediaPlayer
import MarqueeLabel
import AmperfyKit
import PromiseKit

class PlayerControlView: UIView {
  
    static let frameHeight: CGFloat = 210
    static private let margin = UIEdgeInsets(top: 0, left: UIView.defaultMarginX, bottom: 20, right: UIView.defaultMarginX)
    
    private var appDelegate: AppDelegate!
    private var player: PlayerFacade!
    private var rootView: PopupPlayerVC?
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var skipBackwardButton: UIButton!
    @IBOutlet weak var skipForwardButton: UIButton!
    
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var elapsedTimeLabel: UILabel!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    
    @IBOutlet weak var playerModeButton: UIButton!
    @IBOutlet weak var displayPlaylistButton: UIButton!
    @IBOutlet weak var playbackRateButton: UIButton!
    @IBOutlet weak var sleepTimerButton: UIButton!
    @IBOutlet weak var optionsButton: UIButton!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
        player = appDelegate.player
        player.addNotifier(notifier: self)
    }
    
    func prepare(toWorkOnRootView: PopupPlayerVC? ) {
        self.rootView = toWorkOnRootView
        refreshPlayer()
    }
    
    @IBAction func playButtonPushed(_ sender: Any) {
        player.togglePlayPause()
        refreshPlayButton()
    }
    
    @IBAction func previousButtonPushed(_ sender: Any) {
        switch player.playerMode {
        case .music:
            player.playPreviousOrReplay()
        case .podcast:
            player.skipBackward(interval: player.skipBackwardPodcastInterval)
        }
    }
    
    @IBAction func nextButtonPushed(_ sender: Any) {
        switch player.playerMode {
        case .music:
            player.playNext()
        case .podcast:
            player.skipForward(interval: player.skipForwardPodcastInterval)
        }
    }
    
    @IBAction func skipBackwardButtonPushed(_ sender: Any) {
        player.skipBackward(interval: player.skipBackwardMusicInterval)
    }
    
    @IBAction func skipForwardButtonPushed(_ sender: Any) {
        player.skipForward(interval: player.skipForwardMusicInterval)
    }
    
    @IBAction func timeSliderChanged(_ sender: Any) {
        if let timeSliderValue = timeSlider?.value {
            player.seek(toSecond: Double(timeSliderValue))
        }
    }
    
    @IBAction func timeSliderIsChanging(_ sender: Any) {
        if let timeSliderValue = timeSlider?.value {
            let elapsedClockTime = ClockTime(timeInSeconds: Int(timeSliderValue))
            elapsedTimeLabel.text = elapsedClockTime.asShortString()
            let remainingTime = ClockTime(timeInSeconds: Int(Double(timeSliderValue) - ceil(player.duration)))
            remainingTimeLabel.text = remainingTime.asShortString()
        }
    }
    
    @IBAction func airplayButtonPushed(_ sender: Any) {
        appDelegate.userStatistics.usedAction(.airplay)
        let rect = CGRect(x: -100, y: 0, width: 0, height: 0)
        let airplayVolume = MPVolumeView(frame: rect)
        airplayVolume.showsVolumeSlider = false
        self.addSubview(airplayVolume)
        for view: UIView in airplayVolume.subviews {
            if let button = view as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }
        airplayVolume.removeFromSuperview()
    }
    
    @IBAction private func displayPlaylistPressed() {
        appDelegate.userStatistics.usedAction(.changePlayerDisplayStyle)
        var displayStyle = appDelegate.storage.settings.playerDisplayStyle
        displayStyle.switchToNextStyle()
        appDelegate.storage.settings.playerDisplayStyle = displayStyle
        rootView?.changeDisplayStyle(to: displayStyle)
        refreshDisplayPlaylistButton()
        refreshPlayerOptions()
    }
    
    @IBAction func playerModeChangePressed(_ sender: Any) {
        switch player.playerMode {
        case .music:
            appDelegate.player.setPlayerMode(.podcast)
        case .podcast:
            appDelegate.player.setPlayerMode(.music)
        }
        refreshPlayerModeChangeButton()
    }
    
    func viewWillAppear(_ animated: Bool) {
        refreshView()
    }
    
    func refreshView() {
        refreshPlayer()

        timeSlider.setUnicolorThumbImage(thumbSize: 10.0, color: .labelColor, for: UIControl.State.normal)
        timeSlider.setUnicolorThumbImage(thumbSize: 30.0, color: .labelColor, for: UIControl.State.highlighted)
    }
    
    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        timeSlider.setUnicolorThumbImage(thumbSize: 10.0, color: .labelColor, for: UIControl.State.normal)
        timeSlider.setUnicolorThumbImage(thumbSize: 30.0, color: .labelColor, for: UIControl.State.highlighted)
    }
    
    func refreshPlayButton() {
        var buttonImg = UIImage()
        if player.isPlaying {
            buttonImg = UIImage.pause
        } else {
            buttonImg = UIImage.play
        }
        
        playButton.setImage(buttonImg, for: UIControl.State.normal)
        let barButtonItem = UIBarButtonItem(image: buttonImg, style: .plain, target: self, action: #selector(PlayerControlView.playButtonPushed))
        rootView?.popupItem.trailingBarButtonItems = [ barButtonItem ]
    }
    
    func refreshCurrentlyPlayingInfo() {
        switch player.playerMode {
        case .music:
            skipBackwardButton.isHidden = !appDelegate.storage.settings.isShowMusicPlayerSkipButtons
            skipForwardButton.isHidden = !appDelegate.storage.settings.isShowMusicPlayerSkipButtons
            skipBackwardButton.alpha = !appDelegate.storage.settings.isShowMusicPlayerSkipButtons ? 0.0 : 1.0
            skipForwardButton.alpha = !appDelegate.storage.settings.isShowMusicPlayerSkipButtons ? 0.0 : 1.0
        case .podcast:
            skipBackwardButton.isHidden = true
            skipForwardButton.isHidden = true
        }
    }

    func refreshTimeInfo() {
        if player.currentlyPlaying != nil {
            timeSlider.minimumValue = 0.0
            timeSlider.maximumValue = Float(player.duration)
            if !timeSlider.isTracking {
                let elapsedClockTime = ClockTime(timeInSeconds: Int(player.elapsedTime))
                elapsedTimeLabel.text = elapsedClockTime.asShortString()
                let remainingTime = ClockTime(timeInSeconds: Int(player.elapsedTime - ceil(player.duration)))
                remainingTimeLabel.text = remainingTime.asShortString()
                timeSlider.value = Float(player.elapsedTime)
            }
            rootView?.popupItem.progress = Float(player.elapsedTime / player.duration)
        } else {
            elapsedTimeLabel.text = "--:--"
            remainingTimeLabel.text = "--:--"
            timeSlider.minimumValue = 0.0
            timeSlider.maximumValue = 1.0
            timeSlider.value = 0.0
            rootView?.popupItem.progress = 0.0
        }
    }
    
    func refreshPlayer() {
        refreshCurrentlyPlayingInfo()
        refreshPlayButton()
        refreshTimeInfo()
        refreshPrevNextButtons()
        refreshPlaybackRateButton()
        refreshSleepTimerButton()
        refreshDisplayPlaylistButton()
        refreshPlayerModeChangeButton()
        refreshPlayerOptions()
    }
    
    func refreshPrevNextButtons() {
        previousButton.imageView?.contentMode = .scaleAspectFit
        nextButton.imageView?.contentMode = .scaleAspectFit
        switch player.playerMode {
        case .music:
            previousButton.setImage(UIImage.backwardFill, for: .normal)
            nextButton.setImage(UIImage.forwardFill, for: .normal)
        case .podcast:
            previousButton.setImage(UIImage.goBackward15, for: .normal)
            nextButton.setImage(UIImage.goForward30, for: .normal)
        }
    }
    
    func refreshPlaybackRateButton() {
        let playerPlaybackRate = self.player.playbackRate
        playbackRateButton.setTitle(playerPlaybackRate.description, for: .normal)
        
        let availablePlaybackRates: [UIAction] = PlaybackRate.allCases.compactMap { playbackRate in
            return UIAction(title: playbackRate.description, image: playbackRate == playerPlaybackRate ? .check : nil, handler: { _ in
                self.player.setPlaybackRate(playbackRate)
            })
        }
        playbackRateButton.menu = UIMenu(title: "Playback Rate", children: availablePlaybackRates)
        playbackRateButton.showsMenuAsPrimaryAction = true
    }
    
    func refreshSleepTimerButton() {
        guard let rootView = rootView else { return }
        let isSelected = appDelegate.sleepTimer != nil || self.appDelegate.player.isShouldPauseAfterFinishedPlaying
        var config = rootView.getPlayerButtonConfiguration(isSelected: isSelected)
        config.image = UIImage.sleepFill
        sleepTimerButton.isSelected = isSelected
        sleepTimerButton.configuration = config
        
        if let timer = appDelegate.sleepTimer {
            let deactivate = UIAction(title: "Off", image: nil, handler: { _ in
                self.appDelegate.sleepTimer?.invalidate()
                self.appDelegate.sleepTimer = nil
                self.refreshSleepTimerButton()
            })
            sleepTimerButton.menu = UIMenu(title: "Will pause at: \(timer.fireDate.asShortHrMinString)", children: [deactivate])
        } else if self.appDelegate.player.isShouldPauseAfterFinishedPlaying {
            let deactivate = UIAction(title: "Off", image: nil, handler: { _ in
                self.appDelegate.player.isShouldPauseAfterFinishedPlaying = false
                self.refreshSleepTimerButton()
            })
            switch player.playerMode {
            case .music:
                sleepTimerButton.menu = UIMenu(title: "Will pause at end of song", children: [deactivate])
            case .podcast:
                sleepTimerButton.menu = UIMenu(title: "Will pause at end of episode", children: [deactivate])
            }
        } else {
            let endOfTrack = UIAction(title: "End of song or episode", image: nil, handler: { _ in
                self.appDelegate.player.isShouldPauseAfterFinishedPlaying = true
                self.refreshSleepTimerButton()
            })
            let sleep5 = UIAction(title: "5 Minutes", image: nil, handler: { _ in
                self.activateSleepTimer(timeInterval: TimeInterval(5 * 60))
                self.refreshSleepTimerButton()
            })
            let sleep10 = UIAction(title: "10 Minutes", image: nil, handler: { _ in
                self.activateSleepTimer(timeInterval: TimeInterval(10 * 60))
                self.refreshSleepTimerButton()
            })
            let sleep15 = UIAction(title: "15 Minutes", image: nil, handler: { _ in
                self.activateSleepTimer(timeInterval: TimeInterval(15 * 60))
                self.refreshSleepTimerButton()
            })
            let sleep30 = UIAction(title: "30 Minutes", image: nil, handler: { _ in
                self.activateSleepTimer(timeInterval: TimeInterval(30 * 60))
                self.refreshSleepTimerButton()
            })
            let sleep45 = UIAction(title: "45 Minutes", image: nil, handler: { _ in
                self.activateSleepTimer(timeInterval: TimeInterval(45 * 60))
                self.refreshSleepTimerButton()
            })
            let sleep60 = UIAction(title: "1 Hour", image: nil, handler: { _ in
                self.activateSleepTimer(timeInterval: TimeInterval(60 * 60))
                self.refreshSleepTimerButton()
            })
            sleepTimerButton.menu = UIMenu(title: "Sleep Timer", children: [endOfTrack, sleep5, sleep10, sleep15, sleep30, sleep45, sleep60])
        }
        sleepTimerButton.showsMenuAsPrimaryAction = true
    }
    
    func refreshPlayerOptions() {
        var menuActions = [UIAction]()
        if player.currentlyPlaying != nil || player.prevQueue.count > 0 || player.userQueue.count > 0 || player.nextQueue.count > 0 {
            let clearPlayer = UIAction(title: "Clear Player", image: .clear, handler: { _ in
                self.player.clearQueues()
            })
            menuActions.append(clearPlayer)
        }
        if player.userQueue.count > 0 {
            let clearUserQueue = UIAction(title: "Clear User Queue", image: .playlistX, handler: { _ in
                self.rootView?.clearUserQueue()
            })
            menuActions.append(clearUserQueue)
        }
        
        switch player.playerMode {
        case .music:
            if player.currentlyPlaying != nil || player.prevQueue.count > 0 || player.nextQueue.count > 0 {
                let addContextToPlaylist = UIAction(title: "Add Context Queue to Playlist", image: .playlistPlus, handler: { _ in
                    let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
                    var itemsToAdd = self.player.prevQueue.filterSongs()
                    if let currentlyPlaying = self.player.currentlyPlaying, currentlyPlaying.isSong {
                        itemsToAdd.append(currentlyPlaying)
                    }
                    itemsToAdd.append(contentsOf: self.player.nextQueue.filterSongs())
                    selectPlaylistVC.itemsToAdd = itemsToAdd
                    let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
                    self.rootView?.present(selectPlaylistNav, animated: true, completion: nil)
                })
                menuActions.append(addContextToPlaylist)
            }
        case .podcast: break
        }

        switch self.appDelegate.storage.settings.playerDisplayStyle {
        case .compact:
            let scrollToCurrentlyPlaying = UIAction(title: "Scroll to currently playing", image: .squareArrow, handler: { _ in
                self.rootView?.scrollToCurrentlyPlayingRow()
            })
            menuActions.append(scrollToCurrentlyPlaying)
        case .large: break
        }

        optionsButton.menu = UIMenu(title: "Player Options", children: menuActions)
        optionsButton.showsMenuAsPrimaryAction = true
    }
    
    func activateSleepTimer(timeInterval: TimeInterval) {
        appDelegate.sleepTimer?.invalidate()
        appDelegate.sleepTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { (t) in
            self.appDelegate.player.pause()
            self.appDelegate.eventLogger.info(topic: "Sleep Timer", message: "Sleep timer paused playback.")
            self.appDelegate.sleepTimer?.invalidate()
            self.appDelegate.sleepTimer = nil
            self.refreshSleepTimerButton()
        }
    }
    
    func refreshDisplayPlaylistButton() {
        guard let rootView = rootView else { return }
        let isSelected = appDelegate.storage.settings.playerDisplayStyle == .compact
        var config = rootView.getPlayerButtonConfiguration(isSelected: isSelected)
        config.image = .playlistDisplayStyle
        displayPlaylistButton.isSelected = isSelected
        displayPlaylistButton.configuration = config
    }
    
    func refreshPlayerModeChangeButton() {
        switch player.playerMode {
        case .music:
            playerModeButton.setImage(UIImage.musicalNotes, for: .normal)
        case .podcast:
            playerModeButton.setImage(UIImage.podcast, for: .normal)
        }
    }
    
}

extension PlayerControlView: MusicPlayable {

    func didStartPlaying() {
        refreshPlayer()
    }
    
    func didPause() {
        refreshPlayer()
    }
    
    func didStopPlaying() {
        refreshPlayer()
        refreshCurrentlyPlayingInfo()
    }

    func didElapsedTimeChange() {
        refreshTimeInfo()
    }
    
    func didPlaylistChange() {
        refreshPlayer()
    }
    
    func didArtworkChange() {
    }
    
    func didShuffleChange() {
    }
    
    func didRepeatChange() {
    }
    
    func didPlaybackRateChange() {
        refreshPlaybackRateButton()
    }

}
