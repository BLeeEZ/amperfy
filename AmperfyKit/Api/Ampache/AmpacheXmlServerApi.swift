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

import Foundation
import CoreData
import os.log
import PromiseKit
import Alamofire
import PMKAlamofire

struct AmpacheResponseError: LocalizedError {
    public var statusCode: Int = 0
    public var message: String
    
    public var ampacheError: AmpacheXmlServerApi.AmpacheError? {
        return AmpacheXmlServerApi.AmpacheError(rawValue: statusCode)
    }
}

extension ResponseError {
    var asAmpacheError: AmpacheXmlServerApi.AmpacheError? {
        return AmpacheXmlServerApi.AmpacheError(rawValue: statusCode)
    }
    
    static func createFromAmpacheError(cleansedURL: CleansedURL?, error: AmpacheResponseError, data: Data?) -> ResponseError {
        return ResponseError(statusCode: error.statusCode, message: error.message, cleansedURL: cleansedURL, data: data)
    }
}

class AmpacheXmlServerApi: URLCleanser {
    
    enum AmpacheError: Int {
        case empty = 0
        case accessControlNotEnabled = 4700 // The API is disabled. Enable 'access_control' in your config
        case receivedInvalidHandshake = 4701 //This is a temporary error, this means no valid session was passed or the handshake failed
        case accessDenied = 4703 // The requested method is not available
                                 // You can check the error message for details about which feature is disabled
        case notFound = 4704 // The API could not find the requested object
        case missing = 4705 // This is a fatal error, the service requested a method that the API does not implement
        case depreciated = 4706 // This is a fatal error, the method requested is no longer available
        case badRequest = 4710  // Used when you have specified a valid method but something about the input is incorrect, invalid or missing
                                // You can check the error message for details, but do not re-attempt the exact same request
        case failedAccessCheck = 4742 // Access denied to the requested object or function for this user
        
        var shouldErrorBeDisplayedToUser: Bool {
            return self != .empty && self != .notFound
        }
        
        var isRemoteAvailable: Bool {
            return self != .notFound
        }
    }
    
    static let maxItemCountToPollAtOnce: Int = 500
    static let apiPathComponents = ["server", "xml.server.php"]
    
    var serverApiVersion: String?
    let clientApiVersion = "500000"
    
    private let log = OSLog(subsystem: "Amperfy", category: "Ampache")
    let eventLogger: EventLogger
    private var credentials: LoginCredentials?
    private var authHandshake: AuthentificationHandshake?
    
    func requestServerPodcastSupport() -> Promise<Bool> {
        return firstly {
            reauthenticate()
        }.then { auth -> Promise<Bool> in
            var isPodcastSupported = false
            if let serverApi = self.serverApiVersion, let serverApiInt = Int(serverApi) {
                isPodcastSupported = serverApiInt >= 420000
            }
            return Promise<Bool>.value(isPodcastSupported)
        }
    }
    
    init(eventLogger: EventLogger) {
        self.eventLogger = eventLogger
    }
    
