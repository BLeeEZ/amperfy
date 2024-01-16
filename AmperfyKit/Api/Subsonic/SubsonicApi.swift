//
//  SubsonicApi.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 05.04.19.
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
import os.log
import PromiseKit

class SubsonicApi  {
        
    private let subsonicServerApi: SubsonicServerApi

    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }
    
    var authType: SubsonicApiAuthType {
        get { return subsonicServerApi.authType }
        set { subsonicServerApi.authType = newValue }
    }
    
}
    
extension SubsonicApi: BackendApi {
    
    public var clientApiVersion: String {
        return subsonicServerApi.clientApiVersion?.description ?? "-"
    }
    
    public var serverApiVersion: String {
        return subsonicServerApi.serverApiVersion?.description ?? "-"
    }

    func provideCredentials(credentials: LoginCredentials) {
        subsonicServerApi.provideCredentials(credentials: credentials)
    }
    
    func isAuthenticationValid(credentials: LoginCredentials) -> Promise<Void> {
        return subsonicServerApi.isAuthenticationValid(credentials: credentials)
    }

    func generateUrl(forDownloadingPlayable playable: AbstractPlayable) -> Promise<URL> {
        return subsonicServerApi.generateUrl(forDownloadingPlayable: playable)
    }

    func generateUrl(forStreamingPlayable playable: AbstractPlayable) -> Promise<URL> {
        return subsonicServerApi.generateUrl(forStreamingPlayable: playable)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> Promise<URL> {
        return subsonicServerApi.generateUrl(forArtwork: artwork)
    }

    func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
        return subsonicServerApi.checkForErrorResponse(response: response)
    }
    
    func createLibrarySyncer(storage: PersistentStorage) -> LibrarySyncer {
        return SubsonicLibrarySyncer(subsonicServerApi: subsonicServerApi, storage: storage)
    }
    
    func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate {
        return SubsonicArtworkDownloadDelegate(subsonicServerApi: subsonicServerApi)
    }
    
    func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        return SubsonicServerApi.extractArtworkInfoFromURL(urlString: urlString)
    }

}
