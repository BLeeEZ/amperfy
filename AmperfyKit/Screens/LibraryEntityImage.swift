//
//  LibraryEntityImage.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 10.06.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

import CoreData
import UIKit

@MainActor
public class LibraryEntityImage: RoundedImage {
  static let cache: NSCache<NSManagedObjectID, UIImage> = NSCache()

  let appDelegate: AmperKit
  var entity: AbstractLibraryEntity?
  var backupImage: UIImage?
  var imagePreparationTask: Task<(), Never>?

  required public init?(coder: NSCoder) {
    self.appDelegate = AmperKit.shared
    super.init(coder: coder)
    appDelegate.notificationHandler.register(
      self,
      selector: #selector(downloadFinishedSuccessful(notification:)),
      name: .downloadFinishedSuccess,
      object: appDelegate.artworkDownloadManager
    )
    appDelegate.notificationHandler.register(
      self,
      selector: #selector(downloadFinishedSuccessful(notification:)),
      name: .downloadFinishedSuccess,
      object: appDelegate.playableDownloadManager
    )
  }

  public func display(entity: AbstractLibraryEntity) {
    self.entity = entity
    backupImage = entity.getDefaultImage(theme: appDelegate.storage.settings.themePreference)
    refresh()
  }

  public func displayAndUpdate(entity: AbstractLibraryEntity) {
    guard self.entity != entity else { return }

    display(entity: entity)
    if let artwork = entity.artwork {
      appDelegate.artworkDownloadManager.download(object: artwork)
    }
  }

  public func display(image: UIImage) {
    backupImage = image
    entity = nil
    refresh()
  }

  private var placeholderImage: UIImage {
    backupImage ?? UIImage.getGeneratedArtwork(
      theme: appDelegate.storage.settings.themePreference,
      artworkType: .song
    )
  }

  private var entityImageToDisplay: UIImage {
    entity?.image(
      theme: appDelegate.storage.settings.themePreference,
      setting: appDelegate.storage.settings.artworkDisplayPreference
    ) ?? placeholderImage
  }

  private func refresh() {
    let entityToDisplay = entity
    let imageToDisplay = entityImageToDisplay

    if let objectID = entityToDisplay?.objectID,
       let cachedImg = Self.cache.object(forKey: objectID) {
      image = cachedImg
      return
    }

    image = placeholderImage
    guard let objectID = entityToDisplay?.objectID else { return }

    imagePreparationTask?.cancel()
    imagePreparationTask = Task.detached(priority: .high) { [weak self] in
      await self?.loadImageAndCacheIt(entityObjectID: objectID, imageToDisplay: imageToDisplay)
    }
  }

  nonisolated func loadImageAndCacheIt(
    entityObjectID: NSManagedObjectID,
    imageToDisplay: UIImage
  ) async {
    guard !Task.isCancelled else { return }
    let readyImage = await imageToDisplay.byPreparingForDisplay()
    guard !Task.isCancelled else { return }
    Task { @MainActor [weak self] in
      guard let self, let readyImage else { return }
      Self.cache.setObject(readyImage, forKey: entityObjectID)
      refresh()
    }
  }

  @objc
  private func downloadFinishedSuccessful(notification: Notification) {
    guard let downloadNotification = DownloadNotification.fromNotification(notification)
    else { return }
    if let playable = entity as? AbstractPlayable,
       playable.uniqueID == downloadNotification.id {
      Task { @MainActor in
        await self.loadImageAndCacheIt(
          entityObjectID: playable.objectID,
          imageToDisplay: entityImageToDisplay
        )
      }
    }
    if let artwork = entity?.artwork,
       artwork.uniqueID == downloadNotification.id {
      Task { @MainActor in
        guard let entityObjectID = entity?.objectID else { return }
        await self.loadImageAndCacheIt(
          entityObjectID: entityObjectID,
          imageToDisplay: entityImageToDisplay
        )
      }
    }
  }
}
