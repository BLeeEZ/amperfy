//
//  BackendProxy.swift
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

// MARK: - ServerApiType

public enum ServerApiType: Int, Sendable {
  case ampache = 1
  case subsonic = 2
}

// MARK: - BackenApiType

public enum BackenApiType: Int, Sendable, Codable {
  case notDetected = 0
  case ampache = 1
  case subsonic = 2
  case subsonic_legacy = 3

  public var description: String {
    switch self {
    case .notDetected: return "NotDetected"
    case .ampache: return "Ampache"
    case .subsonic: return "Subsonic"
    case .subsonic_legacy: return "Subsonic (legacy login)"
    }
  }

  public var selectorDescription: String {
    switch self {
    case .notDetected: return "Auto-Detect"
    case .ampache: return "Ampache"
    case .subsonic: return "Subsonic"
    case .subsonic_legacy: return "Subsonic (legacy login)"
    }
  }

  public var asServerApiType: ServerApiType? {
    switch self {
    case .notDetected: return nil
    case .ampache: return .ampache
    case .subsonic: return .subsonic
    case .subsonic_legacy: return .subsonic
    }
  }
}

// MARK: - AuthenticationError

public enum AuthenticationError: LocalizedError {
  case notAbleToLogin
  case invalidUrl
  case requestStatusError(message: String)
  case downloadError(message: String)

  public var errorDescription: String? {
    var ret = ""
    switch self {
    case .notAbleToLogin:
      ret = "Not able to login, please check credentials!"
    case .invalidUrl:
      ret = "Server URL is invalid!"
    case let .requestStatusError(message: message):
      ret = "Requesting server URL finished with status response error code '\(message)'!"
    case let .downloadError(message: message):
      ret = message
    }
    return ret
  }
}

// MARK: - BackendError

public enum BackendError: LocalizedError {
  case invalidUrl
  case noCredentials
  case persistentSaveFailed
  case notSupported
  case incorrectServerBehavior(message: String)

  public var errorDescription: String? {
    var ret = ""
    switch self {
    case .invalidUrl:
      ret = "Provided URL is invalid."
    case .noCredentials:
      ret = "Internal error: no credentials provided."
    case .persistentSaveFailed:
      ret = "Change could not be saved."
    case .notSupported:
      ret = "Requested functionality is not supported."
    case let .incorrectServerBehavior(message: message):
      ret = "Server didn't behave as expected: \(message)"
    }
    return ret
  }
}

// MARK: - ResponseErrorType

public enum ResponseErrorType: Sendable {
  case api
  case xml
  case resource
}

// MARK: - ResponseError

final public class ResponseError: LocalizedError, Sendable {
  public let type: ResponseErrorType
  public let statusCode: Int
  public let message: String
  public let cleansedURL: CleansedURL?
  public let data: Data?

  init(
    type: ResponseErrorType,
    statusCode: Int = 0,
    message: String = "",
    cleansedURL: CleansedURL? = nil,
    data: Data? = nil
  ) {
    self.type = type
    self.statusCode = statusCode
    self.cleansedURL = cleansedURL
    self.data = data

    switch type {
    case .api:
      self.message = message
    case .xml:
      self.message = "XML response could not be parsed."
    case .resource:
      self.message = message
    }
  }

  public var errorDescription: String? {
    switch type {
    case .api:
      return "API error \(statusCode): \(message)"
    case .xml:
      return "\(message)"
    case .resource:
      return "API error \(statusCode): \(message)"
    }
  }

  public func asInfo(topic: String) -> ResponseErrorInfo {
    var dataString: String?
    if let data = data {
      dataString = String(decoding: data, as: UTF8.self)
    }
    return ResponseErrorInfo(
      topic: topic,
      statusCode: statusCode,
      message: message,
      cleansedURL: cleansedURL?.description ?? "",
      data: dataString
    )
  }
}

// MARK: - ResponseErrorInfo

