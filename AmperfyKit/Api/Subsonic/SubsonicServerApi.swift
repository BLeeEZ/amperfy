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

import Foundation
import os.log
import PromiseKit
import Alamofire
import PMKAlamofire

protocol SubsonicUrlCreator {
    func getArtUrlString(forCoverArtId: String) -> String
}

enum SubsonicApiAuthType: Int {
    case autoDetect = 0
    case legacy = 1
}

extension ResponseError {
    var asSubsonicError: SubsonicServerApi.SubsonicError? {
        return SubsonicServerApi.SubsonicError(rawValue: statusCode)
    }
}


class SubsonicServerApi {
    
    enum SubsonicError: Int {
        case generic = 0 // A generic error.
        case requiredParameterMissing = 10 // Required parameter is missing.
        case clientVersionToLow = 20 // Incompatible Subsonic REST protocol version. Client must upgrade.
        case serverVerionToLow = 30 // Incompatible Subsonic REST protocol version. Server must upgrade.
        case wrongUsernameOrPassword = 40 // Wrong username or password.
        case tokenAuthenticationNotSupported = 41 // Token authentication not supported for LDAP users.
        case userIsNotAuthorized = 50 // User is not authorized for the given operation.
        case trialPeriodForServerIsOver = 60 // The trial period for the Subsonic server is over. Please upgrade to Subsonic Premium. Visit subsonic.org for details.
        case requestedDataNotFound = 70 // The requested data was not found.
        
        var shouldErrorBeDisplayedToUser: Bool {
            return self != .requestedDataNotFound
        }

        var isRemoteAvailable: Bool {
            return self != .requestedDataNotFound
        }
    }
    
    static let defaultClientApiVersionWithToken = SubsonicVersion(major: 1, minor: 13, patch: 0)
    static let defaultClientApiVersionPreToken = SubsonicVersion(major: 1, minor: 11, patch: 0)
    
    var serverApiVersion: SubsonicVersion?
    var clientApiVersion: SubsonicVersion?
    var authType: SubsonicApiAuthType = .autoDetect
    
    private let log = OSLog(subsystem: "Amperfy", category: "Subsonic")
    private let eventLogger: EventLogger
    private var credentials: LoginCredentials?
    
    init(eventLogger: EventLogger) {
        self.eventLogger = eventLogger
    }
    
    static func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        guard let url = URL(string: urlString),
            let urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let id = urlComp.queryItems?.first(where: {$0.name == "id"})?.value
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
    
    private func determineApiVersionToUse(providedCredentials: LoginCredentials? = nil) -> Promise<SubsonicVersion> {
        return firstly {
            self.getCachedServerApiVersionOrRequestIt(providedCredentials: providedCredentials)
        }.then { version in
            self.determineClientApiVersion(serverVersion: version)
        }
    }
    
    private func getCachedServerApiVersionOrRequestIt(providedCredentials: LoginCredentials? = nil) -> Promise<SubsonicVersion> {
        if let serverVersion = serverApiVersion {
            return Promise<SubsonicVersion>.value(serverVersion)
        } else {
            return self.requestServerApiVersionPromise(providedCredentials: providedCredentials)
        }
    }
    
    private func determineClientApiVersion(serverVersion: SubsonicVersion) -> Promise<SubsonicVersion> {
        return Promise<SubsonicVersion> { seal in
            if let clientApi = self.clientApiVersion {
                return seal.fulfill(clientApi)
            }
            guard authType != .legacy else {
                os_log("Client API legacy login", log: log, type: .info)
                self.clientApiVersion = SubsonicServerApi.defaultClientApiVersionPreToken
                return seal.fulfill(self.clientApiVersion!)
            }
            os_log("Server API version is '%s'", log: log, type: .info, serverVersion.description)
            if serverVersion < SubsonicVersion.authenticationTokenRequiredServerApi {
                self.clientApiVersion = SubsonicServerApi.defaultClientApiVersionPreToken
            } else {
                self.clientApiVersion = SubsonicServerApi.defaultClientApiVersionWithToken
            }
            os_log("Client API version is '%s'", log: log, type: .info, self.clientApiVersion!.description)
            return seal.fulfill(clientApiVersion!)
        }
    }
    
    private func createBasicApiUrlComponent(forAction: String, providedCredentials: LoginCredentials? = nil) -> URLComponents? {
        let localCredentials = providedCredentials != nil ? providedCredentials : self.credentials
        guard let hostname = localCredentials?.serverUrl,
              var apiUrl = URL(string: hostname)
        else { return nil }
        
        apiUrl.appendPathComponent("rest")
        apiUrl.appendPathComponent("\(forAction).view")
    
        return URLComponents(url: apiUrl, resolvingAgainstBaseURL: false)
    }
    
