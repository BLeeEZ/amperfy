//
//  CommonScreenOperations.swift
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

import AmperfyKit
import Foundation
import UIKit

extension UIView {
  static let defaultMarginX: CGFloat = 25
  static let defaultMarginY: CGFloat = 11
  static let defaultMarginTopElement = UIEdgeInsets(
    top: 0.0,
    left: UIView.defaultMarginX,
    bottom: 0.0,
    right: UIView.defaultMarginX
  )
  static let defaultMarginMiddleElement = UIEdgeInsets(
    top: UIView.defaultMarginY,
    left: UIView.defaultMarginX,
    bottom: UIView.defaultMarginY,
    right: UIView.defaultMarginX
  )
  static let defaultMarginCellX: CGFloat = 16
  static let defaultMarginCellY: CGFloat = 9
  static let defaultMarginCell = UIEdgeInsets(
    top: UIView.defaultMarginCellY,
    left: UIView.defaultMarginCellX,
    bottom: UIView.defaultMarginCellY,
    right: UIView.defaultMarginCellX
  )
}

// MARK: - CommonScreenOperations

class CommonScreenOperations {
  /// Scales with the user's text size (40pt at the default text size)
  @MainActor
  static var tableSectionHeightLarge: CGFloat { TextScaling.scaledValue(40) }
}

// MARK: - Entity preview context menu

extension UIViewController {
  /// Context menu with a preview of the container.
  /// The container gets synced with the server of the account while the preview is displayed.
  func createEntityPreviewContextMenuConfiguration(
    for containable: PlayableContainable,
    at indexPath: IndexPath,
    account: Account?,
    playContextCb: GetPlayContextCallback?
  )
    -> UIContextMenuConfiguration {
    let identifier = NSString(string: TableViewPreviewInfo(
      playableContainerIdentifier: containable.containerIdentifier,
      indexPath: indexPath
    ).asJSONString())
    return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
      let vc = EntityPreviewVC()
      vc.display(container: containable, on: self)
      Task { @MainActor in
        do {
          if let account = account {
            try await containable.fetch(
              storage: self.appDelegate.storage,
              librarySyncer: self.appDelegate.getMeta(account.info).librarySyncer,
              playableDownloadManager: self.appDelegate.getMeta(account.info)
                .playableDownloadManager
            )
          }
        } catch {
          self.appDelegate.eventLogger.report(topic: "Preview Sync", error: error)
        }
        vc.refresh()
      }
      return vc
    }) { suggestedActions in
      EntityPreviewActionBuilder(
        container: containable,
        on: self,
        playContextCb: playContextCb
      ).createMenu()
    }
  }

  /// Opens the container the context menu preview has been created for.
  func performEntityPreviewTransition(for configuration: UIContextMenuConfiguration) {
    guard let identifier = configuration.identifier as? String,
          let tvPreviewInfo = TableViewPreviewInfo.create(fromIdentifier: identifier),
          let containerIdentifier = tvPreviewInfo.playableContainerIdentifier,
          let container = appDelegate.storage.main.library
          .getContainer(identifier: containerIdentifier)
    else { return }
    EntityPreviewActionBuilder(container: container, on: self).performPreviewTransition()
  }
}

// MARK: - UIViewController

extension UIViewController {
  private func openSettings() {
    #if targetEnvironment(macCatalyst)
      appDelegate.showSettings(sender: "")
    #else
      let nav = AppStoryboard.Main.segueToSettings()
      nav.modalPresentationStyle = .formSheet
      present(nav, animated: true)
    #endif
  }

  public func setupUserNavButton() {
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      image: .settingsFilled,
      primaryAction: UIAction { [weak self] _ in
        self?.openSettings()
      }
    )
    navigationItem.leftBarButtonItem?.accessibilityLabel = "Settings"
  }
}