public struct ResponseErrorInfo: Encodable {
  public var topic: String
  public var statusCode: Int
  public var message: String
  public var cleansedURL: String
  public var data: String?
}

// MARK: - BackendProxy

public final class BackendProxy: Sendable {
  private let log = OSLog(subsystem: "Amperfy", category: "BackendProxy")
  private let networkMonitor: NetworkMonitorFacade
  private let performanceMonitor: ThreadPerformanceMonitor
  private let eventLogger: EventLogger
  private let settings: AmperfySettings

  public var selectedApi: BackenApiType {
    get {
      activeApiType.wrappedValue
    }
    set {
      os_log("%s is active backend api", log: self.log, type: .info, newValue.description)
      activeApiType.wrappedValue = newValue
      downloadManagerDelegate.wrappedValue = activeApi.createArtworkDownloadDelegate()
    }
  }

  private let activeApiType = Atomic<BackenApiType>(wrappedValue: .ampache)
  private let downloadManagerDelegate = Atomic<DownloadManagerDelegate?>(wrappedValue: nil)

  private var activeApi: BackendApi {
    switch activeApiType.wrappedValue {
    case .notDetected:
      return ampacheApi.wrappedValue!
    case .ampache:
      return ampacheApi.wrappedValue!
    case .subsonic:
      return subsonicApi.wrappedValue!
    case .subsonic_legacy:
      return subsonicLegacyApi.wrappedValue!
    }
  }

  private let ampacheApi = Atomic<BackendApi?>(wrappedValue: nil)
  private let subsonicApi = Atomic<SubsonicApi?>(wrappedValue: nil)
  private let subsonicLegacyApi = Atomic<SubsonicApi?>(wrappedValue: nil)

  init(
    networkMonitor: NetworkMonitorFacade,
    performanceMonitor: ThreadPerformanceMonitor,
    eventLogger: EventLogger,
    settings: AmperfySettings
  ) {
    self.networkMonitor = networkMonitor
    self.performanceMonitor = performanceMonitor
    self.eventLogger = eventLogger
    self.settings = settings
  }

  @MainActor
  public func initialize() {
    ampacheApi.wrappedValue = AmpacheApi(
      ampacheXmlServerApi: AmpacheXmlServerApi(
        performanceMonitor: performanceMonitor,
        eventLogger: eventLogger,
        settings: settings
      ),
      networkMonitor: networkMonitor,
      performanceMonitor: performanceMonitor,
      eventLogger: eventLogger
    )
    subsonicApi.wrappedValue = SubsonicApi(
      subsonicServerApi: SubsonicServerApi(
        performanceMonitor: performanceMonitor,
        eventLogger: eventLogger,
        settings: settings
      ),
      networkMonitor: networkMonitor,
      performanceMonitor: performanceMonitor,
      eventLogger: eventLogger
    )
    subsonicApi.wrappedValue!.setAuthType(newAuthType: .autoDetect)
    subsonicLegacyApi.wrappedValue = SubsonicApi(
      subsonicServerApi: SubsonicServerApi(
        performanceMonitor: performanceMonitor,
        eventLogger: eventLogger,
        settings: settings
      ),
      networkMonitor: networkMonitor,
      performanceMonitor: performanceMonitor,
      eventLogger: eventLogger
    )
    subsonicLegacyApi.wrappedValue!.setAuthType(newAuthType: .legacy)
  }

  @MainActor
  public func login(
    apiType: BackenApiType,
    credentials: LoginCredentials
  ) async throws
    -> BackenApiType {
    try await checkServerReachablity(credentials: credentials)

    if apiType == .notDetected || apiType == .ampache {
      do {
        try await ampacheApi.wrappedValue!.isAuthenticationValid(credentials: credentials)
        return .ampache
      } catch {} // error -> ignore this api and check the others
    }

    if apiType == .notDetected || apiType == .subsonic {
      do {
        try await subsonicApi.wrappedValue!.isAuthenticationValid(credentials: credentials)
        return .subsonic
      } catch {} // error -> ignore this api and check the others
    }

    if apiType == .notDetected || apiType == .subsonic_legacy {
      do {
        try await subsonicLegacyApi.wrappedValue!.isAuthenticationValid(credentials: credentials)
        return .subsonic_legacy
      } catch {} // error -> ignore this api and check the others
    }

    throw AuthenticationError.notAbleToLogin
  }