    private func createAuthApiUrlComponent(version: SubsonicVersion, forAction: String, credentials providedCredentials: LoginCredentials? = nil) throws -> URLComponents {
        let localCredentials = providedCredentials != nil ? providedCredentials : self.credentials
        guard let username = localCredentials?.username,
              let password = localCredentials?.password,
              var urlComp = createBasicApiUrlComponent(forAction: forAction, providedCredentials: localCredentials)
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
    
    private func createAuthApiUrlComponent(version: SubsonicVersion, forAction: String, id: String) throws -> URLComponents {
        var urlComp = try createAuthApiUrlComponent(version: version, forAction: forAction)
        urlComp.addQueryItem(name: "id", value: id)
        return urlComp
    }
    
    func provideCredentials(credentials: LoginCredentials) {
        self.credentials = credentials
    }
    
    func isAuthenticationValid(credentials: LoginCredentials) -> Promise<Void> {
        return firstly {
            self.requestServerApiVersionPromise(providedCredentials: credentials)
        }.then { version in
            self.determineClientApiVersion(serverVersion: version)
        }.then { version -> Promise<Data> in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "ping", credentials: credentials)
            return self.request(url: try self.createUrl(from: urlComp))
        }.then { data -> Promise<Void> in
            let parserDelegate = SsPingParserDelegate()
            let parser = XMLParser(data: data)
            parser.delegate = parserDelegate
            let success = parser.parse()
            
            if let error = parser.parserError {
                os_log("Error during login parsing: %s", log: self.log, type: .error, error.localizedDescription)
                throw AuthenticationError.notAbleToLogin
            }
            if success, parserDelegate.isAuthValid {
                return Promise.value
            } else {
                os_log("Couldn't login.", log: self.log, type: .error)
                throw AuthenticationError.notAbleToLogin
            }
        }
    }
    
    func generateUrl(forDownloadingPlayable playable: AbstractPlayable) -> Promise<URL> {
        return firstly {
            self.determineApiVersionToUse()
        }.then { version -> Promise<URL> in
            if let podcastEpisode = playable.asPodcastEpisode, let streamId = podcastEpisode.streamId {
                return Promise<URL>.value(try self.createUrl(from: try self.createAuthApiUrlComponent(version: version, forAction: "download", id: streamId)))
            } else {
                return Promise<URL>.value(try self.createUrl(from: try self.createAuthApiUrlComponent(version: version, forAction: "download", id: playable.id)))
            }
        }
    }
    
