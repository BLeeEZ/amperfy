//
//  CarPlaySavedQueuesExtension.swift
//  Amperfy
//
//  Created by Amperfy Contributors on 11.06.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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
  func createSavedQueuesSections() -> [CPListSection] {
    guard let activeAccount else { return [] }
    let savedQueues = appDelegate.savedQueues.list(forAccount: activeAccount)
    let formatter = RelativeDateTimeFormatter()
    var items = [CPListTemplateItem]()
    for savedQueue in savedQueues.prefix(CPListTemplate.maximumItemCount) {
      let dateString = formatter.localizedString(for: savedQueue.lastUsedAt, relativeTo: Date())
      let item = CPListItem(
        text: savedQueue.name,
        detailText: "\(savedQueue.songCount) Songs · \(dateString)",
        image: UIImage.createArtwork(
          with: UIImage.savedQueues,
          iconSizeType: .small,
          theme: getPreference(activeAccountInfo).theme,
          lightDarkMode: traits.userInterfaceStyle.asModeType,
          switchColors: true
        ).carPlayImage(carTraitCollection: traits)
      )
      item.handler = { [weak self] _, completion in
        guard let self else { completion(); return }
        Task { @MainActor in
          guard await appDelegate.savedQueues.restore(savedQueue) else {
            completion()
            return
          }
          appDelegate.player.playCurrentItem()
          displayNowPlaying {
            completion()
          }
        }
      }
      items.append(item)
    }
    return [CPListSection(items: items)]
  }

  @objc
  func refreshSavedQueues() {
    guard let templates = interfaceController?.templates,
          templates.contains(savedQueuesSection) else { return }
    savedQueuesSection.updateSections(createSavedQueuesSections())
  }
}
