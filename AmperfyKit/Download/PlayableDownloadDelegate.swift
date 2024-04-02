//
//  PlayableDownloadDelegate.swift
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
import CoreData
import PromiseKit

class PlayableDownloadDelegate: DownloadManagerDelegate {

    private let backendApi: BackendApi
    private let artworkExtractor: EmbeddedArtworkExtractor

    init(backendApi: BackendApi, artworkExtractor: EmbeddedArtworkExtractor) {
        self.backendApi = backendApi
        self.artworkExtractor = artworkExtractor
    }
    
    var requestPredicate: NSPredicate {
        return DownloadMO.onlyPlayablesPredicate
    }
    
    var parallelDownloadsCount: Int {
        return 4
    }
    
    func prepareDownload(download: Download) -> Promise<URL> {
        return Promise<AbstractPlayable> { seal in
            guard let playable = download.element as? AbstractPlayable else { throw DownloadError.fetchFailed }
            guard !playable.isCached else { throw DownloadError.alreadyDownloaded }
            guard Reachability.isConnectedToNetwork() else { throw DownloadError.noConnectivity }
            seal.fulfill(playable)
        }.then { playable in
            self.backendApi.generateUrl(forDownloadingPlayable: playable)
        }
    }
    
    func validateDownloadedData(download: Download) -> ResponseError? {
        guard let data = download.resumeData else {
            return ResponseError(message: "Invalid download", cleansedURL: download.url?.asCleansedURL(cleanser: backendApi), data: download.resumeData)
        }
        return backendApi.checkForErrorResponse(response: APIDataResponse(data: data, url: download.url, meta: nil))
    }

    func completedDownload(download: Download, storage: PersistentStorage) -> Guarantee<Void> {
        return Guarantee<Void> { seal in
            guard let data = download.resumeData,
                  let playable = download.element as? AbstractPlayable,
                  let url = download.url else {
                return seal(Void())
            }
            let library = LibraryStorage(context: storage.main.context)
            savePlayableDataAsync(playable: playable, url: url, data: data, storage: storage)
            artworkExtractor.extractEmbeddedArtwork(library: library, playable: playable, fileData: data)
            library.saveContext()
            seal(Void())
        }
    }
    
    /// save downloaded playable async to avoid memory overflow issues due to kept references
    func savePlayableDataAsync(playable: AbstractPlayable, url: URL, data: Data, storage: PersistentStorage) {
        firstly {
            storage.async.perform { companion in
                guard let playableAsyncMO = companion.context.object(with: playable.objectID) as? AbstractPlayableMO else {
                    return
                }
                let playableAsync = AbstractPlayable(managedObject: playableAsyncMO)
                let playableFile = companion.library.createPlayableFile()
                playableFile.info = playableAsync
                playableFile.data = data
                let transcodingInfo = self.backendApi.determTranscodingInfo(url: url)
                playableAsync.contentTypeTranscoded = transcodingInfo.format?.asMIMETypeString
            }
        }.catch { error in
            // no error possible
        }
    }
    
    func failedDownload(download: Download, storage: PersistentStorage) {
    }
    
}
