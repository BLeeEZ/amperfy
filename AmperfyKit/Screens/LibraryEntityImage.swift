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

public class LibraryEntityImage: RoundedImage {
    
    let appDelegate: AmperKit
    var entity: AbstractLibraryEntity?
    var backupImage: UIImage?

    required public init?(coder: NSCoder) {
        appDelegate = AmperKit.shared
        super.init(coder: coder)
        appDelegate.notificationHandler.register(self, selector: #selector(self.downloadFinishedSuccessful(notification:)), name: .downloadFinishedSuccess, object: appDelegate.artworkDownloadManager)
        appDelegate.notificationHandler.register(self, selector: #selector(self.downloadFinishedSuccessful(notification:)), name: .downloadFinishedSuccess, object: appDelegate.playableDownloadManager)
    }
    
    deinit {
        appDelegate.notificationHandler.remove(self, name: .downloadFinishedSuccess, object: appDelegate.artworkDownloadManager)
    }
    
    public func display(entity: AbstractLibraryEntity) {
        self.entity = entity
        self.backupImage = entity.defaultImage
        refresh()
    }

    public func displayAndUpdate(entity: AbstractLibraryEntity) {
        display(entity: entity)
        if let artwork = entity.artwork {
            appDelegate.artworkDownloadManager.download(object: artwork)
        }
    }
    
    public func display(image: UIImage) {
        self.backupImage = image
        self.entity = nil
        refresh()
    }
    
    public func refresh() {
        self.image = entity?.image(setting: appDelegate.storage.settings.artworkDisplayPreference) ?? backupImage ?? UIImage.songArtwork
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
