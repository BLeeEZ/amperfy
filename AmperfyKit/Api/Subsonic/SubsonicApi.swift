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
        return subsonicServerApi.clientApiVersion.description
    }
    
    public var serverApiVersion: String {
        return subsonicServerApi.serverApiVersion?.description ?? "-"
    }
    
    public var isPodcastSupported: Bool {
        return subsonicServerApi.isPodcastSupported
    }

    func provideCredentials(credentials: LoginCredentials) {
        subsonicServerApi.provideCredentials(credentials: credentials)
    }

    func authenticate(credentials: LoginCredentials) {
        subsonicServerApi.authenticate(credentials: credentials)
    }

    func isAuthenticated() -> Bool {
        return subsonicServerApi.isAuthenticated()
    }
    
    func isAuthenticationValid(credentials: LoginCredentials) -> Bool {
        return subsonicServerApi.isAuthenticationValid(credentials: credentials)
    }

    func generateUrl(forDownloadingPlayable playable: AbstractPlayable) -> URL? {
        return subsonicServerApi.generateUrl(forDownloadingPlayable: playable)
    }

    func generateUrl(forStreamingPlayable playable: AbstractPlayable) -> URL? {
        return subsonicServerApi.generateUrl(forStreamingPlayable: playable)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        return subsonicServerApi.generateUrl(forArtwork: artwork)
    }

    func checkForErrorResponse(inData data: Data) -> ResponseError? {
        return subsonicServerApi.checkForErrorResponse(inData: data)
    }
    
    func createLibrarySyncer() -> LibrarySyncer {
        return SubsonicLibrarySyncer(subsonicServerApi: subsonicServerApi)
    }
    
    func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate {
        return SubsonicArtworkDownloadDelegate(subsonicServerApi: subsonicServerApi)
    }
    
    func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        return SubsonicServerApi.extractArtworkInfoFromURL(urlString: urlString)
    }

}
