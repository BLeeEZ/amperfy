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
        return ampacheXmlServerApi.serverApiVersion ?? "-"
    }
    
    public var isStreamingTranscodingActive: Bool {
        return ampacheXmlServerApi.isStreamingTranscodingActive
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

    func generateUrl(forStreamingPlayable playable: AbstractPlayable, maxBitrate: StreamingMaxBitratePreference) -> Promise<URL> {
        return ampacheXmlServerApi.generateUrl(forStreamingPlayable: playable, maxBitrate: maxBitrate)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> Promise<URL> {
        return ampacheXmlServerApi.generateUrl(forArtwork: artwork)
    }
    
    func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
        return ampacheXmlServerApi.checkForErrorResponse(response: response)
    }
    
    func determTranscodingInfo(url: URL) -> TranscodingInfo {
        return ampacheXmlServerApi.determTranscodingInfo(url: url)
    }

    func createLibrarySyncer(storage: PersistentStorage) -> LibrarySyncer {
        return AmpacheLibrarySyncer(ampacheXmlServerApi: ampacheXmlServerApi, networkMonitor: networkMonitor, performanceMonitor: self.performanceMonitor, storage: storage, eventLogger: eventLogger)
    }

    func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate {
        return AmpacheArtworkDownloadDelegate(ampacheXmlServerApi: ampacheXmlServerApi, networkMonitor: networkMonitor)
    }
    
    func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        AmpacheXmlServerApi.extractArtworkInfoFromURL(urlString: urlString)
    }
    
    func cleanse(url: URL) -> CleansedURL {
        return ampacheXmlServerApi.cleanse(url: url)
    }

}
