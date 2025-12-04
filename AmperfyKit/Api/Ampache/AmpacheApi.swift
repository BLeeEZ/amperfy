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

final class AmpacheApi: BackendApi {
  private let ampacheXmlServerApi: AmpacheXmlServerApi
  private let networkMonitor: NetworkMonitorFacade
  private let performanceMonitor: ThreadPerformanceMonitor
  private let eventLogger: EventLogger

  init(
    ampacheXmlServerApi: AmpacheXmlServerApi,
    networkMonitor: NetworkMonitorFacade,
    performanceMonitor: ThreadPerformanceMonitor,
    eventLogger: EventLogger
  ) {
    self.ampacheXmlServerApi = ampacheXmlServerApi
    self.networkMonitor = networkMonitor
    self.performanceMonitor = performanceMonitor
    self.eventLogger = eventLogger
  }

  public var clientApiVersion: String {
    ampacheXmlServerApi.clientApiVersion
  }

  public var serverApiVersion: String { ampacheXmlServerApi.serverApiVersion.wrappedValue ?? "-" }

  func provideCredentials(credentials: LoginCredentials) {
    ampacheXmlServerApi.provideCredentials(credentials: credentials)
  }

  @MainActor
  func isAuthenticationValid(credentials: LoginCredentials) async throws {
    try await ampacheXmlServerApi.isAuthenticationValid(credentials: credentials)
  }

  @MainActor
  func generateUrl(forDownloadingPlayable playableInfo: AbstractPlayableInfo) async throws
    -> URL {
    try await ampacheXmlServerApi.generateUrlForDownloadingPlayable(
      isSong: playableInfo.type == .song,
      id: playableInfo.id
    )
  }

  func generateUrl(
    forStreamingPlayable playableInfo: AbstractPlayableInfo,
    maxBitrate: StreamingMaxBitratePreference,
    formatPreference: StreamingFormatPreference
  ) async throws
    -> URL {
    try await ampacheXmlServerApi.generateUrlForStreamingPlayable(
      isSong: playableInfo.type == .song,
      id: playableInfo.id,
      maxBitrate: maxBitrate,
      formatPreference: formatPreference
    )
  }

  func generateUrl(forArtwork artwork: Artwork) async throws -> URL {
    try await ampacheXmlServerApi.generateUrlForArtwork(artworkRemoteInfo: artwork.remoteInfo)
  }

  func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
    ampacheXmlServerApi.checkForErrorResponse(response: response)
  }

  @MainActor
  func createLibrarySyncer(account: Account, storage: PersistentStorage) -> LibrarySyncer {
    AmpacheLibrarySyncer(
      ampacheXmlServerApi: ampacheXmlServerApi, account: account,
      networkMonitor: networkMonitor,
      performanceMonitor: performanceMonitor,
      storage: storage,
      eventLogger: eventLogger
    )
  }

  func createArtworkDownloadDelegate() -> DownloadManagerDelegate {
    AmpacheArtworkDownloadDelegate(
      ampacheXmlServerApi: ampacheXmlServerApi,
      networkMonitor: networkMonitor
    )
  }

  func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
    AmpacheXmlServerApi.extractArtworkInfoFromURL(urlString: urlString)
  }

  func cleanse(url: URL?) -> CleansedURL {
    ampacheXmlServerApi.cleanse(url: url)
  }
}
