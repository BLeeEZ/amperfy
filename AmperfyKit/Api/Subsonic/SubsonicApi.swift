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
    private let networkMonitor: NetworkMonitorFacade
    private let performanceMonitor: ThreadPerformanceMonitor
    private let eventLogger: EventLogger

    init(subsonicServerApi: SubsonicServerApi, networkMonitor: NetworkMonitorFacade, performanceMonitor: ThreadPerformanceMonitor, eventLogger: EventLogger) {
        self.subsonicServerApi = subsonicServerApi
        self.networkMonitor = networkMonitor
        self.performanceMonitor = performanceMonitor
        self.eventLogger = eventLogger
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
    
    public var isStreamingTranscodingActive: Bool {
        return subsonicServerApi.isStreamingTranscodingActive
    }

    func provideCredentials(credentials: LoginCredentials) {
        subsonicServerApi.provideCredentials(credentials: credentials)
    }
    
    @MainActor func isAuthenticationValid(credentials: LoginCredentials) async throws {
        return try await subsonicServerApi.isAuthenticationValid(credentials: credentials)
    }

    @MainActor func generateUrl(forDownloadingPlayable playable: AbstractPlayable) async throws -> URL {
        return try await subsonicServerApi.generateUrl(forDownloadingPlayable: playable)
    }

    @MainActor func generateUrl(forStreamingPlayable playable: AbstractPlayable, maxBitrate: StreamingMaxBitratePreference) async throws -> URL {
        return try await subsonicServerApi.generateUrl(forStreamingPlayable: playable, maxBitrate: maxBitrate)
    }
    
    @MainActor func generateUrl(forArtwork artwork: Artwork) async throws -> URL {
        return try await subsonicServerApi.generateUrl(forArtwork: artwork)
    }

    func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
        return subsonicServerApi.checkForErrorResponse(response: response)
    }
    
    @MainActor func createLibrarySyncer(storage: PersistentStorage) -> LibrarySyncer {
        return SubsonicLibrarySyncer(subsonicServerApi: subsonicServerApi, networkMonitor: networkMonitor, performanceMonitor: performanceMonitor, storage: storage, eventLogger: eventLogger)
    }
    
    func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate {
        return SubsonicArtworkDownloadDelegate(subsonicServerApi: subsonicServerApi, networkMonitor: networkMonitor)
    }
    
    func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        return SubsonicServerApi.extractArtworkInfoFromURL(urlString: urlString)
    }
    
    func cleanse(url: URL) -> CleansedURL {
        return subsonicServerApi.cleanse(url: url)
    }

}
