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

extension ResponseError {
    var asAmpacheError: AmpacheXmlServerApi.AmpacheError? {
        return AmpacheXmlServerApi.AmpacheError(rawValue: statusCode)
    }
}

class AmpacheXmlServerApi {
    
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
    
    var isPodcastSupported: Bool {
        reauthenticateIfNeccessary()
        if let serverApi = serverApiVersion, let serverApiInt = Int(serverApi) {
            return serverApiInt >= 420000
        } else {
            return false
        }
    }
    
    var artistCount: Int {
        reauthenticateIfNeccessary()
        return authHandshake?.artistCount ?? 0
    }
    var albumCount: Int {
        reauthenticateIfNeccessary()
        return authHandshake?.albumCount ?? 0
    }
    var songCount: Int {
        reauthenticateIfNeccessary()
        return authHandshake?.songCount ?? 0
    }
    var genreCount: Int {
        reauthenticateIfNeccessary()
        return authHandshake?.genreCount ?? 0
    }
    var playlistCount: Int {
        reauthenticateIfNeccessary()
        return authHandshake?.playlistCount ?? 0
    }
    var podcastCount: Int {
        reauthenticateIfNeccessary()
        return authHandshake?.podcastCount ?? 0
    }

    var defaultArtworkUrl: String {
        reauthenticateIfNeccessary()
        guard
        let hostname = credentials?.serverUrl,
        let auth = authHandshake,
        var url = URL(string: hostname)
        else { return "" }

        url.appendPathComponent("image.php")
        guard var urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return "" }
        urlComp.addQueryItem(name: "object_id", value: "0")
        urlComp.addQueryItem(name: "object_type", value: "artist")
        urlComp.addQueryItem(name: "auth", value: auth.token)
        guard let urlString = urlComp.string else { return ""}
        return urlString
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

    func isAuthenticated() -> Bool {
        guard let auth = authHandshake else { return false }
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

    private func createAuthenticatedApiUrlComponent() -> URLComponents? {
        reauthenticateIfNeccessary()
        guard let apiUrl = createApiUrl(),
            let auth = authHandshake,
            var urlComp = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false)
          else { return nil }
        urlComp.addQueryItem(name: "auth", value: auth.token)
        return urlComp
    }
 
    func provideCredentials(credentials: LoginCredentials) {
        self.credentials = credentials
    }
    
    func authenticate(credentials: LoginCredentials) {
        if let handshake = requestHandshake(credentials: credentials) {
            self.authHandshake = handshake
            self.credentials = credentials
        } else {
            self.authHandshake = nil
            self.credentials = nil
        }
    }
    
    func isAuthenticationValid(credentials: LoginCredentials) -> Bool {
        return requestHandshake(credentials: credentials) != nil
    }
    
    private func requestHandshake(credentials: LoginCredentials) -> AuthentificationHandshake? {
        let timestamp = Int(NSDate().timeIntervalSince1970)
        let passphrase = generatePassphrase(passwordHash: credentials.passwordHash, timestamp: timestamp)

        guard let apiUrl = createApiUrl(providedCredentials: credentials), var urlComp = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else { return nil }
        urlComp.addQueryItem(name: "action", value: "handshake")
        urlComp.addQueryItem(name: "auth", value: passphrase)
        urlComp.addQueryItem(name: "timestamp", value: timestamp)
        urlComp.addQueryItem(name: "version", value: clientApiVersion)
        urlComp.addQueryItem(name: "user", value: credentials.username)
        guard let url = urlComp.url else {
            os_log("Ampache authentication url is invalid: %s", log: log, type: .error, urlComp.description)
            return nil
        }
        let parser = XMLParser(contentsOf: url)!
        let curDelegate = AuthParserDelegate()
        parser.delegate = curDelegate
        let success = parser.parse()
        if let serverApiVersion = curDelegate.serverApiVersion {
            self.serverApiVersion = serverApiVersion
        }
        if let error = parser.parserError {
            os_log("Error during AuthPars: %s", log: log, type: .error, error.localizedDescription)
            return nil
        }
        if success && curDelegate.authHandshake != nil {
            return curDelegate.authHandshake
        } else {
            authHandshake = nil
            os_log("Couldn't get a login token.", log: log, type: .error)
            if let apiError = curDelegate.error {
                eventLogger.report(error: apiError, displayPopup: true)
            }
            return nil
        }
    }
    
