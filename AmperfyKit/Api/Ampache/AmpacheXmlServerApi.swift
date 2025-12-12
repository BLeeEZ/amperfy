//
//  AmpacheXmlServerApi.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
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
import CoreData
import Foundation
import os.log

// MARK: - AmpacheResponseError

struct AmpacheResponseError: LocalizedError {
  public var statusCode: Int = 0
  public var message: String

  public var ampacheError: AmpacheXmlServerApi.AmpacheError? {
    AmpacheXmlServerApi.AmpacheError(rawValue: statusCode)
  }
}

extension ResponseError {
  var asAmpacheError: AmpacheXmlServerApi.AmpacheError? {
    AmpacheXmlServerApi.AmpacheError(rawValue: statusCode)
  }

  static func createFromAmpacheError(
    cleansedURL: CleansedURL?,
    error: AmpacheResponseError,
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

// MARK: - AmpacheXmlServerApi

final class AmpacheXmlServerApi: URLCleanser, Sendable {
  enum AmpacheError: Int {
    case empty = 0
    case accessControlNotEnabled =
      4700 // The API is disabled. Enable 'access_control' in your config
    case receivedInvalidHandshake =
      4701 // This is a temporary error, this means no valid session was passed or the handshake failed
    case accessDenied = 4703 // The requested method is not available
    // You can check the error message for details about which feature is disabled
    case notFound = 4704 // The API could not find the requested object
    case missing =
      4705 // This is a fatal error, the service requested a method that the API does not implement
    case depreciated = 4706 // This is a fatal error, the method requested is no longer available
    case badRequest =
      4710 // Used when you have specified a valid method but something about the input is incorrect, invalid or missing
    // You can check the error message for details, but do not re-attempt the exact same request
    case failedAccessCheck = 4742 // Access denied to the requested object or function for this user

    var shouldErrorBeDisplayedToUser: Bool {
      self != .empty && self != .notFound
    }

    var isRemoteAvailable: Bool {
      self != .notFound
    }
  }

  static let maxItemCountToPollAtOnce: Int = 500
  static let apiPathComponents = ["server", "xml.server.php"]

  internal let serverApiVersion = Atomic<String?>(wrappedValue: nil)
  internal let clientApiVersion = "500000"

  private let log = OSLog(subsystem: "Amperfy", category: "Ampache")
  private let performanceMonitor: ThreadPerformanceMonitor
  private let eventLogger: EventLogger
  private let credentials = Atomic<LoginCredentials?>(wrappedValue: nil)
  private let authHandshake = Atomic<AuthentificationHandshake?>(wrappedValue: nil)
  private let settings: AmperfySettings
  public var account: AccountInfo? {
    guard let credentials = credentials.wrappedValue else { return nil }
    return Account.createInfo(credentials: credentials)
  }

  public func requestServerPodcastSupport() async throws -> Bool {
    let _ = try await reauthenticate()
    var isPodcastSupported = false
    if let serverApi = serverApiVersion.wrappedValue, let serverApiInt = Int(serverApi) {
      isPodcastSupported = serverApiInt >= 420000
    }
    return isPodcastSupported
  }

  init(
    performanceMonitor: ThreadPerformanceMonitor,
    eventLogger: EventLogger,
    settings: AmperfySettings
  ) {
    self.performanceMonitor = performanceMonitor
    self.eventLogger = eventLogger
    self.settings = settings
  }

  static func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
    guard let url = URL(string: urlString),
          let urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let objectId = urlComp.queryItems?.first(where: { $0.name == "object_id" })?.value,
          let objectType = urlComp.queryItems?.first(where: { $0.name == "object_type" })?.value
    else { return nil }
    return ArtworkRemoteInfo(id: objectId, type: objectType)
  }

  private func isAuthenticated(auth: AuthentificationHandshake) -> Bool {
    let deltaTime: TimeInterval = auth.reauthenicateTime.timeIntervalSince(Date())
    return !deltaTime.isLess(than: 0.0)
  }

  private func generatePassphrase(passwordHash: String, timestamp: Int) -> String {
    // Ampache passphrase: sha256(unixtime + sha256(password)) where '+' denotes concatenation
    // Concatenate timestamp and password hash
    let dataStr = "\(timestamp)\(passwordHash)"
    let passphrase = StringHasher.sha256(dataString: dataStr)
    return passphrase
  }

  private func createApiUrl(providedCredentials: LoginCredentials? = nil) -> URL? {
    let localCredentials = providedCredentials != nil ? providedCredentials : credentials
      .wrappedValue
    guard let hostname = localCredentials?.activeBackendServerUrl else { return nil }
    var apiUrl = URL(string: hostname)
    Self.apiPathComponents.forEach { apiUrl?.appendPathComponent($0) }
    return apiUrl
  }

  private func createAuthApiUrlComponent(auth: AuthentificationHandshake) throws -> URLComponents {
    guard let apiUrl = createApiUrl() else { throw BackendError.invalidUrl }
    guard var urlComp = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false)
    else { throw BackendError.invalidUrl }
    urlComp.addQueryItem(name: "auth", value: auth.token)
    return urlComp
  }

