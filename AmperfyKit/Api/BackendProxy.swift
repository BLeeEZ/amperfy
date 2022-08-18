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

public enum BackenApiType: Int {
    case notDetected = 0
    case ampache = 1
    case subsonic = 2
    case subsonic_legacy = 3

    public var description : String {
        switch self {
        case .notDetected: return "NotDetected"
        case .ampache: return "Ampache"
        case .subsonic: return "Subsonic"
        case .subsonic_legacy: return "Subsonic (legacy login)"
        }
    }
    
    public var selectorDescription : String {
        switch self {
        case .notDetected: return "Auto-Detect"
        case .ampache: return "Ampache"
        case .subsonic: return "Subsonic"
        case .subsonic_legacy: return "Subsonic (legacy login)"
        }
    }
}

public struct AuthenticationError: Error {
    public enum ErrorKind {
        case notAbleToLogin
        case invalidUrl
        case requestStatusError
        case downloadError
    }
    
    public var message: String = ""
    public let kind: ErrorKind
}

public struct ResponseError {
    var statusCode: Int = 0
    var message: String = ""
}

public class BackendProxy {
    
    private let log = OSLog(subsystem: "Amperfy", category: "BackendProxy")
    private let eventLogger: EventLogger
    private var activeApiType = BackenApiType.ampache
    public var selectedApi: BackenApiType {
        get {
            return activeApiType
        }
        set {
            os_log("%s is active backend api", log: self.log, type: .info, newValue.description)
            activeApiType = newValue
        }
    }
    
    private var activeApi: BackendApi {
        switch activeApiType {
        case .notDetected:
            return ampacheApi
        case .ampache:
            return ampacheApi
        case .subsonic:
            return subsonicApi
        case .subsonic_legacy:
            return subsonicLegacyApi
        }
    }
 
    private lazy var ampacheApi: BackendApi = {
        return AmpacheApi(ampacheXmlServerApi: AmpacheXmlServerApi(eventLogger: eventLogger))
    }()
    private lazy var subsonicApi: BackendApi = {
        let api = SubsonicApi(subsonicServerApi: SubsonicServerApi(eventLogger: eventLogger))
        api.authType = .autoDetect
        return api
    }()
    private lazy var subsonicLegacyApi: BackendApi = {
        let api = SubsonicApi(subsonicServerApi: SubsonicServerApi(eventLogger: eventLogger))
        api.authType = .legacy
        return api
    }()
    
    init(eventLogger: EventLogger) {
        self.eventLogger = eventLogger
    }

    public func login(apiType: BackenApiType, credentials: LoginCredentials) throws -> BackenApiType {
        try checkServerReachablity(credentials: credentials)
        if apiType == .notDetected || apiType == .ampache {
            ampacheApi.authenticate(credentials: credentials)
            if ampacheApi.isAuthenticated() {
                selectedApi = .ampache
                return .ampache
            }
        }
        if apiType == .notDetected || apiType == .subsonic {
            subsonicApi.authenticate(credentials: credentials)
            if subsonicApi.isAuthenticated() {
                selectedApi = .subsonic
                return .subsonic
            }
        }
        if apiType == .notDetected || apiType == .subsonic_legacy {
            subsonicLegacyApi.authenticate(credentials: credentials)
            if subsonicLegacyApi.isAuthenticated() {
                selectedApi = .subsonic_legacy
                return .subsonic_legacy
            }
        }
        throw AuthenticationError(kind: .notAbleToLogin)
    }
    
    private func checkServerReachablity(credentials: LoginCredentials) throws {
        guard let serverUrl = URL(string: credentials.serverUrl) else {
            throw AuthenticationError(kind: .invalidUrl)
        }
            
        let group = DispatchGroup()
        group.enter()
        
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig)
        let request = URLRequest(url: serverUrl)
        var downloadError: AuthenticationError? = nil
        let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
            if let error = error {
                downloadError = AuthenticationError(message: error.localizedDescription, kind: .downloadError)
            } else {
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    if statusCode >= 400,
                       // ignore 401 Unauthorized (RFC 7235) status code
                       // -> Can occure if root website requires http basic authentication,
                       //    but the REST API endpoints are reachable without http basic authentication
                       statusCode != 401 {
                        downloadError = AuthenticationError(message: "\(statusCode)", kind: .requestStatusError)
                    } else {
                        os_log("Server url is reachable. Status code: %d", log: self.log, type: .info, statusCode)
                    }
                }
            }
            group.leave()
        }
        task.resume()
        group.wait()
        
        if let error = downloadError {
            throw error
        }
    }

}
    
extension BackendProxy: BackendApi {
  
    public var clientApiVersion: String {
        return activeApi.clientApiVersion
    }
    
    public var serverApiVersion: String {
        return activeApi.serverApiVersion
    }
    
    public var isPodcastSupported: Bool {
        return activeApi.isPodcastSupported
    }
    
    public func provideCredentials(credentials: LoginCredentials) {
        activeApi.provideCredentials(credentials: credentials)
    }
    
    public func authenticate(credentials: LoginCredentials) {
        activeApi.authenticate(credentials: credentials)
    }
    
    public func isAuthenticated() -> Bool {
        return activeApi.isAuthenticated()
    }
    
    public func isAuthenticationValid(credentials: LoginCredentials) -> Bool {
        return activeApi.isAuthenticationValid(credentials: credentials)
    }
    
    public func generateUrl(forDownloadingPlayable playable: AbstractPlayable) -> URL? {
        return activeApi.generateUrl(forDownloadingPlayable: playable)
    }
    
    public func generateUrl(forStreamingPlayable playable: AbstractPlayable) -> URL? {
        return activeApi.generateUrl(forStreamingPlayable: playable)
    }
    
    public func generateUrl(forArtwork artwork: Artwork) -> URL? {
        return activeApi.generateUrl(forArtwork: artwork)
    }
    
    public func checkForErrorResponse(inData data: Data) -> ResponseError? {
        return activeApi.checkForErrorResponse(inData: data)
    }
    
    public func createLibrarySyncer() -> LibrarySyncer {
        return activeApi.createLibrarySyncer()
    }

    public func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate {
        return activeApi.createArtworkArtworkDownloadDelegate()
    }
    
    public func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        return activeApi.extractArtworkInfoFromURL(urlString: urlString)
    }
    
}
