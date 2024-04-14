//
//  CarPlayNowPlayingExtension.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 31.01.24.
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
import CarPlay
import AmperfyKit
import PromiseKit

extension CarPlaySceneDelegate {
    func configureNowPlayingTemplate() {
        var buttons: [CPNowPlayingButton] = []
        buttons.append(
            CPNowPlayingRepeatButton(handler: { [weak self] button in
                guard let `self` = self else { return }
                self.appDelegate.player.setRepeatMode(self.appDelegate.player.repeatMode.nextMode)
            })
        )
        buttons.append(
            CPNowPlayingShuffleButton(handler: { [weak self] button in
                guard let `self` = self else { return }
                self.appDelegate.player.toggleShuffle()
            })
        )
        if appDelegate.player.playerMode == .music {
            let isFavorite =  appDelegate.player.currentlyPlaying?.isFavorite ?? false
            buttons.append(
                CPNowPlayingImageButton(image: isFavorite ? .heartFill : .heartEmpty, handler: { [weak self] button in
                    guard let `self` = self else { return }
                    guard let playableInfo = appDelegate.player.currentlyPlaying else { return }
                    firstly {
                        playableInfo.remoteToggleFavorite(syncer: self.appDelegate.librarySyncer)
                    }.catch { error in
                        self.appDelegate.eventLogger.report(topic: "Toggle Favorite", error: error)
                    }.finally {
                        self.configureNowPlayingTemplate()
                    }
                })
            )
        }
        buttons.append(
            CPNowPlayingPlaybackRateButton(handler: { [weak self] button in
                guard let `self` = self else { return }
                let availablePlaybackRates: [CPListItem] = PlaybackRate.allCases.compactMap { playbackRate in
                    let listItem = CPListItem(text: playbackRate.description, detailText: nil)
                    listItem.handler = { [weak self] item, completion in
                        guard let `self` = self else { completion(); return }
                        self.appDelegate.player.setPlaybackRate(playbackRate)
                        self.interfaceController?.popTemplate(animated: true) { _,_ in }
                        completion()
                    }
                    return listItem
                }
                let playbackRateTemplate = CPListTemplate(title: "Playback Rate", sections: [
                    CPListSection(items: availablePlaybackRates)
                ])
                self.interfaceController?.pushTemplate(playbackRateTemplate, animated: true, completion: nil)
                
            })
        )
        CPNowPlayingTemplate.shared.updateNowPlayingButtons(buttons)
        CPNowPlayingTemplate.shared.upNextTitle = Self.queueButtonText
        CPNowPlayingTemplate.shared.isUpNextButtonEnabled = true
    }
    
    func displayNowPlaying(completion: @escaping (() -> Void)) {
        configureNowPlayingTemplate()
        self.interfaceController?.popToRootTemplate(animated: false) { _,_ in
            self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { _,_ in completion() }
        }
    }
}

extension CarPlaySceneDelegate: CPNowPlayingTemplateObserver {
    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        self.interfaceController?.pushTemplate(playerQueueSection, animated: true, completion: nil)
    }
    
    func createPlayerQueueSections() -> [CPListSection] {
        var queueSection = [CPListSection]()
        
        let userQueue = appDelegate.player.userQueue
        if userQueue.count > 0 {
            var userQueueItems = [CPListItem]()
            for (index, userQueueItem) in appDelegate.player.userQueue.enumerated() {
                let playerIndex = PlayerIndex(queueType: .user, index: index)
                let listItem = self.createQueueItem(for: userQueueItem, playerIndex: playerIndex)
                userQueueItems.append(listItem)
                if userQueueItems.count >= CPListTemplate.maximumItemCount {
                    break
                }
            }
            let userQueueSection = CPListSection(items: userQueueItems, header: "Next in Queue", sectionIndexTitle: nil)
            queueSection.append(userQueueSection)
        }

        if userQueue.count < CPListTemplate.maximumItemCount {
            let nextQueue = appDelegate.player.nextQueue
            if nextQueue.count > 0 {
                var nextQueueItems = [CPListItem]()
                for (index, nextQueueItem) in appDelegate.player.nextQueue.enumerated() {
                    let playerIndex = PlayerIndex(queueType: .next, index: index)
                    let listItem = self.createQueueItem(for: nextQueueItem, playerIndex: playerIndex)
                    nextQueueItems.append(listItem)
                    if (userQueue.count + nextQueueItems.count) >= CPListTemplate.maximumItemCount {
                        break
                    }
                }
                let nextQueueSection = CPListSection(items: nextQueueItems, header: "Next from: \(appDelegate.player.contextName)", sectionIndexTitle: nil)
                queueSection.append(nextQueueSection)
            }
        }
        return queueSection
    }
    
    private func createQueueItem(for playable: AbstractPlayable, playerIndex: PlayerIndex) -> CPListItem {
        let accessoryType: CPListItemAccessoryType = playable.isCached ? .cloud : .none
        let image = playable.image(setting: artworkDisplayPreference)
        let listItem = CPListItem(text: playable.title, detailText: playable.subtitle, image: image.carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: accessoryType)
        listItem.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            self.appDelegate.player.play(playerIndex: playerIndex)
            self.interfaceController?.popTemplate(animated: true) { _,_ in
                completion()
            }
        }
        return listItem
    }
}

extension CarPlaySceneDelegate: MusicPlayable {
    func didStartPlaying() {
        configureNowPlayingTemplate()
        playerQueueSection.updateSections(createPlayerQueueSections())
    }
    func didPause() { }
    func didStopPlaying() { }
    func didElapsedTimeChange() { }
    func didPlaylistChange() {
        playerQueueSection.updateSections(createPlayerQueueSections())
    }
    func didArtworkChange() { }
    func didShuffleChange() { }
    func didRepeatChange() { }
    func didPlaybackRateChange() { }
    
}