  func provideCredentials(credentials: LoginCredentials) {
    authHandshake.wrappedValue = nil
    self.credentials.wrappedValue = credentials
  }

  private func authenticate(credentials: LoginCredentials) async throws
    -> AuthentificationHandshake {
    do {
      let auth = try await requestAuth(credentials: credentials)
      authHandshake.wrappedValue = auth
      return auth
    } catch {
      authHandshake.wrappedValue = nil
      throw error
    }
  }

  func isAuthenticationValid(credentials: LoginCredentials) async throws {
    try await requestAuth(credentials: credentials)
  }

  @discardableResult
  private func requestAuth(credentials: LoginCredentials) async throws
    -> AuthentificationHandshake {
    let url = try await createAuthURL(credentials: credentials)
    let response = try await request(url: url)
    return try await parseAuthResult(response: response)
  }

  private func createAuthURL(credentials: LoginCredentials) async throws -> URL {
    let timestamp = Int(NSDate().timeIntervalSince1970)
    let passphrase = generatePassphrase(
      passwordHash: credentials.passwordHash,
      timestamp: timestamp
    )

    guard let apiUrl = createApiUrl(providedCredentials: credentials), var urlComp = URLComponents(
      url: apiUrl,
      resolvingAgainstBaseURL: false
    ) else { throw BackendError.invalidUrl }
    urlComp.addQueryItem(name: "action", value: "handshake")
    urlComp.addQueryItem(name: "auth", value: passphrase)
    urlComp.addQueryItem(name: "timestamp", value: timestamp)
    urlComp.addQueryItem(name: "version", value: clientApiVersion)
    urlComp.addQueryItem(name: "user", value: credentials.username)
    guard let url = urlComp.url else {
      os_log(
        "Ampache authentication url is invalid: %s",
        log: log,
        type: .error,
        urlComp.description
      )
      throw BackendError.invalidUrl
    }
    return url
  }

