//
//  SubsonicServerApi.swift
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

import Alamofire
import Foundation
import os.log

// MARK: - SubsonicApiAuthType

enum SubsonicApiAuthType: Int {
  case autoDetect = 0
  case legacy = 1
}

// MARK: - SubsonicResponseError

struct SubsonicResponseError: LocalizedError {
  public var statusCode: Int = 0
  public var message: String

  public var subsonicError: SubsonicServerApi.SubsonicError? {
    SubsonicServerApi.SubsonicError(rawValue: statusCode)
  }
}

extension ResponseError {
  var asSubsonicError: SubsonicServerApi.SubsonicError? {
    SubsonicServerApi.SubsonicError(rawValue: statusCode)
  }

  static func createFromSubsonicError(
    cleansedURL: CleansedURL?,
    error: SubsonicResponseError,
    data: Data?
  )
    -> ResponseError {
    ResponseError(
      type: .api,
      statusCode: error.statusCode,
      message: error.message,
      cleansedURL: cleansedURL,
      data: data
    )
  }
}

// MARK: - OpenSubsonicExtension

enum OpenSubsonicExtension: String {
  case songLyrics
}

// MARK: - OpenSubsonicExtensionsSupport

struct OpenSubsonicExtensionsSupport {
  var extensionResponse: OpenSubsonicExtensionsResponse?
  var isSupported = false
}

// MARK: - SubsonicServerApi

final class SubsonicServerApi: URLCleanser, Sendable {
  enum SubsonicError: Int {
    case generic = 0 // A generic error.
    case requiredParameterMissing = 10 // Required parameter is missing.
    case clientVersionToLow =
      20 // Incompatible Subsonic REST protocol version. Client must upgrade.
    case serverVerionToLow = 30 // Incompatible Subsonic REST protocol version. Server must upgrade.
    case wrongUsernameOrPassword = 40 // Wrong username or password.
    case tokenAuthenticationNotSupported = 41 // Token authentication not supported for LDAP users.
    case userIsNotAuthorized = 50 // User is not authorized for the given operation.
    case trialPeriodForServerIsOver =
      60 // The trial period for the Subsonic server is over. Please upgrade to Subsonic Premium. Visit subsonic.org for details.
    case requestedDataNotFound = 70 // The requested data was not found.

    var shouldErrorBeDisplayedToUser: Bool {
      self != .requestedDataNotFound
    }

    var isRemoteAvailable: Bool {
      self != .requestedDataNotFound
    }
  }

  static let defaultClientApiVersionWithToken = SubsonicVersion(major: 1, minor: 13, patch: 0)
  static let defaultClientApiVersionPreToken = SubsonicVersion(major: 1, minor: 11, patch: 0)

  internal let serverApiVersion = Atomic<SubsonicVersion?>(wrappedValue: nil)
  internal let clientApiVersion = Atomic<SubsonicVersion?>(wrappedValue: nil)
  internal let authType = Atomic<SubsonicApiAuthType>(wrappedValue: .autoDetect)
  internal var account: AccountInfo? {
    guard let credentials = credentials.wrappedValue else { return nil }
    return Account.createInfo(credentials: credentials)
  }

  private let log = OSLog(subsystem: "Amperfy", category: "Subsonic")
  private let performanceMonitor: ThreadPerformanceMonitor
  private let eventLogger: EventLogger
  private let settings: AmperfySettings
  private let credentials = Atomic<LoginCredentials?>(wrappedValue: nil)
  private let openSubsonicExtensionsSupport =
    Atomic<OpenSubsonicExtensionsSupport?>(wrappedValue: nil)
  init(
    performanceMonitor: ThreadPerformanceMonitor,
    eventLogger: EventLogger,
    settings: AmperfySettings
  ) {
    self.performanceMonitor = performanceMonitor
    self.eventLogger = eventLogger
    self.settings = settings
  }

  func setAuthType(newAuthType: SubsonicApiAuthType) {
    authType.wrappedValue = newAuthType
  }

  private var authTypeBasedClientApiVersion: SubsonicVersion {
    authType.wrappedValue == .legacy ? Self.defaultClientApiVersionPreToken : Self
      .defaultClientApiVersionWithToken
  }