    static func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        guard let url = URL(string: urlString),
            let urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let objectId = urlComp.queryItems?.first(where: {$0.name == "object_id"})?.value,
            let objectType = urlComp.queryItems?.first(where: {$0.name == "object_type"})?.value
        else { return nil }
        return ArtworkRemoteInfo(id: objectId, type: objectType)
    }

    private func isAuthenticated(auth: AuthentificationHandshake) -> Bool {
        let deltaTime:TimeInterval = auth.reauthenicateTime.timeIntervalSince(Date())
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
        let localCredentials = providedCredentials != nil ? providedCredentials : self.credentials
        guard let hostname = localCredentials?.serverUrl else { return nil }
        var apiUrl = URL(string: hostname)
        Self.apiPathComponents.forEach{ apiUrl?.appendPathComponent($0) }
        return apiUrl
    }
 
    private func createAuthApiUrlComponent(auth: AuthentificationHandshake) throws -> URLComponents {
        guard let apiUrl = createApiUrl() else { throw BackendError.invalidUrl }
        guard var urlComp = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else { throw BackendError.invalidUrl }
        urlComp.addQueryItem(name: "auth", value: auth.token)
        return urlComp
    }
    
    func provideCredentials(credentials: LoginCredentials) {
        self.authHandshake = nil
        self.credentials = credentials
    }
    
    private func authenticate(credentials: LoginCredentials) -> Promise<AuthentificationHandshake> {
        return Promise<AuthentificationHandshake> { seal in
            firstly {
                requestAuth(credentials: credentials)
            }.done { auth in
                self.authHandshake = auth
                seal.fulfill(auth)
            }.catch { error in
                self.authHandshake = nil
                seal.reject(error)
            }
        }
    }
    
    func isAuthenticationValid(credentials: LoginCredentials) -> Promise<Void> {
        return requestAuth(credentials: credentials).asVoid()
    }
    
    private func requestAuth(credentials: LoginCredentials) -> Promise<AuthentificationHandshake> {
        return firstly {
            createAuthURL(credentials: credentials)
        }.then { url in
            self.request(url: url)
        }.then { response in
            self.parseAuthResult(response: response)
        }
    }
    
    private func createAuthURL(credentials: LoginCredentials) -> Promise<URL> {
        return Promise<URL> { seal in
            let timestamp = Int(NSDate().timeIntervalSince1970)
            let passphrase = generatePassphrase(passwordHash: credentials.passwordHash, timestamp: timestamp)

            guard let apiUrl = createApiUrl(providedCredentials: credentials), var urlComp = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else { throw BackendError.invalidUrl }
            urlComp.addQueryItem(name: "action", value: "handshake")
            urlComp.addQueryItem(name: "auth", value: passphrase)
            urlComp.addQueryItem(name: "timestamp", value: timestamp)
            urlComp.addQueryItem(name: "version", value: clientApiVersion)
            urlComp.addQueryItem(name: "user", value: credentials.username)
            guard let url = urlComp.url else {
                os_log("Ampache authentication url is invalid: %s", log: log, type: .error, urlComp.description)
                throw BackendError.invalidUrl
            }
            seal.fulfill(url)
        }
    }
    
    func cleanse(url: URL) -> CleansedURL {
        guard
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
    
    private func parseAuthResult(response: APIDataResponse) -> Promise<AuthentificationHandshake> {
        return Promise<AuthentificationHandshake> { seal in
            let parser = XMLParser(data: response.data)
            let curDelegate = AuthParserDelegate()
            parser.delegate = curDelegate
            let success = parser.parse()
            if let serverApiVersion = curDelegate.serverApiVersion {
                self.serverApiVersion = serverApiVersion
            }
            if let error = parser.parserError {
                os_log("Error during AuthPars: %s", log: self.log, type: .error, error.localizedDescription)
                throw XMLParserResponseError(cleansedURL: response.url?.asCleansedURL(cleanser: self), data: response.data)
            }
            if success, let auth = curDelegate.authHandshake {
                return seal.fulfill(auth)
            } else {
                self.authHandshake = nil
                os_log("Couldn't get a login token.", log: self.log, type: .error)
                if let apiError = curDelegate.error {
                    throw apiError
                }
                throw AuthenticationError.notAbleToLogin
            }
        }
    }
    
    private func reauthenticate() -> Promise<AuthentificationHandshake> {
        if let auth = authHandshake, isAuthenticated(auth: auth) {
            return Promise<AuthentificationHandshake>.value(auth)
        } else {
            guard let cred = credentials else { return Promise(error: BackendError.noCredentials) }
            return authenticate(credentials: cred)
        }
    }
    
    func requestDefaultArtwork() -> Promise<APIDataResponse> {
        return request { auth in
            guard let hostname = self.credentials?.serverUrl,
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
    
    func requestCatalogs() -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "catalogs")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestGenres() -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "genres")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestArtists(startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) -> Promise<APIDataResponse> {
        return request { auth in
            let offset = startIndex < auth.artistCount ? startIndex : auth.artistCount-1
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "artists")
            urlComp.addQueryItem(name: "offset", value: offset)
            urlComp.addQueryItem(name: "limit", value: pollCount)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestArtistWithinCatalog(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "advanced_search")
            urlComp.addQueryItem(name: "rule_1", value: "catalog")
            urlComp.addQueryItem(name: "rule_1_operator", value: 0)
            urlComp.addQueryItem(name: "rule_1_input", value: Int(id) ?? 0)
            urlComp.addQueryItem(name: "type", value: "artist")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestArtistInfo(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "artist")
            urlComp.addQueryItem(name: "filter", value: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestArtistAlbums(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "artist_albums")
            urlComp.addQueryItem(name: "filter", value: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestArtistSongs(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "artist_songs")
            urlComp.addQueryItem(name: "filter", value: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestAlbumInfo(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "album")
            urlComp.addQueryItem(name: "filter", value: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestAlbumSongs(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "album_songs")
            urlComp.addQueryItem(name: "filter", value: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSongInfo(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "song")
            urlComp.addQueryItem(name: "filter", value: id)
            return try self.createUrl(from: urlComp)
        }
    }

    func requestAlbums(startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) -> Promise<APIDataResponse> {
        return request { auth in
            let offset = startIndex < auth.albumCount ? startIndex : auth.albumCount-1
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "albums")
            urlComp.addQueryItem(name: "offset", value: offset)
            urlComp.addQueryItem(name: "limit", value: pollCount)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestRandomSongs(count: Int) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "playlist_generate")
            urlComp.addQueryItem(name: "mode", value: "random")
            urlComp.addQueryItem(name: "format", value: "song")
            urlComp.addQueryItem(name: "limit", value: count)
            return try self.createUrl(from: urlComp)
        }
    }

    func requestPodcastEpisodeDelete(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "podcast_episode_delete")
            urlComp.addQueryItem(name: "filter", value: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestFavoriteArtists() -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "advanced_search")
            urlComp.addQueryItem(name: "rule_1", value: "favorite")
            urlComp.addQueryItem(name: "rule_1_operator", value: 0)
            urlComp.addQueryItem(name: "rule_1_input", value: "")
            urlComp.addQueryItem(name: "type", value: "artist")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestFavoriteAlbums() -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "advanced_search")
            urlComp.addQueryItem(name: "rule_1", value: "favorite")
            urlComp.addQueryItem(name: "rule_1_operator", value: 0)
            urlComp.addQueryItem(name: "rule_1_input", value: "")
            urlComp.addQueryItem(name: "type", value: "album")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestFavoriteSongs() -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "advanced_search")
            urlComp.addQueryItem(name: "rule_1", value: "favorite")
            urlComp.addQueryItem(name: "rule_1_operator", value: 0)
            urlComp.addQueryItem(name: "rule_1_input", value: "")
            urlComp.addQueryItem(name: "type", value: "song")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestNewestAlbums(offset: Int, count: Int) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "stats")
            urlComp.addQueryItem(name: "type", value: "album")
            urlComp.addQueryItem(name: "filter", value: "newest")
            urlComp.addQueryItem(name: "limit", value: count)
            urlComp.addQueryItem(name: "offset", value: offset)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestRecentAlbums(offset: Int, count: Int) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "stats")
            urlComp.addQueryItem(name: "type", value: "album")
            urlComp.addQueryItem(name: "filter", value: "recent")
            urlComp.addQueryItem(name: "limit", value: count)
            urlComp.addQueryItem(name: "offset", value: offset)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylists() -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "playlists")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylist(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "playlist")
            urlComp.addQueryItem(name: "filter", value: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistSongs(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "playlist_songs")
            urlComp.addQueryItem(name: "filter", value: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistCreate(name: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "playlist_create")
            urlComp.addQueryItem(name: "name", value: name)
            urlComp.addQueryItem(name: "type", value: "private")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistDelete(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "playlist_delete")
            urlComp.addQueryItem(name: "filter", value: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistAddSong(playlistId: String, songId: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "playlist_add_song")
            urlComp.addQueryItem(name: "filter", value: playlistId)
            urlComp.addQueryItem(name: "song", value: songId)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistDeleteItem(id: String, index: Int) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "playlist_remove_song")
            urlComp.addQueryItem(name: "filter", value: id)
            urlComp.addQueryItem(name: "track", value: index + 1)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistEditOnlyName(id: String, name: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "playlist_edit")
            urlComp.addQueryItem(name: "filter", value: id)
            urlComp.addQueryItem(name: "name", value: name)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistEdit(id: String, songsIds: [String]) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "playlist_edit")
            urlComp.addQueryItem(name: "filter", value: id)
            urlComp.addQueryItem(name: "items", value: songsIds.joined(separator: ","))
            urlComp.addQueryItem(name: "tracks", value: Array(1...songsIds.count).compactMap{"\($0)"}.joined(separator: ","))
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPodcasts() -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "podcasts")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPodcastEpisodes(id: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "podcast_episodes")
            urlComp.addQueryItem(name: "filter", value: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestRecordPlay(songId: String, date: Date?) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "record_play")
            if let username = self.credentials?.username {
                urlComp.addQueryItem(name: "user", value: username)
            }
            if let date = date {
                urlComp.addQueryItem(name: "date", value: Int(date.timeIntervalSince1970))
            }
            urlComp.addQueryItem(name: "id", value: songId)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestRate(songId: String, rating: Int) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "rate")
            urlComp.addQueryItem(name: "type", value: "song")
            urlComp.addQueryItem(name: "id", value: songId)
            urlComp.addQueryItem(name: "rating", value: rating)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestRate(albumId: String, rating: Int) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "rate")
            urlComp.addQueryItem(name: "type", value: "album")
            urlComp.addQueryItem(name: "id", value: albumId)
            urlComp.addQueryItem(name: "rating", value: rating)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestRate(artistId: String, rating: Int) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "rate")
            urlComp.addQueryItem(name: "type", value: "artist")
            urlComp.addQueryItem(name: "id", value: artistId)
            urlComp.addQueryItem(name: "rating", value: rating)
            return try self.createUrl(from: urlComp)
        }
    }

    func requestSetFavorite(songId: String, isFavorite: Bool) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "flag")
            urlComp.addQueryItem(name: "type", value: "song")
            urlComp.addQueryItem(name: "id", value: songId)
            urlComp.addQueryItem(name: "flag", value: isFavorite ? 1 : 0)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSetFavorite(albumId: String, isFavorite: Bool) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "flag")
            urlComp.addQueryItem(name: "type", value: "album")
            urlComp.addQueryItem(name: "id", value: albumId)
            urlComp.addQueryItem(name: "flag", value: isFavorite ? 1 : 0)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSetFavorite(artistId: String, isFavorite: Bool) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "flag")
            urlComp.addQueryItem(name: "type", value: "artist")
            urlComp.addQueryItem(name: "id", value: artistId)
            urlComp.addQueryItem(name: "flag", value: isFavorite ? 1 : 0)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSearchArtists(searchText: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "artists")
            urlComp.addQueryItem(name: "filter", value: searchText)
            urlComp.addQueryItem(name: "limit", value: 40)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSearchAlbums(searchText: String) -> Promise<APIDataResponse> {
        return request { auth in
            var urlComp = try self.createAuthApiUrlComponent(auth: auth)
            urlComp.addQueryItem(name: "action", value: "albums")
            urlComp.addQueryItem(name: "filter", value: searchText)
            urlComp.addQueryItem(name: "limit", value: 40)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSearchSongs(searchText: String) -> Promise<APIDataResponse> {
        return request { auth in
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
    
    private func request(url: URL) -> Promise<APIDataResponse> {
        return firstly {
            AF.request(url, method: .get).validate().responseData()
        }.then { data, response in
            Promise<APIDataResponse>.value(APIDataResponse(data: data, url: url, meta: response))
        }
    }

    func requesetLibraryMetaData() -> Promise<AuthentificationHandshake> {
        return reauthenticate()
    }
    
    func generateUrl(forDownloadingPlayable playable: AbstractPlayable) -> Promise<URL> {
        guard let urlString = playable.url else { return Promise(error: BackendError.invalidUrl) }
        return self.updateUrlToken(urlString: urlString)
    }
    
    func generateUrl(forStreamingPlayable playable: AbstractPlayable) -> Promise<URL> {
        return generateUrl(forDownloadingPlayable: playable)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> Promise<URL> {
        return self.updateUrlToken(urlString: artwork.url)
    }
    
    func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
        let errorParser = AmpacheXmlParser()
        let parser = XMLParser(data: response.data)
        parser.delegate = errorParser
        parser.parse()
        guard let ampacheError = errorParser.error else { return nil }
        return ResponseError.createFromAmpacheError(cleansedURL: response.url?.asCleansedURL(cleanser: self), error: ampacheError, data: response.data)
    }
    
    func updateUrlToken(urlString: String) -> Promise<URL> {
        return firstly {
            reauthenticate()
        }.then { auth -> Promise<URL> in
            guard
                let inputUrlComp = URLComponents(string: urlString),
                let inputUrl = URL(string: urlString),
                var outputUrlComp = try? self.createAuthApiUrlComponent(auth: auth),
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
            return Promise<URL>.value(try self.createUrl(from: outputUrlComp))
        }
    }
    
    private func request(urlCreation: @escaping (_: AuthentificationHandshake) throws -> URL) -> Promise<APIDataResponse> {
        return firstly {
            reauthenticate()
        }.then { auth in
            Promise<URL> { seal in seal.fulfill(try urlCreation(auth)) }
        }.then { url in
            self.request(url: url)
        }
    }
    
}