  func cleanse(url: URL?) -> CleansedURL {
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
      if queryItem.name == "ssid" {
        outputItems.append(URLQueryItem(name: queryItem.name, value: "SSID"))
      } else if queryItem.name == "auth" {
        outputItems.append(URLQueryItem(name: queryItem.name, value: "AUTH"))
      } else if queryItem.name == "user" {
        outputItems.append(URLQueryItem(name: queryItem.name, value: "USER"))
      } else {
        outputItems.append(queryItem)
      }
    }
    urlComp.queryItems = outputItems
    return CleansedURL(urlString: urlComp.string ?? "")
  }

  private func parseAuthResult(response: APIDataResponse) async throws
    -> AuthentificationHandshake {
    let parser = XMLParser(data: response.data)
    let curDelegate = AuthParserDelegate(performanceMonitor: performanceMonitor)
    parser.delegate = curDelegate
    let success = parser.parse()
    if let serverApiVersion = curDelegate.serverApiVersion {
      self.serverApiVersion.wrappedValue = serverApiVersion
    }
    if let error = parser.parserError {
      os_log("Error during AuthPars: %s", log: self.log, type: .error, error.localizedDescription)
      throw ResponseError(
        type: .xml,
        cleansedURL: response.url?.asCleansedURL(cleanser: self),
        data: response.data
      )
    }
    if success, let auth = curDelegate.authHandshake {
      return auth
    } else {
      authHandshake.wrappedValue = nil
      os_log("Couldn't get a login token.", log: self.log, type: .error)
      if let apiError = curDelegate.error {
        throw apiError
      }
      throw AuthenticationError.notAbleToLogin
    }
  }

  private func reauthenticate() async throws -> AuthentificationHandshake {
    if let auth = authHandshake.wrappedValue, isAuthenticated(auth: auth) {
      return auth
    } else {
      guard let cred = credentials.wrappedValue else { throw BackendError.noCredentials }
      return try await authenticate(credentials: cred)
    }
  }

  public func requestDefaultArtwork() async throws -> APIDataResponse {
    try await request { auth in
      guard let hostname = self.credentials.wrappedValue?.activeBackendServerUrl,
            var url = URL(string: hostname)
      else { throw BackendError.invalidUrl }
      url.appendPathComponent("image.php")
      guard var urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        throw BackendError.invalidUrl
      }
      urlComp.addQueryItem(name: "object_id", value: "0")
      urlComp.addQueryItem(name: "object_type", value: "artist")
      urlComp.addQueryItem(name: "auth", value: auth.token)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestCatalogs() async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "catalogs")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestGenres() async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "genres")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestArtists(
    startIndex: Int,
    pollCount: Int = maxItemCountToPollAtOnce
  ) async throws
    -> APIDataResponse {
    try await request { auth in
      let offset = startIndex < auth.artistCount ? startIndex : auth.artistCount - 1
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "artists")
      urlComp.addQueryItem(name: "offset", value: offset)
      urlComp.addQueryItem(name: "limit", value: pollCount)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestArtistWithinCatalog(id: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "advanced_search")
      urlComp.addQueryItem(name: "rule_1", value: "catalog")
      urlComp.addQueryItem(name: "rule_1_operator", value: 0)
      urlComp.addQueryItem(name: "rule_1_input", value: Int(id) ?? 0)
      urlComp.addQueryItem(name: "type", value: "artist")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestArtistInfo(id: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "artist")
      urlComp.addQueryItem(name: "filter", value: id)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestArtistAlbums(id: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "artist_albums")
      urlComp.addQueryItem(name: "filter", value: id)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestArtistSongs(id: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "artist_songs")
      urlComp.addQueryItem(name: "filter", value: id)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestAlbumInfo(id: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "album")
      urlComp.addQueryItem(name: "filter", value: id)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestAlbumSongs(id: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "album_songs")
      urlComp.addQueryItem(name: "filter", value: id)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSongInfo(id: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "song")
      urlComp.addQueryItem(name: "filter", value: id)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestAlbums(
    startIndex: Int,
    pollCount: Int = maxItemCountToPollAtOnce
  ) async throws
    -> APIDataResponse {
    try await request { auth in
      let offset = startIndex < auth.albumCount ? startIndex : auth.albumCount - 1
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "albums")
      urlComp.addQueryItem(name: "offset", value: offset)
      urlComp.addQueryItem(name: "limit", value: pollCount)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestRandomSongs(count: Int) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "playlist_generate")
      urlComp.addQueryItem(name: "mode", value: "random")
      urlComp.addQueryItem(name: "format", value: "song")
      urlComp.addQueryItem(name: "limit", value: count)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPodcastEpisodeDelete(id: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "podcast_episode_delete")
      urlComp.addQueryItem(name: "filter", value: id)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestFavoriteArtists() async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "advanced_search")
      urlComp.addQueryItem(name: "rule_1", value: "favorite")
      urlComp.addQueryItem(name: "rule_1_operator", value: 0)
      urlComp.addQueryItem(name: "rule_1_input", value: "")
      urlComp.addQueryItem(name: "type", value: "artist")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestFavoriteAlbums() async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "advanced_search")
      urlComp.addQueryItem(name: "rule_1", value: "favorite")
      urlComp.addQueryItem(name: "rule_1_operator", value: 0)
      urlComp.addQueryItem(name: "rule_1_input", value: "")
      urlComp.addQueryItem(name: "type", value: "album")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestFavoriteSongs() async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "advanced_search")
      urlComp.addQueryItem(name: "rule_1", value: "favorite")
      urlComp.addQueryItem(name: "rule_1_operator", value: 0)
      urlComp.addQueryItem(name: "rule_1_input", value: "")
      urlComp.addQueryItem(name: "type", value: "song")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestNewestAlbums(offset: Int, count: Int) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "stats")
      urlComp.addQueryItem(name: "type", value: "album")
      urlComp.addQueryItem(name: "filter", value: "newest")
      urlComp.addQueryItem(name: "limit", value: count)
      urlComp.addQueryItem(name: "offset", value: offset)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestRecentAlbums(offset: Int, count: Int) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "stats")
      urlComp.addQueryItem(name: "type", value: "album")
      urlComp.addQueryItem(name: "filter", value: "recent")
      urlComp.addQueryItem(name: "limit", value: count)
      urlComp.addQueryItem(name: "offset", value: offset)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylists() async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "playlists")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylist(id: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "playlist")
      urlComp.addQueryItem(name: "filter", value: id)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylistSongs(id: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "playlist_songs")
      urlComp.addQueryItem(name: "filter", value: id)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylistCreate(name: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "playlist_create")
      urlComp.addQueryItem(name: "name", value: name)
      urlComp.addQueryItem(name: "type", value: "private")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylistDelete(id: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "playlist_delete")
      urlComp.addQueryItem(name: "filter", value: id)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylistAddSong(
    playlistId: String,
    songId: String
  ) async throws
    -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "playlist_add_song")
      urlComp.addQueryItem(name: "filter", value: playlistId)
      urlComp.addQueryItem(name: "song", value: songId)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylistDeleteItem(id: String, index: Int) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "playlist_remove_song")
      urlComp.addQueryItem(name: "filter", value: id)
      urlComp.addQueryItem(name: "track", value: index + 1)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylistEditOnlyName(
    id: String,
    name: String
  ) async throws
    -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "playlist_edit")
      urlComp.addQueryItem(name: "filter", value: id)
      urlComp.addQueryItem(name: "name", value: name)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPlaylistEdit(id: String, songsIds: [String]) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "playlist_edit")
      urlComp.addQueryItem(name: "filter", value: id)
      urlComp.addQueryItem(name: "items", value: songsIds.joined(separator: ","))
      urlComp.addQueryItem(
        name: "tracks",
        value: Array(1 ... songsIds.count).compactMap { "\($0)" }.joined(separator: ",")
      )
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestRadios() async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "live_streams")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPodcasts() async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "podcasts")
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestPodcastEpisodes(
    id: String,
    limit: Int? = nil
  ) async throws
    -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "podcast_episodes")
      urlComp.addQueryItem(name: "filter", value: id)
      if let limit = limit {
        urlComp.addQueryItem(name: "limit", value: limit)
      }
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestRecordPlay(songId: String, date: Date?) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "record_play")
      if let username = self.credentials.wrappedValue?.username {
        urlComp.addQueryItem(name: "user", value: username)
      }
      if let date = date {
        urlComp.addQueryItem(name: "date", value: Int(date.timeIntervalSince1970))
      }
      urlComp.addQueryItem(name: "id", value: songId)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestRate(songId: String, rating: Int) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "rate")
      urlComp.addQueryItem(name: "type", value: "song")
      urlComp.addQueryItem(name: "id", value: songId)
      urlComp.addQueryItem(name: "rating", value: rating)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestRate(albumId: String, rating: Int) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "rate")
      urlComp.addQueryItem(name: "type", value: "album")
      urlComp.addQueryItem(name: "id", value: albumId)
      urlComp.addQueryItem(name: "rating", value: rating)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestRate(artistId: String, rating: Int) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "rate")
      urlComp.addQueryItem(name: "type", value: "artist")
      urlComp.addQueryItem(name: "id", value: artistId)
      urlComp.addQueryItem(name: "rating", value: rating)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSetFavorite(songId: String, isFavorite: Bool) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "flag")
      urlComp.addQueryItem(name: "type", value: "song")
      urlComp.addQueryItem(name: "id", value: songId)
      urlComp.addQueryItem(name: "flag", value: isFavorite ? 1 : 0)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSetFavorite(
    albumId: String,
    isFavorite: Bool
  ) async throws
    -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "flag")
      urlComp.addQueryItem(name: "type", value: "album")
      urlComp.addQueryItem(name: "id", value: albumId)
      urlComp.addQueryItem(name: "flag", value: isFavorite ? 1 : 0)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSetFavorite(
    artistId: String,
    isFavorite: Bool
  ) async throws
    -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "flag")
      urlComp.addQueryItem(name: "type", value: "artist")
      urlComp.addQueryItem(name: "id", value: artistId)
      urlComp.addQueryItem(name: "flag", value: isFavorite ? 1 : 0)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSearchArtists(searchText: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "artists")
      urlComp.addQueryItem(name: "filter", value: searchText)
      urlComp.addQueryItem(name: "limit", value: 40)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSearchAlbums(searchText: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "albums")
      urlComp.addQueryItem(name: "filter", value: searchText)
      urlComp.addQueryItem(name: "limit", value: 40)
      return try self.createUrl(from: urlComp)
    }
  }

  public func requestSearchSongs(searchText: String) async throws -> APIDataResponse {
    try await request { auth in
      var urlComp = try self.createAuthApiUrlComponent(auth: auth)
      urlComp.addQueryItem(name: "action", value: "search_songs")
      urlComp.addQueryItem(name: "filter", value: searchText)
      urlComp.addQueryItem(name: "limit", value: 40)
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

  private func request(url: URL) async throws -> APIDataResponse {
    try await withUnsafeThrowingContinuation { continuation in
      AF.request(url, method: .get).validate().responseData { response in

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

  func requesetLibraryMetaData() async throws -> AuthentificationHandshake {
    try await reauthenticate()
  }

  public func generateUrlForDownloadingPlayable(isSong: Bool, id: String) async throws -> URL {
    let auth = try await reauthenticate()

    var urlComp = try createAuthApiUrlComponent(auth: auth)
    urlComp.addQueryItem(name: "action", value: "download")
    urlComp.addQueryItem(name: "type", value: isSong ? "song" : "podcast_episode")
    urlComp.addQueryItem(name: "id", value: id)
    switch settings.user.cacheTranscodingFormatPreference {
    case .mp3:
      urlComp.addQueryItem(name: "format", value: "mp3")
    default:
      urlComp.addQueryItem(name: "format", value: "raw")
    }
    return try createUrl(from: urlComp)
  }

  public func generateUrlForStreamingPlayable(
    isSong: Bool,
    id: String,
    maxBitrate: StreamingMaxBitratePreference,
    formatPreference: StreamingFormatPreference
  ) async throws
    -> URL {
    let auth = try await reauthenticate()

    var urlComp = try createAuthApiUrlComponent(auth: auth)
    urlComp.addQueryItem(name: "action", value: "stream")
    urlComp.addQueryItem(name: "type", value: isSong ? "song" : "podcast_episode")
    urlComp.addQueryItem(name: "id", value: id)

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
      urlComp.addQueryItem(name: "bitrate", value: maxBitrate.rawValue)
    }
    urlComp.addQueryItem(name: "length", value: 1)
    let url = try createUrl(from: urlComp)
    return url
  }

  public func generateUrlForArtwork(artworkRemoteInfo: ArtworkRemoteInfo) async throws -> URL {
    guard let hostname = credentials
      .wrappedValue?.activeBackendServerUrl else { throw BackendError.noCredentials }
    guard var apiUrl = URL(string: hostname) else { throw BackendError.invalidUrl }
    apiUrl.appendPathComponent("image.php")

    guard var urlComp = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false)
    else { throw BackendError.invalidUrl }

    urlComp.addQueryItem(name: "object_id", value: artworkRemoteInfo.id)
    urlComp.addQueryItem(name: "object_type", value: artworkRemoteInfo.type)

    let url = try createUrl(from: urlComp)
    return url
  }

  public func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
    let errorParser = AmpacheXmlParser(performanceMonitor: performanceMonitor)
    let parser = XMLParser(data: response.data)
    parser.delegate = errorParser
    parser.parse()
    guard let ampacheError = errorParser.error else { return nil }
    return ResponseError.createFromAmpacheError(
      cleansedURL: cleanse(url: response.url),
      error: ampacheError,
      data: response.data
    )
  }

  private func updateUrlToken(urlString: String) async throws -> URL {
    let auth = try await reauthenticate()
    guard let inputUrlComp = URLComponents(string: urlString),
          let inputUrl = URL(string: urlString),
          var outputUrlComp = try? createAuthApiUrlComponent(auth: auth),
          let queryItems = inputUrlComp.queryItems
    else { throw BackendError.invalidUrl }

    var outputItems = [URLQueryItem]()
    for queryItem in queryItems {
      if queryItem.name.isContainedIn(["ssid", "auth"]) {
        outputItems.append(URLQueryItem(name: queryItem.name, value: auth.token))
      } else {
        outputItems.append(queryItem)
      }
    }

    outputUrlComp.queryItems = outputItems
    outputUrlComp.path = inputUrl.path
    return try createUrl(from: outputUrlComp)
  }

  private func request(
    urlCreation: @escaping (_: AuthentificationHandshake) throws
      -> URL
  ) async throws
    -> APIDataResponse {
    let auth = try await reauthenticate()
    let url = try urlCreation(auth)
    return try await request(url: url)
  }
}