  static func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
    guard let url = URL(string: urlString),
          let urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let id = urlComp.queryItems?.first(where: { $0.name == "id" })?.value
    else { return nil }
    return ArtworkRemoteInfo(id: id, type: "")
  }

  private func generateAuthenticationToken(password: String, salt: String) -> String {
    // Calculate the authentication token as follows: token = md5(password + salt).
    // The md5() function takes a string and returns the 32-byte ASCII hexadecimal representation of the MD5 hash,
    // using lower case characters for the hex values. The '+' operator represents concatenation of the two strings.
    // Treat the strings as UTF-8 encoded when calculating the hash. Send the result as parameter
    let dataStr = "\(password)\(salt)"
    let authenticationToken = StringHasher.md5Hex(dataString: dataStr)
    return authenticationToken
  }

  private func getCachedServerApiVersionOrRequestIt(
    providedCredentials: LoginCredentials? =
      nil
  ) async throws
    -> SubsonicVersion {
    if let serverVersion = serverApiVersion.wrappedValue {
      return serverVersion
    } else {
      return try await requestServerApiVersionPromise(providedCredentials: providedCredentials)
    }
  }

  private func determineApiVersionToUse(providedCredentials: LoginCredentials? = nil) async throws
    -> SubsonicVersion {
    if let clientApiVersion = clientApiVersion.wrappedValue {
      return clientApiVersion
    }
    let serverVersion =
      try await getCachedServerApiVersionOrRequestIt(providedCredentials: providedCredentials)

    os_log("Server API version is '%s'", log: self.log, type: .info, serverVersion.description)
    if authType.wrappedValue == .legacy {
      clientApiVersion.wrappedValue = Self.defaultClientApiVersionPreToken
      os_log("Client API legacy login", log: self.log, type: .info)
    } else {
      clientApiVersion.wrappedValue = Self.defaultClientApiVersionWithToken
      os_log(
        "Client API version is '%s'",
        log: self.log,
        type: .info,
        self.clientApiVersion.wrappedValue!.description
      )
    }
    return clientApiVersion.wrappedValue!
  }

  private func createBasicApiUrlComponent(
    forAction: String,
    providedCredentials: LoginCredentials? = nil
  )
    -> URLComponents? {
    let localCredentials = providedCredentials != nil ? providedCredentials : credentials
      .wrappedValue
    guard let hostname = localCredentials?.activeBackendServerUrl,
          var apiUrl = URL(string: hostname)
    else { return nil }

    apiUrl.appendPathComponent("rest")
    apiUrl.appendPathComponent("\(forAction).view")

    return URLComponents(url: apiUrl, resolvingAgainstBaseURL: false)
  }

  private func createAuthApiUrlComponent(
    version: SubsonicVersion,
    forAction: String,
    credentials providedCredentials: LoginCredentials? = nil
  ) throws
    -> URLComponents {
    let localCredentials = providedCredentials != nil ? providedCredentials : credentials
      .wrappedValue
    guard let username = localCredentials?.username,
          let password = localCredentials?.password,
          var urlComp = createBasicApiUrlComponent(
            forAction: forAction,
            providedCredentials: localCredentials
          )
    else { throw BackendError.invalidUrl }

    urlComp.addQueryItem(name: "u", value: username)
    urlComp.addQueryItem(name: "v", value: version.description)
    urlComp.addQueryItem(name: "c", value: "Amperfy")

    if version < SubsonicVersion.authenticationTokenRequiredServerApi {
      urlComp.addQueryItem(name: "p", value: password)
    } else {
      let salt = String.generateRandomString(ofLength: 16)
      let authenticationToken = generateAuthenticationToken(password: password, salt: salt)
      urlComp.addQueryItem(name: "t", value: authenticationToken)
      urlComp.addQueryItem(name: "s", value: salt)
    }

    return urlComp
  }

  private func createAuthApiUrlComponent(
    version: SubsonicVersion,
    forAction: String,
    id: String
  ) throws
    -> URLComponents {
    var urlComp = try createAuthApiUrlComponent(version: version, forAction: forAction)
    urlComp.addQueryItem(name: "id", value: id)
    return urlComp
  }

  public func provideCredentials(credentials: LoginCredentials) {
    self.credentials.wrappedValue = credentials
  }

  public func cleanse(url: URL?) -> CleansedURL {
    guard let url = url,
          var urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let queryItems = urlComp.queryItems
    else { return CleansedURL(urlString: "") }

    urlComp.host = "SERVERURL"
    if urlComp.port != nil {
      urlComp.port = nil
    }
    var outputItems = [URLQueryItem]()
    for queryItem in queryItems {
      if queryItem.name == "p" {
        outputItems.append(URLQueryItem(name: queryItem.name, value: "PASSWORD"))
      } else if queryItem.name == "t" {
        outputItems.append(URLQueryItem(name: queryItem.name, value: "AUTHTOKEN"))
      } else if queryItem.name == "s" {
        outputItems.append(URLQueryItem(name: queryItem.name, value: "SALT"))
      } else if queryItem.name == "u" {
        outputItems.append(URLQueryItem(name: queryItem.name, value: "USER"))
      } else {
        outputItems.append(queryItem)
      }
    }
    urlComp.queryItems = outputItems
    return CleansedURL(urlString: urlComp.string ?? "")
  }

  public func isAuthenticationValid(credentials: LoginCredentials) async throws {
    let version = try await determineApiVersionToUse(providedCredentials: credentials)
    let urlComp = try createAuthApiUrlComponent(
      version: version,
      forAction: "ping",
      credentials: credentials
    )
    let response = try await request(url: try createUrl(from: urlComp))

    let parserDelegate = SsPingParserDelegate(performanceMonitor: performanceMonitor)
    let parser = XMLParser(data: response.data)
    parser.delegate = parserDelegate
    let success = parser.parse()

    if let error = parser.parserError {
      os_log(
        "Error during login parsing: %s",
        log: self.log,
        type: .error,
        error.localizedDescription
      )
      throw AuthenticationError.notAbleToLogin
    }
    if success, parserDelegate.isAuthValid {
      return
    } else {
      os_log("Couldn't login.", log: self.log, type: .error)
      throw AuthenticationError.notAbleToLogin
    }
  }

  public func generateUrl(forDownloadingPlayableId apiId: String) async throws -> URL {
    let version = try await determineApiVersionToUse()
    // If transcoding is selected for caching the subsonic API method 'stream' must be used
    // For raw format subsonic API method 'download' can be used
    switch settings.user.cacheTranscodingFormatPreference {
    case .mp3:
      var urlComp = try createAuthApiUrlComponent(version: version, forAction: "stream", id: apiId)
      urlComp.addQueryItem(name: "format", value: "mp3")
      let url = try createUrl(from: urlComp)
      return url
    case .serverConfig:
      let urlComp = try createAuthApiUrlComponent(version: version, forAction: "stream", id: apiId)
      // let the server decide which format to use
      let url = try createUrl(from: urlComp)
      return url
    case .raw:
      let urlComp = try createAuthApiUrlComponent(
        version: version,
        forAction: "download",
        id: apiId
      )
      let url = try createUrl(from: urlComp)
      return url
    }
  }

  public func generateUrl(
    forStreamingPlayableId apiId: String,
    maxBitrate: StreamingMaxBitratePreference,
    formatPreference: StreamingFormatPreference
  ) async throws
    -> URL {
    let version = try await determineApiVersionToUse()
    var urlComp = try createAuthApiUrlComponent(version: version, forAction: "stream", id: apiId)

    switch formatPreference {
    case .mp3:
      urlComp.addQueryItem(name: "format", value: "mp3")
    case .raw:
      urlComp.addQueryItem(name: "format", value: "raw")
    case .serverConfig:
      break // do nothing
    }
    switch maxBitrate {
    case .noLimit:
      break
    default:
      urlComp.addQueryItem(name: "maxBitRate", value: maxBitrate.rawValue)
    }
    return try createUrl(from: urlComp)
  }

  public func generateUrl(forArtworkId id: String) async throws -> URL {
    let version = try await determineApiVersionToUse()
    return try createUrl(from: try createAuthApiUrlComponent(
      version: version,
      forAction: "getCoverArt",
      id: id
    ))
  }

  private func requestServerApiVersionPromise(
    providedCredentials: LoginCredentials? =
      nil
  ) async throws
    -> SubsonicVersion {
    guard let urlComp = try? createAuthApiUrlComponent(
      version: authTypeBasedClientApiVersion,
      forAction: "ping",
      credentials: providedCredentials
    ) else {
      throw BackendError.invalidUrl
    }

    let url = try createUrl(from: urlComp)
    let response = try await request(url: url)

    let delegate = SsPingParserDelegate(performanceMonitor: performanceMonitor)
    let parser = XMLParser(data: response.data)
    parser.delegate = delegate
    parser.parse()
    guard let serverApiVersionString = delegate.serverApiVersion else {
      throw ResponseError(type: .xml, cleansedURL: cleanse(url: response.url), data: response.data)
    }
    guard let serverApiVersion = SubsonicVersion(serverApiVersionString) else {
      os_log(
        "The server API version '%s' could not be parsed to 'SubsonicVersion'",
        log: self.log,
        type: .info,
        serverApiVersionString
      )
      throw ResponseError(type: .xml, cleansedURL: cleanse(url: response.url), data: response.data)
    }
    self.serverApiVersion.wrappedValue = serverApiVersion
    return serverApiVersion
  }

  public func requestServerPodcastSupport() async throws -> Bool {
    let _ = try await determineApiVersionToUse()
    var isPodcastSupported = false
    if let serverApi = serverApiVersion.wrappedValue {
      isPodcastSupported = serverApi >= SubsonicVersion(major: 1, minor: 9, patch: 0)
    }
    if !isPodcastSupported {
      return isPodcastSupported
    } else {
      do {
        let _ = try await requestPodcasts()
        return true
      } catch {
        return false
      }
    }
  }

  private func requestOpenSubsonicExtensions() async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getOpenSubsonicExtensions"
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func isOpenSubsonicExtensionSupported(extension oSsExtention: OpenSubsonicExtension) async
    -> Bool {
    // the member variable will be set after the server has been requested
    // here we already asked the server for its support and use the cached response
    if let oSsExtSupport = openSubsonicExtensionsSupport.wrappedValue {
      if oSsExtSupport.isSupported == false {
        os_log(
          "No OpenSubsonicExtensions supported (%s)!",
          log: self.log,
          type: .info,
          oSsExtention.rawValue
        )
        return false
      } else if let response = oSsExtSupport.extensionResponse {
        let isExtensionSupported = response.supportedExtensions.contains(oSsExtention.rawValue)
        os_log(
          "OpenSubsonicExtension %s supported: %s",
          log: self.log,
          type: .info,
          oSsExtention.rawValue,
          isExtensionSupported ? "yes" : "no"
        )
        return isExtensionSupported
      } else {
        os_log(
          "No OpenSubsonicExtensions supported (%s)!",
          log: self.log,
          type: .info,
          oSsExtention.rawValue
        )
        return false
      }
    } else {
      // we haven't yet requested the server for OpenSubsonicExtensions support
      do {
        let response = try await requestOpenSubsonicExtensions()
        let task = Task { // perform asynchronous
          let parserDelegate = SsOpenSubsonicExtensionsParserDelegate(
            performanceMonitor: self
              .performanceMonitor
          )

          let parser = XMLParser(data: response.data)
          parser.delegate = parserDelegate
          let success = parser.parse()
          guard success else {
            os_log(
              "No OpenSubsonicExtensions supported (%s)!",
              log: self.log,
              type: .info,
              oSsExtention.rawValue
            )
            return false
          }

          self.openSubsonicExtensionsSupport.wrappedValue = OpenSubsonicExtensionsSupport()
          self.openSubsonicExtensionsSupport.wrappedValue?.isSupported = !parserDelegate
            .openSubsonicExtensionsResponse.supportedExtensions.isEmpty
          self.openSubsonicExtensionsSupport.wrappedValue?.extensionResponse = parserDelegate
            .openSubsonicExtensionsResponse

          if let availableExtensions = self.openSubsonicExtensionsSupport.wrappedValue?
            .extensionResponse?
            .supportedExtensions {
            let availableExtensionsStr = availableExtensions
              .reduce("") { $0 == "" ? $1 : $0 + ", " + $1 }
            os_log(
              "OpenSubsonicExtensions supported: %s",
              log: self.log,
              type: .info,
              availableExtensionsStr
            )
            let isSpecificExtensionSupported = availableExtensions.contains(oSsExtention.rawValue)
            os_log(
              "OpenSubsonicExtensions %s supported: %s",
              log: self.log,
              type: .info,
              oSsExtention.rawValue,
              isSpecificExtensionSupported ? "yes" : "no"
            )
            return isSpecificExtensionSupported
          } else {
            os_log(
              "No OpenSubsonicExtension supported (%s)!",
              log: self.log,
              type: .info,
              oSsExtention.rawValue
            )
            return false
          }
        }
        return await task.value
      } catch {
        os_log(
          "No OpenSubsonicExtension supported (%s)!",
          log: self.log,
          type: .info,
          oSsExtention.rawValue
        )
        openSubsonicExtensionsSupport.wrappedValue = OpenSubsonicExtensionsSupport()
        openSubsonicExtensionsSupport.wrappedValue?.isSupported = false
        return false
      }
    }
  }

  /// this requires that the server supports OpenSubsonicExtension "songLyrics"
  public func requestLyricsBySongId(id: String) async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getLyricsBySongId",
        id: id
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestGenres() async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getGenres")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestArtists() async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getArtists")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestArtist(id: String) async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getArtist",
        id: id
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestAlbum(id: String) async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getAlbum",
        id: id
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSongInfo(id: String) async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getSong",
        id: id
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestFavoriteElements() async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getStarred2")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestNewestAlbums(offset: Int, count: Int) async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getAlbumList2")
      urlComp.addQueryItem(name: "type", value: "newest")
      urlComp.addQueryItem(name: "size", value: count)
      urlComp.addQueryItem(name: "offset", value: offset)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestRecentAlbums(offset: Int, count: Int) async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getAlbumList2")
      urlComp.addQueryItem(name: "type", value: "recent")
      urlComp.addQueryItem(name: "size", value: count)
      urlComp.addQueryItem(name: "offset", value: offset)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestAlbums(offset: Int, count: Int) async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getAlbumList2")
      urlComp.addQueryItem(name: "type", value: "alphabeticalByName")
      urlComp.addQueryItem(name: "size", value: count)
      urlComp.addQueryItem(name: "offset", value: offset)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestRandomSongs(count: Int) async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getRandomSongs"
      )
      urlComp.addQueryItem(name: "size", value: count)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPodcastEpisodeDelete(id: String) async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "deletePodcastEpisode",
        id: id
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSearchArtists(searchText: String) async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "search3")
      urlComp.addQueryItem(name: "query", value: searchText)
      urlComp.addQueryItem(name: "artistCount", value: 40)
      urlComp.addQueryItem(name: "artistOffset", value: 0)
      urlComp.addQueryItem(name: "albumCount", value: 0)
      urlComp.addQueryItem(name: "albumOffset", value: 0)
      urlComp.addQueryItem(name: "songCount", value: 0)
      urlComp.addQueryItem(name: "songOffset", value: 0)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSearchAlbums(searchText: String) async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "search3")
      urlComp.addQueryItem(name: "query", value: searchText)
      urlComp.addQueryItem(name: "artistCount", value: 0)
      urlComp.addQueryItem(name: "artistOffset", value: 0)
      urlComp.addQueryItem(name: "albumCount", value: 40)
      urlComp.addQueryItem(name: "albumOffset", value: 0)
      urlComp.addQueryItem(name: "songCount", value: 0)
      urlComp.addQueryItem(name: "songOffset", value: 0)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSearchSongs(searchText: String) async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "search3")
      urlComp.addQueryItem(name: "query", value: searchText)
      urlComp.addQueryItem(name: "artistCount", value: 0)
      urlComp.addQueryItem(name: "artistOffset", value: 0)
      urlComp.addQueryItem(name: "albumCount", value: 0)
      urlComp.addQueryItem(name: "albumOffset", value: 0)
      urlComp.addQueryItem(name: "songCount", value: 40)
      urlComp.addQueryItem(name: "songOffset", value: 0)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylists() async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getPlaylists")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylistSongs(id: String) async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getPlaylist",
        id: id
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylistCreate(name: String) async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "createPlaylist"
      )
      urlComp.addQueryItem(name: "name", value: name)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylistDelete(id: String) async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "deletePlaylist",
        id: id
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
    let errorParser = SsXmlParser(performanceMonitor: performanceMonitor)
    let parser = XMLParser(data: response.data)
    parser.delegate = errorParser
    parser.parse()
    guard let subsonicError = errorParser.error else { return nil }
    return ResponseError.createFromSubsonicError(
      cleansedURL: cleanse(url: response.url),
      error: subsonicError,
      data: response.data
    )
  }

  public func requestPlaylistUpdate(
    id: String,
    name: String,
    songIndicesToRemove: [Int],
    songIdsToAdd: [String]
  ) async throws
    -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "updatePlaylist"
      )
      urlComp.addQueryItem(name: "playlistId", value: id)
      urlComp.addQueryItem(name: "name", value: name)
      for songIndex in songIndicesToRemove {
        urlComp.addQueryItem(name: "songIndexToRemove", value: songIndex)
      }
      for songId in songIdsToAdd {
        urlComp.addQueryItem(name: "songIdToAdd", value: songId)
      }
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPodcasts() async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getPodcasts")
      urlComp.addQueryItem(name: "includeEpisodes", value: "false")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPodcastEpisodes(id: String) async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getPodcasts",
        id: id
      )
      urlComp.addQueryItem(name: "includeEpisodes", value: "true")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestNewestPodcasts() async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getNewestPodcasts"
      )
      urlComp.addQueryItem(name: "count", value: 20)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestRadios() async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getInternetRadioStations"
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestMusicFolders() async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getMusicFolders"
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestIndexes(musicFolderId: String) async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getIndexes")
      urlComp.addQueryItem(name: "musicFolderId", value: musicFolderId)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestMusicDirectory(id: String) async throws -> APIDataResponse {
    try await request { version in
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "getMusicDirectory",
        id: id
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestScrobble(
    id: String,
    submission: Bool,
    date: Date? = nil
  ) async throws
    -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "scrobble",
        id: id
      )
      if let date = date {
        urlComp.addQueryItem(name: "date", value: Int(date.timeIntervalSince1970))
      }
      urlComp.addQueryItem(name: "submission", value: submission.description)
      return try self.createUrl(from: urlComp)
    }
  }

  /// Only songs, albums, artists are supported by the subsonic API
  public func requestRating(id: String, rating: Int) async throws -> APIDataResponse {
    try await request { version in
      var urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: "setRating",
        id: id
      )
      urlComp.addQueryItem(name: "rating", value: rating)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSetFavorite(songId: String, isFavorite: Bool) async throws -> APIDataResponse {
    try await request { version in
      let apiFavoriteAction = isFavorite ? "star" : "unstar"
      let urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: apiFavoriteAction,
        id: songId
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSetFavorite(
    albumId: String,
    isFavorite: Bool
  ) async throws
    -> APIDataResponse {
    try await request { version in
      let apiFavoriteAction = isFavorite ? "star" : "unstar"
      var urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: apiFavoriteAction
      )
      urlComp.addQueryItem(name: "albumId", value: albumId)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSetFavorite(
    artistId: String,
    isFavorite: Bool
  ) async throws
    -> APIDataResponse {
    try await request { version in
      let apiFavoriteAction = isFavorite ? "star" : "unstar"
      var urlComp = try self.createAuthApiUrlComponent(
        version: version,
        forAction: apiFavoriteAction
      )
      urlComp.addQueryItem(name: "artistId", value: artistId)
      return try self.createUrl(from: urlComp)
    }
  }

  private func createUrl(from urlComp: URLComponents) throws -> URL {
    if let url = urlComp.url {
      return url
    } else {
      throw BackendError.invalidUrl
    }
  }

  private func request(urlCreation: @escaping (_: SubsonicVersion) throws -> URL) async throws
    -> APIDataResponse {
    let version = try await determineApiVersionToUse()
    let url = try urlCreation(version)
    return try await request(url: url)
  }

  private func request(url: URL) async throws -> APIDataResponse {
    try await withUnsafeThrowingContinuation { continuation in
      let afRequest = AF.request(url, method: .get)
      afRequest.validate().responseData { response in
        if response.response?.statusCode == 404 {
          let cleanedURL = self.cleanse(url: response.request?.url)
          os_log("API 404: Not Found: %s", log: self.log, type: .info, cleanedURL.description)
          let notFoundError = ResponseError(
            type: .api,
            statusCode: SubsonicError.requestedDataNotFound.rawValue,
            message: "404: Not Found",
            cleansedURL: cleanedURL,
            data: response.data
          )
          continuation.resume(throwing: notFoundError)
          return
        }
        if let data = response.data {
          continuation.resume(returning: APIDataResponse(data: data, url: url))
          return
        }
        if let err = response.error {
          continuation.resume(throwing: err)
          return
        }
        fatalError("should not get here")
      }
    }
  }
}
