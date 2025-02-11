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

@MainActor class AmpacheApi: BackendApi {

    private let ampacheXmlServerApi: AmpacheXmlServerApi
    private let networkMonitor: NetworkMonitorFacade
    private let performanceMonitor: ThreadPerformanceMonitor
    private let eventLogger: EventLogger

    init(ampacheXmlServerApi: AmpacheXmlServerApi, networkMonitor: NetworkMonitorFacade, performanceMonitor: ThreadPerformanceMonitor, eventLogger: EventLogger) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
        self.networkMonitor = networkMonitor
        self.performanceMonitor = performanceMonitor
        self.eventLogger = eventLogger
    }
    
    public var clientApiVersion: String {
        return ampacheXmlServerApi.clientApiVersion
    }
    
    public var serverApiVersion: String {
        get { return ampacheXmlServerApi.serverApiVersion ?? "-" }
    }
    
    public var isStreamingTranscodingActive: Bool {
        get { return ampacheXmlServerApi.isStreamingTranscodingActive }
    }

    func provideCredentials(credentials: LoginCredentials) {
        ampacheXmlServerApi.provideCredentials(credentials: credentials)
    }

    @MainActor func isAuthenticationValid(credentials: LoginCredentials) async throws {
        return try await ampacheXmlServerApi.isAuthenticationValid(credentials: credentials)
    }

    @MainActor func generateUrl(forDownloadingPlayable playable: AbstractPlayable) async throws -> URL {
        return try await ampacheXmlServerApi.generateUrlForDownloadingPlayable(isSong: playable.isSong, id: playable.id)
    }

    @MainActor func generateUrl(forStreamingPlayable playable: AbstractPlayable, maxBitrate: StreamingMaxBitratePreference) async throws -> URL {
        return try await ampacheXmlServerApi.generateUrlForStreamingPlayable(isSong: playable.isSong, id: playable.id, maxBitrate: maxBitrate)
    }
    
    @MainActor func generateUrl(forArtwork artwork: Artwork) async throws -> URL {
        return try await ampacheXmlServerApi.generateUrlForArtwork(artworkUrl: artwork.url)
    }
    
    func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
        return ampacheXmlServerApi.checkForErrorResponse(response: response)
    }

    @MainActor func createLibrarySyncer(storage: PersistentStorage) -> LibrarySyncer {
        return AmpacheLibrarySyncer(ampacheXmlServerApi: ampacheXmlServerApi, networkMonitor: networkMonitor, performanceMonitor: self.performanceMonitor, storage: storage, eventLogger: eventLogger)
    }

    @MainActor func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate {
        return AmpacheArtworkDownloadDelegate(ampacheXmlServerApi: ampacheXmlServerApi, networkMonitor: networkMonitor)
    }
    
    func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        AmpacheXmlServerApi.extractArtworkInfoFromURL(urlString: urlString)
    }
    
    func cleanse(url: URL?) -> CleansedURL {
        return ampacheXmlServerApi.cleanse(url: url)
    }

}
