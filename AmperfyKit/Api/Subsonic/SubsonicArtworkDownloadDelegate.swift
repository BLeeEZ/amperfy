//
//  SubsonicArtworkDownloadDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.06.21.
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

import Foundation
import CoreData
import UIKit
import os.log

class SubsonicArtworkDownloadDelegate: DownloadManagerDelegate {
        
    private let subsonicServerApi: SubsonicServerApi

    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }
    
    var requestPredicate: NSPredicate {
        return DownloadMO.onlyArtworksPredicate
    }
    
    var parallelDownloadsCount: Int {
        return 2
    }

    func prepareDownload(download: Download, context: NSManagedObjectContext) throws -> URL {
        guard let downloadElement = download.element else {
            throw DownloadError.fetchFailed
        }
        let artworkMO = try context.existingObject(with: downloadElement.objectID) as! ArtworkMO
        let artwork = Artwork(managedObject: artworkMO)
        guard Reachability.isConnectedToNetwork() else { throw DownloadError.noConnectivity }
        guard let url = subsonicServerApi.generateUrl(forArtwork: artwork) else { throw DownloadError.urlInvalid }
        return url
    }
    
    func validateDownloadedData(download: Download) -> ResponseError? {
        guard let data = download.resumeData else {
            return ResponseError(statusCode: 0, message: "Invalid download")
        }
        return subsonicServerApi.checkForErrorResponse(inData: data)
    }
    
    func completedDownload(download: Download, context: NSManagedObjectContext) {
        guard let data = download.resumeData,
              let downloadElement = download.element,
              let artworkMO = try? context.existingObject(with: downloadElement.objectID) as? ArtworkMO else {
            return
        }
        let library = LibraryStorage(context: context)
        let artwork = Artwork(managedObject: artworkMO)
        artwork.status = .CustomImage
        artwork.setImage(fromData: data)
        library.saveContext()
    }
    
    func failedDownload(download: Download, context: NSManagedObjectContext) {
        guard let downloadElement = download.element,
              let artworkMO = try? context.existingObject(with: downloadElement.objectID) as? ArtworkMO else {
            return
        }
        let artwork = Artwork(managedObject: artworkMO)
        artwork.status = .FetchError
        let library = LibraryStorage(context: context)
        library.saveContext()
    }

}
