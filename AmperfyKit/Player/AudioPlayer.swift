//
//  AudioPlayer.swift
//  AmperfyKit
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

import Foundation
import AVFoundation
import MediaPlayer
import os.log

public class AudioPlayer: NSObject, BackendAudioPlayerNotifiable  {
    
    public static let replayInsteadPlayPreviousTimeInSec = 5.0
    static let progressTimeStartThreshold: Double = 15.0
    static let progressTimeEndThreshold: Double = 15.0
    
    var currentlyPlaying: AbstractPlayable? {
        return queueHandler.currentlyPlaying
    }
    var currentMusicItem: AbstractPlayable? {
        return queueHandler.currentMusicItem
    }
    var currentPodcastItem: AbstractPlayable? {
        return queueHandler.currentPodcastItem
    }
    var isShouldPauseAfterFinishedPlaying = false

    private var playerStatus: PlayerStatusPersistent
    private var queueHandler: PlayQueueHandler
    private let backendAudioPlayer: BackendAudioPlayer
    private let settings: PersistentStorage.Settings
    private let userStatistics: UserStatistics
    private var notifierList = [MusicPlayable]()

    init(coreData: PlayerStatusPersistent, queueHandler: PlayQueueHandler, backendAudioPlayer: BackendAudioPlayer, settings: PersistentStorage.Settings, userStatistics: UserStatistics) {
        self.playerStatus = coreData
        self.queueHandler = queueHandler
        self.backendAudioPlayer = backendAudioPlayer
        self.backendAudioPlayer.isAutoCachePlayedItems = coreData.isAutoCachePlayedItems
        self.settings = settings
        self.userStatistics = userStatistics
        super.init()
        self.backendAudioPlayer.responder = self
    }

    func reinit(playerStatus: PlayerData, queueHandler: PlayQueueHandler) {
        self.playerStatus = playerStatus
        self.queueHandler = queueHandler
    }
    
    private func shouldCurrentItemReplayedInsteadOfPrevious() -> Bool {
        if !backendAudioPlayer.canBeContinued {
            return false
        }
        return backendAudioPlayer.elapsedTime >= Self.replayInsteadPlayPreviousTimeInSec
    }

    private func replayCurrentItem() {
        os_log(.debug, "Replay")
        backendAudioPlayer.seek(toSecond: 0)
        play()
        notifyItemStartedPlayingFromBeginning()
    }

    private func insertIntoPlayer(playable: AbstractPlayable) {
        userStatistics.playedItem(repeatMode: playerStatus.repeatMode, isShuffle: playerStatus.isShuffle)
        playable.countPlayed()
        backendAudioPlayer.requestToPlay(playable: playable, playbackRate: playerStatus.playbackRate, autoStartPlayback: !self.settings.isPlaybackStartOnlyOnPlay)
    }
    
    //BackendAudioPlayerNotifiable
    func notifyItemPreparationFinished() {
        notifyItemStartedPlayingFromBeginning()
        notifyItemStartedPlaying()
    }
    
    //BackendAudioPlayerNotifiable
    func didItemFinishedPlaying() {
        if isShouldPauseAfterFinishedPlaying {
            isShouldPauseAfterFinishedPlaying = false
            pause()
        } else if playerStatus.repeatMode == .single {
            replayCurrentItem()
        } else {
            playNext()
        }
    }
    
    func play() {
        if !backendAudioPlayer.canBeContinued {
            if let currentPlayable = currentlyPlaying {
                insertIntoPlayer(playable: currentPlayable)
            }
        } else {
            backendAudioPlayer.continuePlay()
            notifyItemStartedPlaying()
        }
        WidgetUtils.saveCurrentSong(song: currentlyPlaying?.asSong)
    }

    public func play(context: PlayContext) {
        guard let activePlayable = context.getActivePlayable() else { return }
        let topUserQueueItem = queueHandler.userQueue.first
        let wasUserQueuePlaying = queueHandler.isUserQueuePlaying
        queueHandler.clearActiveQueue()
        queueHandler.appendActiveQueue(playables: context.playables)
        if context.type == .music {
            queueHandler.contextName = context.name
        }
        
        if queueHandler.isUserQueuePlaying {
            play(playerIndex: PlayerIndex(queueType: .next, index: context.index))
            if !wasUserQueuePlaying, let topUserQueueItem = topUserQueueItem {
                queueHandler.insertUserQueue(playables: [topUserQueueItem])
            }
        } else if context.index == 0 {
            insertIntoPlayer(playable: activePlayable)
        } else {
            play(playerIndex: PlayerIndex(queueType: .next, index: context.index-1))
        }
        WidgetUtils.saveCurrentSong(song: currentlyPlaying?.asSong)
    }
    
    func play(playerIndex: PlayerIndex) {
        guard let playable = queueHandler.markAndGetPlayableAsPlaying(at: playerIndex) else {
            stop()
            return
        }
        insertIntoPlayer(playable: playable)
        WidgetUtils.saveCurrentSong(song: currentlyPlaying?.asSong)
    }
    
    func playPreviousOrReplay() {
        if shouldCurrentItemReplayedInsteadOfPrevious() {
            replayCurrentItem()
        } else {
            playPrevious()
        }
        WidgetUtils.saveCurrentSong(song: currentlyPlaying?.asSong)
    }

