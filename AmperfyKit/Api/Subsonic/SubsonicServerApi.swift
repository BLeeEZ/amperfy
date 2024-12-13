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

struct SubsonicResponseError: LocalizedError {
    public var statusCode: Int = 0
    public var message: String
    
    public var subsonicError: SubsonicServerApi.SubsonicError? {
        return SubsonicServerApi.SubsonicError(rawValue: statusCode)
    }
}

extension ResponseError {
    var asSubsonicError: SubsonicServerApi.SubsonicError? {
        return SubsonicServerApi.SubsonicError(rawValue: statusCode)
    }
    
    static func createFromSubsonicError(cleansedURL: CleansedURL?, error: SubsonicResponseError, data: Data?) -> ResponseError {
        return ResponseError(statusCode: error.statusCode, message: error.message, cleansedURL: cleansedURL, data: data)
    }
}

enum OpenSubsonicExtension: String {
    case songLyrics = "songLyrics"
}

struct OpenSubsonicExtensionsSupport {
    var extensionResponse: OpenSubsonicExtensionsResponse?
    var isSupported = false
}

class SubsonicServerApi: URLCleanser {
    
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
    var isStreamingTranscodingActive: Bool {
        return persistentStorage.settings.streamingFormatPreference != .raw
    }
    var authType: SubsonicApiAuthType = .autoDetect
    private var authTypeBasedClientApiVersion: SubsonicVersion {
        return self.authType == .legacy ? Self.defaultClientApiVersionPreToken : Self.defaultClientApiVersionWithToken
    }
    
    private let log = OSLog(subsystem: "Amperfy", category: "Subsonic")
    private let performanceMonitor: ThreadPerformanceMonitor
    private let eventLogger: EventLogger
    private let persistentStorage: PersistentStorage
    private var credentials: LoginCredentials?
    private var openSubsonicExtensionsSupport: OpenSubsonicExtensionsSupport?