    func generateUrl(forStreamingPlayable playable: AbstractPlayable) -> Promise<URL> {
        return firstly {
            self.determineApiVersionToUse()
        }.then { version -> Promise<URL> in
            if let podcastEpisode = playable.asPodcastEpisode, let streamId = podcastEpisode.streamId {
                return Promise<URL>.value(try self.createUrl(from: try self.createAuthApiUrlComponent(version: version, forAction: "stream", id: streamId)))
            } else {
                return Promise<URL>.value(try self.createUrl(from: try self.createAuthApiUrlComponent(version: version, forAction: "stream", id: playable.id)))
            }
        }
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> Promise<URL> {
        guard let urlComp = URLComponents(string: artwork.url),
           let queryItems = urlComp.queryItems,
           let coverArtQuery = queryItems.first(where: {$0.name == "id"}),
           let coverArtId = coverArtQuery.value
        else { return Promise(error: BackendError.invalidUrl) }
        return firstly {
            self.determineApiVersionToUse()
        }.then { version in
            Promise<URL>.value(try self.createUrl(from: try self.createAuthApiUrlComponent(version: version, forAction: "getCoverArt", id: coverArtId)))
        }
    }
    
    private func requestServerApiVersionPromise(providedCredentials: LoginCredentials? = nil) -> Promise<SubsonicVersion> {
        return firstly {
            Promise<URL> { seal in
                guard let urlComp = createBasicApiUrlComponent(forAction: "ping", providedCredentials: providedCredentials) else {
                    throw BackendError.invalidUrl
                }
                return seal.fulfill(try createUrl(from: urlComp))
            }
        }.then { url in
            self.request(url: url)
        }.then { data in
            return Promise<SubsonicVersion> { seal in
                let delegate = SsPingParserDelegate()
                let parser = XMLParser(data: data)
                parser.delegate = delegate
                parser.parse()
                guard let serverApiVersionString = delegate.serverApiVersion else { throw BackendError.parser }
                guard let serverApiVersion = SubsonicVersion(serverApiVersionString) else {
                    os_log("The server API version '%s' could not be parsed to 'SubsonicVersion'", log: self.log, type: .info, serverApiVersionString)
                    throw BackendError.parser
                }
                self.serverApiVersion = serverApiVersion
                return seal.fulfill(serverApiVersion)
            }
        }
    }
    
    func requestServerPodcastSupport() -> Promise<Bool> {
        return firstly {
            self.determineApiVersionToUse()
        }.then { auth -> Promise<Bool> in
            var isPodcastSupported = false
            if let serverApi = self.serverApiVersion {
                isPodcastSupported = serverApi >= SubsonicVersion(major: 1, minor: 9, patch: 0)
            }
            if !isPodcastSupported {
                return Promise<Bool>.value(isPodcastSupported)
            } else {
                return Promise<Bool> { seal in
                    firstly {
                        self.requestPodcasts().asVoid()
                    }.done {
                        seal.fulfill(true)
                    }.catch { error in
                        seal.fulfill(false)
                    }
                }
            }
        }
    }

    func requestGenres() -> Promise<Data> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getGenres")
            return try self.createUrl(from: urlComp)
        }
    }

    func requestArtists() -> Promise<Data> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getArtists")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestArtist(id: String) -> Promise<Data> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getArtist", id: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestAlbum(id: String) -> Promise<Data> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getAlbum", id: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSongInfo(id: String) -> Promise<Data> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getSong", id: id)
            return try self.createUrl(from: urlComp)
        }
    }

    func requestFavoriteElements() -> Promise<Data> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getStarred2")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestLatestAlbums() -> Promise<Data> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getAlbumList2")
            urlComp.addQueryItem(name: "type", value: "newest")
            urlComp.addQueryItem(name: "size", value: 20)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestRandomSongs(count: Int) -> Promise<Data> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getRandomSongs")
            urlComp.addQueryItem(name: "size", value: count)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPodcastEpisodeDelete(id: String) -> Promise<Data>  {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "deletePodcastEpisode", id: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSearchArtists(searchText: String) -> Promise<Data> {
        return request { version in
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
    
    
    func requestSearchAlbums(searchText: String) -> Promise<Data> {
        return request { version in
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
    
    func requestSearchSongs(searchText: String) -> Promise<Data> {
        return request { version in
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
    
    func requestPlaylists() -> Promise<Data> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getPlaylists")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistSongs(id: String) -> Promise<Data> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getPlaylist", id: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistCreate(name: String) -> Promise<Data> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "createPlaylist")
            urlComp.addQueryItem(name: "name", value: name)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistDelete(id: String) -> Promise<Data> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "deletePlaylist", id: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func checkForErrorResponse(inData data: Data) -> ResponseError? {
        let errorParser = SsXmlParser()
        let parser = XMLParser(data: data)
        parser.delegate = errorParser
        parser.parse()
        return errorParser.error
    }

    func requestPlaylistUpdate(id: String, name: String, songIndicesToRemove: [Int], songIdsToAdd: [String]) -> Promise<Data> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "updatePlaylist")
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
    
    func requestPodcasts() -> Promise<Data> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getPodcasts")
            urlComp.addQueryItem(name: "includeEpisodes", value: "false")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPodcastEpisodes(id: String) -> Promise<Data> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getPodcasts", id: id)
            urlComp.addQueryItem(name: "includeEpisodes", value: "true")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestMusicFolders() -> Promise<Data> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getMusicFolders")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestIndexes(musicFolderId: String) -> Promise<Data> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getIndexes")
            urlComp.addQueryItem(name: "musicFolderId", value: musicFolderId)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestMusicDirectory(id: String) -> Promise<Data> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getMusicDirectory", id: id)
            return try self.createUrl(from: urlComp)
        }
    }

    func requestRecordSongPlay(id: String, date: Date?) -> Promise<Data> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "scrobble", id: id)
            if let date = date {
                urlComp.addQueryItem(name: "date", value: Int(date.timeIntervalSince1970))
            }
            return try self.createUrl(from: urlComp)
        }
    }

    /// Only songs, albums, artists are supported by the subsonic API
    func requestRating(id: String, rating: Int) -> Promise<Data> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "setRating", id: id)
            urlComp.addQueryItem(name: "rating", value: rating)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSetFavorite(songId: String, isFavorite: Bool) -> Promise<Data> {
        return request { version in
            let apiFavoriteAction = isFavorite ? "star" : "unstar"
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: apiFavoriteAction, id: songId)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSetFavorite(albumId: String, isFavorite: Bool) -> Promise<Data> {
        return request { version in
            let apiFavoriteAction = isFavorite ? "star" : "unstar"
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: apiFavoriteAction)
            urlComp.addQueryItem(name: "albumId", value: albumId)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSetFavorite(artistId: String, isFavorite: Bool) -> Promise<Data> {
        return request { version in
            let apiFavoriteAction = isFavorite ? "star" : "unstar"
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: apiFavoriteAction)
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
    
    private func request(urlCreation: @escaping (_: SubsonicVersion) throws -> URL) -> Promise<Data> {
        return firstly {
            self.determineApiVersionToUse()
        }.then { version in
            Promise<URL> { seal in seal.fulfill(try urlCreation(version)) }
        }.then { url in
            self.request(url: url)
        }
    }
    
    private func request(url: URL) -> Promise<Data> {
        return firstly {
            AF.request(url, method: .get).validate().responseData()
        }.then { data, response in
            Promise<Data>.value(data)
        }
    }
    
}

extension SubsonicServerApi: SubsonicUrlCreator {
    func getArtUrlString(forCoverArtId id: String) -> String {
        guard let clientVersion = self.clientApiVersion else { return "" }
        if let apiUrlComponent = try? createAuthApiUrlComponent(version: clientVersion, forAction: "getCoverArt", id: id),
           let url = apiUrlComponent.url {
            return url.absoluteString
        } else {
            return ""
        }
        
    }
}

