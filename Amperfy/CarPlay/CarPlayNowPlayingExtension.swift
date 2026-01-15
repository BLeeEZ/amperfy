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

import AmperfyKit
import CarPlay
import Foundation

extension CarPlaySceneDelegate {
  static let queueButtonText = NSLocalizedString(
    "Queue",
    comment: "Button title on CarPlay player to display queue"
  )

  func updatePlayerQueueSection() {
    playerQueueSection.updateSections(createPlayerQueueSections())
  }

  func configureNowPlayingTemplate() {
    var buttons: [CPNowPlayingButton] = []
    buttons.append(
      CPNowPlayingRepeatButton(handler: { [weak self] button in
        guard let self = self else { return }
        appDelegate.player.setRepeatMode(appDelegate.player.repeatMode.nextMode)
      })
    )
    if appDelegate.player.playerMode == .music {
      buttons.append(
        CPNowPlayingShuffleButton(handler: { [weak self] button in
          guard let self = self else { return }
          appDelegate.player.toggleShuffle()
        })
      )
      if let currentlyPlaying = appDelegate.player.currentlyPlaying,
         !currentlyPlaying.isRadio {
        let isFavorite = appDelegate.player.currentlyPlaying?.isFavorite ?? false
        buttons.append(
          CPNowPlayingImageButton(
            image: isFavorite ? .heartFill : .heartEmpty,
            handler: { [weak self] button in
              guard let self = self else { return }
              guard let playableInfo = appDelegate.player.currentlyPlaying,
                    let account = playableInfo.account else { return }
              Task { @MainActor in
                do {
                  try await playableInfo
                    .remoteToggleFavorite(
                      syncer: self.appDelegate
                        .getMeta(account.info).librarySyncer
                    )
                } catch {
                  self.appDelegate.eventLogger.report(topic: "Toggle Favorite", error: error)
                }
                self.configureNowPlayingTemplate()
              }
            }
          )
        )
      }
    }
    buttons.append(
      CPNowPlayingPlaybackRateButton(handler: { [weak self] button in
        guard let self = self else { return }
        let availablePlaybackRates: [CPListItem] = PlaybackRate.allCases
          .compactMap { playbackRate in
            let listItem = CPListItem(text: playbackRate.description, detailText: nil)
            listItem.handler = { [weak self] item, completion in
              guard let self = self else { completion(); return }
              appDelegate.player.setPlaybackRate(playbackRate)
              interfaceController?.popTemplate(animated: true) { _, _ in }
              completion()
            }
            return listItem
          }
        let playbackRateTemplate = CPListTemplate(title: "Playback Rate", sections: [
          CPListSection(items: availablePlaybackRates),
        ])
        interfaceController?.pushTemplate(playbackRateTemplate, animated: true, completion: nil)

      })
    )
    CPNowPlayingTemplate.shared.updateNowPlayingButtons(buttons)
    CPNowPlayingTemplate.shared.isUpNextButtonEnabled = true
  }

  func displayNowPlaying(immediately: Bool = false, completion: @escaping (() -> ())) {
    configureNowPlayingTemplate()
    if immediately {
      interfaceController?
        .pushTemplate(CPNowPlayingTemplate.shared, animated: false) { _, _ in }
      completion()
    } else {
      Task { @MainActor in
        let _ = try? await interfaceController?.popToRootTemplate(animated: false)
        let _ = try? await self.interfaceController?
          .pushTemplate(CPNowPlayingTemplate.shared, animated: true)
        completion()
      }
    }
  }
}

// MARK: - CarPlaySceneDelegate + CPNowPlayingTemplateObserver

extension CarPlaySceneDelegate: CPNowPlayingTemplateObserver {
  nonisolated func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
    MainActor.assumeIsolated {
      self.interfaceController?.pushTemplate(playerQueueSection, animated: true, completion: nil)
    }
  }

  func createPlayerQueueSections() -> [CPListSection] {
    var queueSection = [CPListSection]()

    let userQueueCount = appDelegate.player.userQueueCount
    let userQueueMax = min(userQueueCount - 1, CPListTemplate.maximumItemCount - 1)
    let userQueue = appDelegate.player.getUserQueueItems(from: 0, to: userQueueMax)
    if userQueueCount > 0 {
      var userQueueItems = [CPListItem]()
      for (index, userQueueItem) in userQueue.enumerated() {
        let playerIndex = PlayerIndex(queueType: .user, index: index)
        let listItem = createQueueItem(for: userQueueItem, playerIndex: playerIndex)
        userQueueItems.append(listItem)
        if userQueueItems.count >= CPListTemplate.maximumItemCount {
          break
        }
      }
      let userQueueSection = CPListSection(
        items: userQueueItems,
        header: "Next in Queue",
        sectionIndexTitle: nil
      )
      queueSection.append(userQueueSection)
    }

    if userQueueCount < CPListTemplate.maximumItemCount {
      let nextQueueCount = appDelegate.player.nextQueueCount
      let nextQueueMax = min(nextQueueCount - 1, CPListTemplate.maximumItemCount - 1)
      let nextQueue = appDelegate.player.getNextQueueItems(from: 0, to: nextQueueMax)
      if !nextQueue.isEmpty {
        var nextQueueItems = [CPListItem]()
        for (index, nextQueueItem) in nextQueue.enumerated() {
          let playerIndex = PlayerIndex(queueType: .next, index: index)
          let listItem = createQueueItem(for: nextQueueItem, playerIndex: playerIndex)
          nextQueueItems.append(listItem)
          if (userQueue.count + nextQueueItems.count) >= CPListTemplate.maximumItemCount {
            break
          }
        }
        let nextQueueSection = CPListSection(
          items: nextQueueItems,
          header: "Next from: \(appDelegate.player.contextName)",
          sectionIndexTitle: nil
        )
        queueSection.append(nextQueueSection)
      }
    }
    return queueSection
  }

  private func createQueueItem(
    for playable: AbstractPlayable,
    playerIndex: PlayerIndex
  )
    -> CPListItem {
    let accessoryType: CPListItemAccessoryType = playable.isCached ? .cloud : .none
    let image = LibraryEntityImage.getImageToDisplayImmediately(
      libraryEntity: playable,
      themePreference: getPreference(playable.account?.info).theme,
      artworkDisplayPreference: getPreference(playable.account?.info).artworkDisplayPreference,
      useCache: false
    )
    let listItem = CPListItem(
      text: playable.title,
      detailText: playable.subtitle,
      image: image.carPlayImage(carTraitCollection: traits),
      accessoryImage: nil,
      accessoryType: accessoryType
    )
    listItem.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      appDelegate.player.play(playerIndex: playerIndex)
      Task { @MainActor in
        guard let _ = try? await interfaceController?.popTemplate(animated: true) else { return }
        completion()
      }
    }
    return listItem
  }
}

// MARK: - CarPlaySceneDelegate + MusicPlayable

extension CarPlaySceneDelegate: MusicPlayable {
  func didStartPlayingFromBeginning() {}
  func didStartPlaying() {
    configureNowPlayingTemplate()
    updatePlayerQueueSection()
  }

  func didPause() {}
  func didStopPlaying() {}
  func didElapsedTimeChange() {}
  func didPlaylistChange() {
    updatePlayerQueueSection()
  }

  func didArtworkChange() {}
  func didShuffleChange() {}
  func didRepeatChange() {}
  func didPlaybackRateChange() {}
}