    private func reauthenticateIfNeccessary() {
        if !isAuthenticated() {
            if let cred = credentials {
                authenticate(credentials: cred)
            }
        }
    }
    
    func requestCatalogs(parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "catalogs")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestGenres(parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "genres")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }

    func requestArtists(parserDelegate: AmpacheXmlParser) {
        reauthenticateIfNeccessary()
        guard let auth = authHandshake else { return }
        let pollCount = (auth.artistCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        for i in 0...pollCount {
            requestArtists(parserDelegate: parserDelegate, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        }
    }

    func requestArtists(parserDelegate: AmpacheXmlParser, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.artistCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "artists")
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }

    func requestArtists(parserDelegate: AmpacheXmlParser, addDate: Date, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.artistCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "artists")
        apiUrlComponent.addQueryItem(name: "add", value: addDate.asIso8601String)
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestArtistWithinCatalog(of catalog: MusicFolder, parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "advanced_search")
        apiUrlComponent.addQueryItem(name: "rule_1", value: "catalog")
        apiUrlComponent.addQueryItem(name: "rule_1_operator", value: 0)
        apiUrlComponent.addQueryItem(name: "rule_1_input", value: Int(catalog.id) ?? 0)
        apiUrlComponent.addQueryItem(name: "type", value: "artist")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestArtistInfo(of artist: Artist, parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "artist")
        apiUrlComponent.addQueryItem(name: "filter", value: artist.id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }

    func requestArtistAlbums(of artist: Artist, parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "artist_albums")
        apiUrlComponent.addQueryItem(name: "filter", value: artist.id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestArtistSongs(of artist: Artist, parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "artist_songs")
        apiUrlComponent.addQueryItem(name: "filter", value: artist.id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestAlbumInfo(of album: Album, parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "album")
        apiUrlComponent.addQueryItem(name: "filter", value: album.id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestAlbumSongs(of album: Album, parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "album_songs")
        apiUrlComponent.addQueryItem(name: "filter", value: album.id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestSongInfo(of song: Song, parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "song")
        apiUrlComponent.addQueryItem(name: "filter", value: song.id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }

    func requestAlbums(parserDelegate: AmpacheXmlParser) {
        reauthenticateIfNeccessary()
        guard let auth = authHandshake else { return }
        let pollCount = (auth.albumCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        for i in 0...pollCount {
            requestAlbums(parserDelegate: parserDelegate, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        }
    }

    func requestAlbums(parserDelegate: AmpacheXmlParser, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.albumCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "albums")
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }

    func requestAlbums(parserDelegate: AmpacheXmlParser, addDate: Date, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.albumCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "albums")
        apiUrlComponent.addQueryItem(name: "add", value: addDate.asIso8601String)
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }

    func requestSongs(parserDelegate: AmpacheXmlParser) {
        reauthenticateIfNeccessary()
        guard let auth = authHandshake else { return }
        let pollCount = (auth.songCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        for i in 0...pollCount {
            requestSongs(parserDelegate: parserDelegate, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        }
    }

    func requestSongs(parserDelegate: AmpacheXmlParser, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.songCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "songs")
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestSongs(parserDelegate: AmpacheXmlParser, addDate: Date, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.songCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "songs")
        apiUrlComponent.addQueryItem(name: "add", value: addDate.asIso8601String)
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestRandomSongs(parserDelegate: AmpacheXmlParser, count: Int) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_generate")
        apiUrlComponent.addQueryItem(name: "mode", value: "random")
        apiUrlComponent.addQueryItem(name: "format", value: "song")
        apiUrlComponent.addQueryItem(name: "limit", value: count)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }

    func requestPodcastEpisodeDelete(parserDelegate: AmpacheXmlParser, id: String) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "podcast_episode_delete")
        apiUrlComponent.addQueryItem(name: "filter", value: id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestFavoriteArtists(parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "advanced_search")
        apiUrlComponent.addQueryItem(name: "rule_1", value: "favorite")
        apiUrlComponent.addQueryItem(name: "rule_1_operator", value: 0)
        apiUrlComponent.addQueryItem(name: "rule_1_input", value: "")
        apiUrlComponent.addQueryItem(name: "type", value: "artist")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestFavoriteAlbums(parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "advanced_search")
        apiUrlComponent.addQueryItem(name: "rule_1", value: "favorite")
        apiUrlComponent.addQueryItem(name: "rule_1_operator", value: 0)
        apiUrlComponent.addQueryItem(name: "rule_1_input", value: "")
        apiUrlComponent.addQueryItem(name: "type", value: "album")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestFavoriteSongs(parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "advanced_search")
        apiUrlComponent.addQueryItem(name: "rule_1", value: "favorite")
        apiUrlComponent.addQueryItem(name: "rule_1_operator", value: 0)
        apiUrlComponent.addQueryItem(name: "rule_1_input", value: "")
        apiUrlComponent.addQueryItem(name: "type", value: "song")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestRecentSongs(parserDelegate: AmpacheXmlParser, count: Int) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "advanced_search")
        apiUrlComponent.addQueryItem(name: "rule_1", value: "recent_added")
        apiUrlComponent.addQueryItem(name: "rule_1_operator", value: 0)
        apiUrlComponent.addQueryItem(name: "rule_1_input", value: count)
        apiUrlComponent.addQueryItem(name: "type", value: "song")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylists(parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlists")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylist(parserDelegate: AmpacheXmlParser, id: String) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist")
        apiUrlComponent.addQueryItem(name: "filter", value: id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylistSongs(parserDelegate: AmpacheXmlParser, id: String) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_songs")
        apiUrlComponent.addQueryItem(name: "filter", value: id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylistCreate(parserDelegate: AmpacheXmlParser, playlist: Playlist) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_create")
        apiUrlComponent.addQueryItem(name: "name", value: playlist.name)
        apiUrlComponent.addQueryItem(name: "type", value: "private")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylistDelete(playlist: Playlist) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_delete")
        apiUrlComponent.addQueryItem(name: "filter", value: playlist.id)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestPlaylistAddSong(playlist: Playlist, song: Song) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_add_song")
        apiUrlComponent.addQueryItem(name: "filter", value: playlist.id)
        apiUrlComponent.addQueryItem(name: "song", value: song.id)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestPlaylistDeleteItem(playlist: Playlist, index: Int) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_remove_song")
        apiUrlComponent.addQueryItem(name: "filter", value: playlist.id)
        apiUrlComponent.addQueryItem(name: "track", value: index + 1)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestPlaylistEditOnlyName(playlist: Playlist) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_edit")
        apiUrlComponent.addQueryItem(name: "filter", value: playlist.id)
        apiUrlComponent.addQueryItem(name: "name", value: playlist.name)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestPlaylistEdit(playlist: Playlist) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_edit")
        apiUrlComponent.addQueryItem(name: "filter", value: playlist.id)
        let playlistSongs = playlist.playables
        if playlistSongs.count > 0 {
            apiUrlComponent.addQueryItem(name: "items", value: playlist.playables.compactMap{ $0.id }.joined(separator: ","))
            apiUrlComponent.addQueryItem(name: "tracks", value: Array(1...playlist.playables.count).compactMap{"\($0)"}.joined(separator: ","))
        }
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestPodcasts(parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "podcasts")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestPodcastEpisodes(of podcast: Podcast, parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "podcast_episodes")
        apiUrlComponent.addQueryItem(name: "filter", value: podcast.id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestRecordPlay(parserDelegate: AmpacheXmlParser, song: Song, date: Date?) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "record_play")
        if let username = credentials?.username {
            apiUrlComponent.addQueryItem(name: "user", value: username)
        }
        if let date = date {
            apiUrlComponent.addQueryItem(name: "date", value: Int(date.timeIntervalSince1970))
        }
        apiUrlComponent.addQueryItem(name: "id", value: song.id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestRate(song: Song, rating: Int) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "rate")
        apiUrlComponent.addQueryItem(name: "type", value: "song")
        apiUrlComponent.addQueryItem(name: "id", value: song.id)
        apiUrlComponent.addQueryItem(name: "rating", value: rating)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestRate(album: Album, rating: Int) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "rate")
        apiUrlComponent.addQueryItem(name: "type", value: "album")
        apiUrlComponent.addQueryItem(name: "id", value: album.id)
        apiUrlComponent.addQueryItem(name: "rating", value: rating)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestRate(artist: Artist, rating: Int) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "rate")
        apiUrlComponent.addQueryItem(name: "type", value: "artist")
        apiUrlComponent.addQueryItem(name: "id", value: artist.id)
        apiUrlComponent.addQueryItem(name: "rating", value: rating)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }

    func requestSetFavorite(song: Song, isFavorite: Bool) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "flag")
        apiUrlComponent.addQueryItem(name: "type", value: "song")
        apiUrlComponent.addQueryItem(name: "id", value: song.id)
        apiUrlComponent.addQueryItem(name: "flag", value: isFavorite ? 1 : 0)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestSetFavorite(album: Album, isFavorite: Bool) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "flag")
        apiUrlComponent.addQueryItem(name: "type", value: "album")
        apiUrlComponent.addQueryItem(name: "id", value: album.id)
        apiUrlComponent.addQueryItem(name: "flag", value: isFavorite ? 1 : 0)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestSetFavorite(artist: Artist, isFavorite: Bool) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "flag")
        apiUrlComponent.addQueryItem(name: "type", value: "artist")
        apiUrlComponent.addQueryItem(name: "id", value: artist.id)
        apiUrlComponent.addQueryItem(name: "flag", value: isFavorite ? 1 : 0)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestSearchArtists(parserDelegate: AmpacheXmlParser, searchText: String) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "artists")
        apiUrlComponent.addQueryItem(name: "filter", value: searchText)
        apiUrlComponent.addQueryItem(name: "limit", value: 40)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestSearchAlbums(parserDelegate: AmpacheXmlParser, searchText: String) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "albums")
        apiUrlComponent.addQueryItem(name: "filter", value: searchText)
        apiUrlComponent.addQueryItem(name: "limit", value: 40)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestSearchSongs(parserDelegate: AmpacheXmlParser, searchText: String) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "search_songs")
        apiUrlComponent.addQueryItem(name: "filter", value: searchText)
        apiUrlComponent.addQueryItem(name: "limit", value: 40)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    private func requestData(fromUrlComponent: URLComponents) -> Data? {
        guard let url = fromUrlComponent.url else {
            os_log("URL could not be created: %s", log: log, type: .error, fromUrlComponent.description)
            return nil
        }
        return try? Data(contentsOf: url)
    }
    
    private func request(fromUrlComponent: URLComponents, viaXmlParser parserDelegate: AmpacheXmlParser) {
        guard let requestedData = requestData(fromUrlComponent: fromUrlComponent) else { return }
        let parser = XMLParser(data: requestedData)
        parser.delegate = parserDelegate
        parser.parse()
        if let error = parserDelegate.error, let ampacheError = error.asAmpacheError, ampacheError != .empty {
            eventLogger.report(error: error, displayPopup: ampacheError.shouldErrorBeDisplayedToUser)
        }
    }

    func requesetLibraryMetaData() -> AuthentificationHandshake? {
        reauthenticateIfNeccessary()
        return authHandshake
    }
    
    func generateUrl(forDownloadingPlayable playable: AbstractPlayable) -> URL? {
        guard var urlString = playable.url else { return nil }
        updateUrlToken(urlString: &urlString)
        return URL(string: urlString)
    }
    
    func generateUrl(forStreamingPlayable playable: AbstractPlayable) -> URL? {
        return generateUrl(forDownloadingPlayable: playable)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        var updatedUrl = artwork.url
        updateUrlToken(urlString: &updatedUrl)
        return URL(string: updatedUrl)
    }
    
    func checkForErrorResponse(inData data: Data) -> ResponseError? {
        let errorParser = AmpacheXmlParser()
        let parser = XMLParser(data: data)
        parser.delegate = errorParser
        parser.parse()
        return errorParser.error
    }
    
    func updateUrlToken(urlString: inout String) {
        reauthenticateIfNeccessary()
        guard
            let auth = authHandshake,
            let inputUrlComp = URLComponents(string: urlString),
            let inputUrl = URL(string: urlString),
            var outputUrlComp = createAuthenticatedApiUrlComponent(),
            let queryItems = inputUrlComp.queryItems
        else { return }

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
        urlString = outputUrlComp.string!
    }
    
}
