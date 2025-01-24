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

import UIKit

public enum ImageDisplayPriority {
    case low
    case high
}

public class LibraryEntityImage: RoundedImage {

#if targetEnvironment(macCatalyst)
    private static let skipTimeIntervalInMicroSec : UInt32 = 500
    private static let continueTimeIntervalInMicroSec : UInt32 = 1_000
    private static let downloadTimeIntervalInMicroSec : UInt32 = 2_000
#else
    private static let skipTimeIntervalInMicroSec : UInt32 = 1_000
    private static let continueTimeIntervalInMicroSec : UInt32 = 10_000
    private static let downloadTimeIntervalInMicroSec : UInt32 = 20_000
#endif
    
    let appDelegate: AmperKit
    var entity: AbstractLibraryEntity?
    var backupImage: UIImage?
    var displayPriority = ImageDisplayPriority.low
    
    static let imageLoadingQueue = {
        let myQueue = OperationQueue()
        myQueue.maxConcurrentOperationCount = 1
        return myQueue
    }()
    static let artworkDownloadQueue = {
        let myQueue = OperationQueue()
        myQueue.maxConcurrentOperationCount = 1
        return myQueue
    }()
    
    required public init?(coder: NSCoder) {
        appDelegate = AmperKit.shared
        super.init(coder: coder)
        appDelegate.notificationHandler.register(self, selector: #selector(self.downloadFinishedSuccessful(notification:)), name: .downloadFinishedSuccess, object: appDelegate.artworkDownloadManager)
        appDelegate.notificationHandler.register(self, selector: #selector(self.downloadFinishedSuccessful(notification:)), name: .downloadFinishedSuccess, object: appDelegate.playableDownloadManager)
    }
    
    public func display(entity: AbstractLibraryEntity, priority: ImageDisplayPriority) {
        self.entity = entity
        self.backupImage = entity.getDefaultImage(theme: appDelegate.storage.settings.themePreference)
        self.displayPriority = priority
        refresh()
    }

    public func displayAndUpdate(entity: AbstractLibraryEntity, priority: ImageDisplayPriority) {
        display(entity: entity, priority: priority)
        if let artwork = entity.artwork {
            Self.artworkDownloadQueue.addOperation { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.appDelegate.artworkDownloadManager.download(object: artwork)
                }
                usleep(Self.downloadTimeIntervalInMicroSec)
            }
        }
    }
    
    public func display(image: UIImage) {
        self.backupImage = image
        self.entity = nil
        self.displayPriority = .low
        refresh()
    }
    
    private func refresh() {
        let placeholderImage = backupImage ?? UIImage.getGeneratedArtwork(theme: appDelegate.storage.settings.themePreference, artworkType: .song)
        let imageToDisplay = entity?.image(theme: appDelegate.storage.settings.themePreference, setting: appDelegate.storage.settings.artworkDisplayPreference) ?? placeholderImage
        
        guard imageToDisplay != placeholderImage else {
            self.image = placeholderImage
            return
        }
    
        switch displayPriority {
        case .low:
            // display placeholder
            self.image = placeholderImage
            let contextEntity = entity
            let viewSize = bounds.size
            Self.imageLoadingQueue.addOperation { [weak self] in
                // operation is too old -> skip it
                guard let self = self,
                      self.entity == contextEntity
                else {
                    usleep(Self.skipTimeIntervalInMicroSec)
                    return
                }
                
                let semaphore = DispatchSemaphore(value: 0)
                imageToDisplay.prepareThumbnail(of: viewSize) { [weak self] thumbnailImage in
                    DispatchQueue.main.async {
                        defer { semaphore.signal() }
                        guard let self = self,
                              self.entity == contextEntity,
                              let thumbnailImage = thumbnailImage
                        else { return }
                        self.image = thumbnailImage
                    }
                }
                semaphore.wait()
                usleep(Self.continueTimeIntervalInMicroSec)
            }
        case .high:
            self.image = imageToDisplay
        }
    }
    
    @objc private func downloadFinishedSuccessful(notification: Notification) {
        guard let downloadNotification = DownloadNotification.fromNotification(notification) else { return }
        if let playable = entity as? AbstractPlayable,
           playable.uniqueID == downloadNotification.id {
            refresh()
        }
        if let artwork = entity?.artwork,
           artwork.uniqueID == downloadNotification.id {
            refresh()
        }
    }
    
}
