//
//  AmpacheArtworkDownloadDelegate.swift
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
import PromiseKit

class AmpacheArtworkDownloadDelegate: DownloadManagerDelegate {
    
    private let ampacheXmlServerApi: AmpacheXmlServerApi
    private var defaultImageData: Data?

    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
    }
    
    var requestPredicate: NSPredicate {
        return DownloadMO.onlyArtworksPredicate
    }
    
    var parallelDownloadsCount: Int {
        return 2
    }

    func prepareDownload(download: Download) -> Promise<URL> {
        return Promise<Artwork> { seal in
            guard let artwork = download.element as? Artwork else {
                throw DownloadError.fetchFailed
            }
            guard Reachability.isConnectedToNetwork() else { throw DownloadError.noConnectivity }
            seal.fulfill(artwork)
        }.then { artwork in
            self.ampacheXmlServerApi.generateUrl(forArtwork: artwork)
        }
    }
    
    func validateDownloadedData(download: Download) -> ResponseError? {
        guard let data = download.resumeData else {
            return ResponseError(statusCode: 0, message: "Invalid download")
        }
        return ampacheXmlServerApi.checkForErrorResponse(inData: data)
    }

    func completedDownload(download: Download, storage: PersistentStorage) -> Guarantee<Void> {
        return Guarantee<Void> { seal in
            guard let data = download.resumeData,
                  let artwork = download.element as? Artwork else {
                return seal(Void())
            }
            firstly {
                self.requestDefaultImageData()
            }.done { defaultImageData in
                if data == defaultImageData {
                    artwork.status = .IsDefaultImage
                    artwork.setImage(fromData: nil)
                } else {
                    artwork.status = .CustomImage
                    artwork.setImage(fromData: data)
                }
                storage.main.saveContext()
            }.catch { error in
                artwork.status = .CustomImage
                artwork.setImage(fromData: data)
                storage.main.saveContext()
            }.finally {
                seal(Void())
            }
        }
    }
    
    func failedDownload(download: Download, storage: PersistentStorage) {
        guard let artwork = download.element as? Artwork else {
            return
        }
        artwork.status = .FetchError
        storage.main.saveContext()
    }
    
    private func requestDefaultImageData() -> Promise<Data> {
        if let defaultImageData = defaultImageData {
            return Promise<Data>.value(defaultImageData)
        } else {
            return firstly {
                self.ampacheXmlServerApi.requestDefaultArtwork()
            }.get { data in
                self.defaultImageData = data
            }
        }
    }
    
}