  @MainActor
  private func checkServerReachablity(credentials: LoginCredentials) async throws {
    guard let activeBackendServerUrl = URL(string: credentials.activeBackendServerUrl) else {
      throw AuthenticationError.invalidUrl
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(), Error>) in
      let sessionConfig = URLSessionConfiguration.default
      let session = URLSession(configuration: sessionConfig)
      let request = URLRequest(url: activeBackendServerUrl)
      let task = session.downloadTask(with: request) { tempLocalUrl, response, error in
        if let error = error {
          continuation
            .resume(
              throwing: AuthenticationError
                .downloadError(message: error.localizedDescription)
            )
        } else {
          if let statusCode = (response as? HTTPURLResponse)?.statusCode {
            if statusCode >= 400,
               // ignore 401 Unauthorized (RFC 7235) status code
               // -> Can occur if root website requires http basic authentication,
               //    but the REST API endpoints are reachable without http basic authentication
               statusCode != 401 {
              continuation
                .resume(throwing: AuthenticationError.requestStatusError(message: "\(statusCode)"))
            } else {
              continuation.resume()
            }
          }
        }
      }
      task.resume()
    }
    os_log("Server url is reachable.", log: self.log, type: .info)
  }
}

// MARK: BackendApi

extension BackendProxy: BackendApi {
  public var clientApiVersion: String { activeApi.clientApiVersion }

  public var serverApiVersion: String { activeApi.serverApiVersion }

  public func provideCredentials(credentials: LoginCredentials) {
    activeApi.provideCredentials(credentials: credentials)
  }

  public func isAuthenticationValid(credentials: LoginCredentials) async throws {
    try await activeApi.isAuthenticationValid(credentials: credentials)
  }

  public func generateUrl(forDownloadingPlayable playableInfo: AbstractPlayableInfo) async throws
    -> URL {
    try await activeApi.generateUrl(forDownloadingPlayable: playableInfo)
  }

  public func generateUrl(
    forStreamingPlayable playableInfo: AbstractPlayableInfo,
    maxBitrate: StreamingMaxBitratePreference,
    formatPreference: StreamingFormatPreference
  ) async throws
    -> URL {
    try await activeApi.generateUrl(
      forStreamingPlayable: playableInfo,
      maxBitrate: maxBitrate,
      formatPreference: formatPreference
    )
  }

  public func generateUrl(forArtwork artwork: Artwork) async throws -> URL {
    try await activeApi.generateUrl(forArtwork: artwork)
  }

  public func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
    activeApi.checkForErrorResponse(response: response)
  }

  public func createLibrarySyncer(account: Account, storage: PersistentStorage) -> LibrarySyncer {
    activeApi.createLibrarySyncer(account: account, storage: storage)
  }

  public func getActiveArtworkDownloadDelegate() -> DownloadManagerDelegate {
    var dlDelegate = downloadManagerDelegate.wrappedValue
    if dlDelegate == nil {
      dlDelegate = activeApi.createArtworkDownloadDelegate()
      downloadManagerDelegate.wrappedValue = dlDelegate
    }
    return dlDelegate!
  }

  public func createArtworkDownloadDelegate() -> DownloadManagerDelegate {
    activeApi.createArtworkDownloadDelegate()
  }

  public func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
    activeApi.extractArtworkInfoFromURL(urlString: urlString)
  }

  public func cleanse(url: URL?) -> CleansedURL {
    activeApi.cleanse(url: url)
  }
}
