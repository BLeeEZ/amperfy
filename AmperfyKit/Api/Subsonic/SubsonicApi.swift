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

// MARK: - SubsonicApi

final class SubsonicApi {
  private let subsonicServerApi: SubsonicServerApi
  private let networkMonitor: NetworkMonitorFacade
  private let performanceMonitor: ThreadPerformanceMonitor
  private let eventLogger: EventLogger

  init(
    subsonicServerApi: SubsonicServerApi,
    networkMonitor: NetworkMonitorFacade,
    performanceMonitor: ThreadPerformanceMonitor,
    eventLogger: EventLogger
  ) {
    self.subsonicServerApi = subsonicServerApi
    self.networkMonitor = networkMonitor
    self.performanceMonitor = performanceMonitor
    self.eventLogger = eventLogger
  }

  @MainActor
  var authType: SubsonicApiAuthType { subsonicServerApi.authType.wrappedValue }

  @MainActor
  func setAuthType(newAuthType: SubsonicApiAuthType) {
    subsonicServerApi.setAuthType(newAuthType: newAuthType)
  }
}

// MARK: BackendApi

extension SubsonicApi: BackendApi {
  public var clientApiVersion: String {
    subsonicServerApi.clientApiVersion.wrappedValue?.description ?? "-"
  }

  public var serverApiVersion: String {
    subsonicServerApi.serverApiVersion.wrappedValue?.description ?? "-"
  }

  func provideCredentials(credentials: LoginCredentials) {
    subsonicServerApi.provideCredentials(credentials: credentials)
  }

  func isAuthenticationValid(credentials: LoginCredentials) async throws {
    try await subsonicServerApi.isAuthenticationValid(credentials: credentials)
  }

  func generateUrl(forDownloadingPlayable playableInfo: AbstractPlayableInfo) async throws
    -> URL {
    let apiId = playableInfo.streamId ?? playableInfo.id
    return try await subsonicServerApi.generateUrl(forDownloadingPlayableId: apiId)
  }

  func generateUrl(
    forStreamingPlayable playableInfo: AbstractPlayableInfo,
    maxBitrate: StreamingMaxBitratePreference,
    formatPreference: StreamingFormatPreference
  ) async throws
    -> URL {
    let apiId = playableInfo.streamId ?? playableInfo.id
    return try await subsonicServerApi.generateUrl(
      forStreamingPlayableId: apiId,
      maxBitrate: maxBitrate,
      formatPreference: formatPreference
    )
  }

  func generateUrl(forArtwork artwork: Artwork) async throws -> URL {
    try await subsonicServerApi.generateUrl(forArtworkId: artwork.id)
  }

  func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
    subsonicServerApi.checkForErrorResponse(response: response)
  }

  @MainActor
  func createLibrarySyncer(account: Account, storage: PersistentStorage) -> LibrarySyncer {
    SubsonicLibrarySyncer(
      subsonicServerApi: subsonicServerApi, account: account,
      networkMonitor: networkMonitor,
      performanceMonitor: performanceMonitor,
      storage: storage,
      eventLogger: eventLogger
    )
  }

  func createArtworkDownloadDelegate() -> DownloadManagerDelegate {
    SubsonicArtworkDownloadDelegate(
      subsonicServerApi: subsonicServerApi,
      networkMonitor: networkMonitor
    )
  }

  func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
    SubsonicServerApi.extractArtworkInfoFromURL(urlString: urlString)
  }

  func cleanse(url: URL?) -> CleansedURL {
    subsonicServerApi.cleanse(url: url)
  }
}
