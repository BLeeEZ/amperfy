//
//  AmpacheApi.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 19.03.19.
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
import PromiseKit

class AmpacheApi: BackendApi {

    private let ampacheXmlServerApi: AmpacheXmlServerApi

    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
    }
    
    public var clientApiVersion: String {
        return ampacheXmlServerApi.clientApiVersion
    }
    
    public var serverApiVersion: String {
        return ampacheXmlServerApi.serverApiVersion ?? "-"
    }

    func provideCredentials(credentials: LoginCredentials) {
        ampacheXmlServerApi.provideCredentials(credentials: credentials)
    }

    func isAuthenticationValid(credentials: LoginCredentials) -> Promise<Void> {
        return ampacheXmlServerApi.isAuthenticationValid(credentials: credentials)
    }

    func generateUrl(forDownloadingPlayable playable: AbstractPlayable) -> Promise<URL> {
        return ampacheXmlServerApi.generateUrl(forDownloadingPlayable: playable)
    }

    func generateUrl(forStreamingPlayable playable: AbstractPlayable) -> Promise<URL> {
        return ampacheXmlServerApi.generateUrl(forStreamingPlayable: playable)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> Promise<URL> {
        return ampacheXmlServerApi.generateUrl(forArtwork: artwork)
    }
    
    func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
        return ampacheXmlServerApi.checkForErrorResponse(response: response)
    }

    func createLibrarySyncer(storage: PersistentStorage) -> LibrarySyncer {
        return AmpacheLibrarySyncer(ampacheXmlServerApi: ampacheXmlServerApi, storage: storage)
    }    

    func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate {
        return AmpacheArtworkDownloadDelegate(ampacheXmlServerApi: ampacheXmlServerApi)
    }
    
    func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        AmpacheXmlServerApi.extractArtworkInfoFromURL(urlString: urlString)
    }
    
    func cleanse(url: URL) -> CleansedURL {
        return ampacheXmlServerApi.cleanse(url: url)
    }

}