    //BackendAudioPlayerNotifiable
    func playPrevious() {
        if !queueHandler.prevQueue.isEmpty {
            play(playerIndex: PlayerIndex(queueType: .prev, index: queueHandler.prevQueue.count-1))
        } else if playerStatus.repeatMode == .all, !queueHandler.nextQueue.isEmpty {
            play(playerIndex: PlayerIndex(queueType: .next, index: queueHandler.nextQueue.count-1))
        } else {
            replayCurrentItem()
        }
        WidgetUtils.saveCurrentSong(song: currentlyPlaying?.asSong)
    }

    //BackendAudioPlayerNotifiable
    func playNext() {
        if queueHandler.userQueue.count > 0 {
            play(playerIndex: PlayerIndex(queueType: .user, index: 0))
        } else if queueHandler.nextQueue.count > 0 {
            play(playerIndex: PlayerIndex(queueType: .next, index: 0))
        } else if playerStatus.repeatMode == .all, !queueHandler.prevQueue.isEmpty {
            play(playerIndex: PlayerIndex(queueType: .prev, index: 0))
        } else {
            stop()
        }
        WidgetUtils.saveCurrentSong(song: currentlyPlaying?.asSong)
    }
    
    func pause() {
        backendAudioPlayer.pause()
        notifyItemPaused()
        WidgetUtils.saveCurrentSong(song: currentlyPlaying?.asSong)
    }
    
    //BackendAudioPlayerNotifiable
    func stop() {
        backendAudioPlayer.stop()
        playerStatus.stop()
        notifyPlayerStopped()
        WidgetUtils.saveCurrentSong(song: currentlyPlaying?.asSong)
    }
    
    func stopButRemainIndex() {
        backendAudioPlayer.stop()
        notifyPlayerStopped()
        WidgetUtils.saveCurrentSong(song: currentlyPlaying?.asSong)
    }
    
    func togglePlayPause() {
        if(backendAudioPlayer.isPlaying) {
            pause()
        } else {
            play()
        }
    }
    
    private func seekToLastStoppedPlayTime() {
        if let playable = currentlyPlaying, playable.isPodcastEpisode, playable.playProgress > 0 {
            backendAudioPlayer.seek(toSecond: Double(playable.playProgress))
        }
    }

    //BackendAudioPlayerNotifiable
    func didElapsedTimeChange() {
        notifyElapsedTimeChanged()
        if let currentItem = currentlyPlaying {
            savePlayInformation(of: currentItem)
        }
    }
    
    //BackendAudioPlayerNotifiable
    func didLyricsTimeChange(time: CMTime) {
        notifyLyricsTimeChanged(time: time)
    }
    
    private func savePlayInformation(of playable: AbstractPlayable) {
        let playDuration = backendAudioPlayer.duration
        let playProgress = backendAudioPlayer.elapsedTime
        if playDuration != 0.0, playProgress != 0.0, playable == currentlyPlaying {
            playable.playDuration = Int(playDuration)
            if playProgress > Self.progressTimeStartThreshold, playProgress < (playDuration - Self.progressTimeEndThreshold) {
                playable.playProgress = Int(playProgress)
            } else {
                playable.playProgress = 0
            }
        }
    }
    
    func addNotifier(notifier: MusicPlayable) {
        notifierList.append(notifier)
    }
    
    func removeAllNotifier() {
        notifierList.removeAll()
    }
    
    func notifyItemStartedPlayingFromBeginning() {
        for notifier in notifierList {
            notifier.didStartPlayingFromBeginning()
        }
        seekToLastStoppedPlayTime()
        WidgetUtils.setPlaybackStatus(isPlaying: true)
    }

    func notifyItemStartedPlaying() {
        for notifier in notifierList {
            notifier.didStartPlaying()
        }
        WidgetUtils.setPlaybackStatus(isPlaying: true)
    }
    
    //BackendAudioPlayerNotifiable
    func notifyErrorOccured(error: Error) {
        for notifier in notifierList {
            notifier.errorOccured(error: error)
        }
        WidgetUtils.setPlaybackStatus(isPlaying: false)
    }
    
    func notifyItemPaused() {
        for notifier in notifierList {
            notifier.didPause()
        }
        WidgetUtils.setPlaybackStatus(isPlaying: false)
    }
    
    func notifyPlayerStopped() {
        for notifier in notifierList {
            notifier.didStopPlaying()
        }
        WidgetUtils.setPlaybackStatus(isPlaying: false)
    }
    
    func notifyArtworkChanged() {
        for notifier in notifierList {
            notifier.didArtworkChange()
        }
    }
    
    func notifyElapsedTimeChanged() {
        for notifier in notifierList {
            notifier.didElapsedTimeChange()
        }
    }
    
    func notifyLyricsTimeChanged(time: CMTime) {
        for notifier in notifierList {
            notifier.didLyricsTimeChange(time: time)
        }
    }
    
    func notifyPlaylistUpdated() {
        for notifier in notifierList {
            notifier.didPlaylistChange()
        }
    }

    func notifyShuffleUpdated() {
        for notifier in notifierList {
            notifier.didShuffleChange()
        }
    }

    func notifyRepeatUpdated() {
        for notifier in notifierList {
            notifier.didRepeatChange()
        }
    }
    
    func notifyPlaybackRateUpdated() {
        for notifier in notifierList {
            notifier.didPlaybackRateChange()
        }
    }

}