    init(performanceMonitor: ThreadPerformanceMonitor, eventLogger: EventLogger, persistentStorage: PersistentStorage) {
        self.performanceMonitor = performanceMonitor
        self.eventLogger = eventLogger
        self.persistentStorage = persistentStorage
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
    
    private func getCachedServerApiVersionOrRequestIt(providedCredentials: LoginCredentials? = nil) -> Promise<SubsonicVersion> {
        if let serverVersion = serverApiVersion {
            return Promise<SubsonicVersion>.value(serverVersion)
        } else {
            return self.requestServerApiVersionPromise(providedCredentials: providedCredentials)
        }
    }
    
    private func determineApiVersionToUse(providedCredentials: LoginCredentials? = nil) -> Promise<SubsonicVersion> {
        return Promise<SubsonicVersion> { clientVersionSeal in
            if let clientApiVersion = self.clientApiVersion {
                return clientVersionSeal.fulfill(clientApiVersion)
            }
            firstly {
                self.getCachedServerApiVersionOrRequestIt(providedCredentials: providedCredentials)
            }.done { serverVersion in
                os_log("Server API version is '%s'", log: self.log, type: .info, serverVersion.description)
                if self.authType == .legacy {
                    self.clientApiVersion = Self.defaultClientApiVersionPreToken
                    os_log("Client API legacy login", log: self.log, type: .info)
                } else {
                    self.clientApiVersion = Self.defaultClientApiVersionWithToken
                    os_log("Client API version is '%s'", log: self.log, type: .info, self.clientApiVersion!.description)
                }
                return clientVersionSeal.fulfill(self.clientApiVersion!)
            }.catch { error in
                return clientVersionSeal.reject(error)
            }
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
    
    func isAuthenticationValid(credentials: LoginCredentials) -> Promise<Void> {
        return firstly {
            self.determineApiVersionToUse(providedCredentials: credentials)
        }.then { version -> Promise<APIDataResponse> in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "ping", credentials: credentials)
            return self.request(url: try self.createUrl(from: urlComp))
        }.then { response -> Promise<Void> in
            let parserDelegate = SsPingParserDelegate(performanceMonitor: self.performanceMonitor)
            let parser = XMLParser(data: response.data)
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
            return Promise<URL> { seal in
                let apiID = playable.asPodcastEpisode?.streamId ?? playable.id
                // If transcoding is selected for caching the subsonic API method 'stream' must be used
                // For raw format subsonic API method 'download' can be used
                switch self.persistentStorage.settings.cacheTranscodingFormatPreference {
                case .mp3:
                    var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "stream", id: apiID)
                    urlComp.addQueryItem(name: "format", value: "mp3")
                    let url = try self.createUrl(from: urlComp)
                    seal.fulfill(url)
                case .serverConfig:
                    var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "stream", id: apiID)
                    // let the server decide which format to use
                    let url = try self.createUrl(from: urlComp)
                    seal.fulfill(url)
                case .raw:
                    let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "download", id: apiID)
                    let url = try self.createUrl(from: urlComp)
                    seal.fulfill(url)
                }
            }
        }
    }
    
    func generateUrl(forStreamingPlayable playable: AbstractPlayable, maxBitrate: StreamingMaxBitratePreference) -> Promise<URL> {
        return firstly {
            self.determineApiVersionToUse()
        }.then { version -> Promise<URL> in
            return Promise<URL> { seal in
                let apiID = playable.asPodcastEpisode?.streamId ?? playable.id
                var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "stream", id: apiID)
                switch self.persistentStorage.settings.streamingFormatPreference {
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
                let url = try self.createUrl(from: urlComp)
                seal.fulfill(url)
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
    
    func determTranscodingInfo(url: URL) -> TranscodingInfo {
        var info = TranscodingInfo()
        let urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let queryItems = urlComp?.queryItems {
            for queryItem in queryItems {
                if queryItem.name == "format",
                   let formatRaw = queryItem.value,
                   let format = CacheTranscodingFormatPreference.createFromFileFormatString(formatRaw) {
                    info.format = format
                } else if queryItem.name == "maxBitRate",
                          let bitrateRawString = queryItem.value,
                          let bitrateRawInt = Int(bitrateRawString),
                          let bitrate = StreamingMaxBitratePreference(rawValue: bitrateRawInt) {
                    info.bitrate = bitrate
                }
            }
        }
        return info
    }
    
    private func requestServerApiVersionPromise(providedCredentials: LoginCredentials? = nil) -> Promise<SubsonicVersion> {
        return firstly {
            Promise<URL> { seal in
                guard let urlComp = try? createAuthApiUrlComponent(version: authTypeBasedClientApiVersion, forAction: "ping", credentials: providedCredentials) else {
                    throw BackendError.invalidUrl
                }
                return seal.fulfill(try createUrl(from: urlComp))
            }
        }.then { url in
            self.request(url: url)
        }.then { response in
            return Promise<SubsonicVersion> { seal in
                let delegate = SsPingParserDelegate(performanceMonitor: self.performanceMonitor)
                let parser = XMLParser(data: response.data)
                parser.delegate = delegate
                parser.parse()
                guard let serverApiVersionString = delegate.serverApiVersion else { throw XMLParserResponseError(cleansedURL: response.url?.asCleansedURL(cleanser: self), data: response.data) }
                guard let serverApiVersion = SubsonicVersion(serverApiVersionString) else {
                    os_log("The server API version '%s' could not be parsed to 'SubsonicVersion'", log: self.log, type: .info, serverApiVersionString)
                    throw XMLParserResponseError(cleansedURL: response.url?.asCleansedURL(cleanser: self), data: response.data)
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
    
    private func requestOpenSubsonicExtensions() -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getOpenSubsonicExtensions")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func isOpenSubsonicExtensionSupported(extension oSsExtention: OpenSubsonicExtension) -> Guarantee<Bool> {
        // the member variable will be set after the server has been requested
        // here we already asked the server for its support and use the cached response
        if let oSsExtSupport = self.openSubsonicExtensionsSupport {
            if oSsExtSupport.isSupported == false {
                os_log("No OpenSubsonicExtensions supported (%s)!", log: self.log, type: .info, oSsExtention.rawValue)
                return Guarantee.value(false)
            } else if let response = oSsExtSupport.extensionResponse {
                let isExtensionSupported = response.supportedExtensions.contains(oSsExtention.rawValue)
                os_log("OpenSubsonicExtension %s supported: %s", log: self.log, type: .info, oSsExtention.rawValue, isExtensionSupported ? "yes" : "no")
                return Guarantee.value(isExtensionSupported)
            } else {
                os_log("No OpenSubsonicExtensions supported (%s)!", log: self.log, type: .info, oSsExtention.rawValue)
                return Guarantee.value(false)
            }
        } else {
            // we haven't yet requested the server for OpenSubsonicExtensions support
            return Guarantee<Bool> { seal in
                firstly {
                    self.requestOpenSubsonicExtensions()
                }.done { response in
                    DispatchQueue.global().async {
                        let parserDelegate = SsOpenSubsonicExtensionsParserDelegate(performanceMonitor: self.performanceMonitor)
                        
                        let parser = XMLParser(data: response.data)
                        parser.delegate = parserDelegate
                        let success = parser.parse()
                        guard success else {
                            os_log("No OpenSubsonicExtensions supported (%s)!", log: self.log, type: .info, oSsExtention.rawValue)
                            seal(false)
                            return
                        }
                        
                        self.openSubsonicExtensionsSupport = OpenSubsonicExtensionsSupport()
                        self.openSubsonicExtensionsSupport?.isSupported = !parserDelegate.openSubsonicExtensionsResponse.supportedExtensions.isEmpty
                        self.openSubsonicExtensionsSupport?.extensionResponse = parserDelegate.openSubsonicExtensionsResponse
                        
                        if let availableExtensions = self.openSubsonicExtensionsSupport?.extensionResponse?.supportedExtensions {
                            let availableExtensionsStr = availableExtensions.reduce("", { $0 == "" ? $1 : $0 + ", " + $1 })
                            os_log("OpenSubsonicExtensions supported: %s", log: self.log, type: .info, availableExtensionsStr)
                            let isSpecificExtensionSupported = availableExtensions.contains(oSsExtention.rawValue)
                            os_log("OpenSubsonicExtensions %s supported: %s", log: self.log, type: .info, oSsExtention.rawValue, isSpecificExtensionSupported ? "yes" : "no")
                            seal(isSpecificExtensionSupported)
                        } else {
                            os_log("No OpenSubsonicExtension supported (%s)!", log: self.log, type: .info, oSsExtention.rawValue)
                            seal(false)
                        }
                    }
                }.catch { error in
                    os_log("No OpenSubsonicExtension supported (%s)!", log: self.log, type: .info, oSsExtention.rawValue)
                    self.openSubsonicExtensionsSupport = OpenSubsonicExtensionsSupport()
                    self.openSubsonicExtensionsSupport?.isSupported = false
                    seal(false)
                }
            }
        }
    }
    
    /// this requires that the server supports OpenSubsonicExtension "songLyrics"
    func requestLyricsBySongId(id: String) -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getLyricsBySongId", id: id)
            return try self.createUrl(from: urlComp)
        }
    }

    func requestGenres() -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getGenres")
            return try self.createUrl(from: urlComp)
        }
    }

    func requestArtists() -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getArtists")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestArtist(id: String) -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getArtist", id: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestAlbum(id: String) -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getAlbum", id: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSongInfo(id: String) -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getSong", id: id)
            return try self.createUrl(from: urlComp)
        }
    }

    func requestFavoriteElements() -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getStarred2")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestNewestAlbums(offset: Int, count: Int) -> Promise<APIDataResponse> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getAlbumList2")
            urlComp.addQueryItem(name: "type", value: "newest")
            urlComp.addQueryItem(name: "size", value: count)
            urlComp.addQueryItem(name: "offset", value: offset)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestRecentAlbums(offset: Int, count: Int) -> Promise<APIDataResponse> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getAlbumList2")
            urlComp.addQueryItem(name: "type", value: "recent")
            urlComp.addQueryItem(name: "size", value: count)
            urlComp.addQueryItem(name: "offset", value: offset)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestAlbums(offset: Int, count: Int) -> Promise<APIDataResponse> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getAlbumList2")
            urlComp.addQueryItem(name: "type", value: "alphabeticalByName")
            urlComp.addQueryItem(name: "size", value: count)
            urlComp.addQueryItem(name: "offset", value: offset)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestRandomSongs(count: Int) -> Promise<APIDataResponse> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getRandomSongs")
            urlComp.addQueryItem(name: "size", value: count)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPodcastEpisodeDelete(id: String) -> Promise<APIDataResponse>  {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "deletePodcastEpisode", id: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSearchArtists(searchText: String) -> Promise<APIDataResponse> {
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
    
    
    func requestSearchAlbums(searchText: String) -> Promise<APIDataResponse> {
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
    
    func requestSearchSongs(searchText: String) -> Promise<APIDataResponse> {
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
    
    func requestPlaylists() -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getPlaylists")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistSongs(id: String) -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getPlaylist", id: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistCreate(name: String) -> Promise<APIDataResponse> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "createPlaylist")
            urlComp.addQueryItem(name: "name", value: name)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPlaylistDelete(id: String) -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "deletePlaylist", id: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
        let errorParser = SsXmlParser(performanceMonitor: self.performanceMonitor)
        let parser = XMLParser(data: response.data)
        parser.delegate = errorParser
        parser.parse()
        guard let subsonicError = errorParser.error else { return nil }
        return ResponseError.createFromSubsonicError(cleansedURL: response.url?.asCleansedURL(cleanser: self), error: subsonicError, data: response.data)
    }

    func requestPlaylistUpdate(id: String, name: String, songIndicesToRemove: [Int], songIdsToAdd: [String]) -> Promise<APIDataResponse> {
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
    
    func requestPodcasts() -> Promise<APIDataResponse> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getPodcasts")
            urlComp.addQueryItem(name: "includeEpisodes", value: "false")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestPodcastEpisodes(id: String) -> Promise<APIDataResponse> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getPodcasts", id: id)
            urlComp.addQueryItem(name: "includeEpisodes", value: "true")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestNewestPodcasts() -> Promise<APIDataResponse> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getNewestPodcasts")
            urlComp.addQueryItem(name: "count", value: 20)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestMusicFolders() -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getMusicFolders")
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestIndexes(musicFolderId: String) -> Promise<APIDataResponse> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getIndexes")
            urlComp.addQueryItem(name: "musicFolderId", value: musicFolderId)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestMusicDirectory(id: String) -> Promise<APIDataResponse> {
        return request { version in
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "getMusicDirectory", id: id)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestScrobble(id: String, submission: Bool, date: Date? = nil) -> Promise<APIDataResponse> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "scrobble", id: id)
            if let date = date {
                urlComp.addQueryItem(name: "date", value: Int(date.timeIntervalSince1970))
            }
            urlComp.addQueryItem(name: "submission", value: submission.description)
            return try self.createUrl(from: urlComp)
        }
    }

    /// Only songs, albums, artists are supported by the subsonic API
    func requestRating(id: String, rating: Int) -> Promise<APIDataResponse> {
        return request { version in
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: "setRating", id: id)
            urlComp.addQueryItem(name: "rating", value: rating)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSetFavorite(songId: String, isFavorite: Bool) -> Promise<APIDataResponse> {
        return request { version in
            let apiFavoriteAction = isFavorite ? "star" : "unstar"
            let urlComp = try self.createAuthApiUrlComponent(version: version, forAction: apiFavoriteAction, id: songId)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSetFavorite(albumId: String, isFavorite: Bool) -> Promise<APIDataResponse> {
        return request { version in
            let apiFavoriteAction = isFavorite ? "star" : "unstar"
            var urlComp = try self.createAuthApiUrlComponent(version: version, forAction: apiFavoriteAction)
            urlComp.addQueryItem(name: "albumId", value: albumId)
            return try self.createUrl(from: urlComp)
        }
    }
    
    func requestSetFavorite(artistId: String, isFavorite: Bool) -> Promise<APIDataResponse> {
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
    
    private func request(urlCreation: @escaping (_: SubsonicVersion) throws -> URL) -> Promise<APIDataResponse> {
        return firstly {
            self.determineApiVersionToUse()
        }.then { version in
            Promise<URL> { seal in seal.fulfill(try urlCreation(version)) }
        }.then { url in
            self.request(url: url)
        }
    }
    
    private func request(url: URL) -> Promise<APIDataResponse> {
        return firstly {
            AF.request(url, method: .get).validate().responseData()
        }.then { data, response in
            Promise<APIDataResponse>.value(APIDataResponse(data: data, url: url, meta: response))
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

