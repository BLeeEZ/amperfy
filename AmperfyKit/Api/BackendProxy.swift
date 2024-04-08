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
import PromiseKit

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
        case .requestStatusError(message: let message):
            ret = "Requesting server URL finished with status response error code '\(message)'!"
        case .downloadError(message: let message):
            ret = message
        }
        return ret
    }
}

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
        case .incorrectServerBehavior(message: let message):
            ret = "Server didn't behave as expected: \(message)"
        }
        return ret
    }
}

public class ResponseError: LocalizedError {
    public var statusCode: Int = 0
    public var message: String
    public var cleansedURL: CleansedURL?
    public var data: Data?
    
    init(statusCode: Int = 0, message: String, cleansedURL: CleansedURL?, data: Data?) {
        self.statusCode = statusCode
        self.message = message
        self.cleansedURL = cleansedURL
        self.data = data
    }
    
    public var errorDescription: String? {
        return "API error \(statusCode): \(message)"
    }
    
    public func asInfo(topic: String) -> ResponseErrorInfo {
        var dataString: String?
        if let data = data {
            dataString = String(decoding: data, as: UTF8.self)
        }
        return ResponseErrorInfo(topic: topic, statusCode: statusCode, message: message, cleansedURL: cleansedURL?.description ?? "", data: dataString)
    }
}

public struct ResponseErrorInfo: Encodable {
    public var topic: String
    public var statusCode: Int
    public var message: String
    public var cleansedURL: String
    public var data: String?
}

public class XMLParserResponseError: ResponseError {
    init(cleansedURL: CleansedURL?, data: Data?) {
        super.init(message: "XML response could not be parsed.", cleansedURL: cleansedURL, data: data)
    }
    
    public override var errorDescription: String? {
        return "\(message)"
    }
}

public class ResourceNotAvailableResponseError: ResponseError {
}


public class BackendProxy {
    
    private let log = OSLog(subsystem: "Amperfy", category: "BackendProxy")
    private let networkMonitor: NetworkMonitorFacade
    private let performanceMonitor: ThreadPerformanceMonitor
    private let eventLogger: EventLogger
    private let persistentStorage: PersistentStorage
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
        return AmpacheApi(ampacheXmlServerApi: AmpacheXmlServerApi(performanceMonitor: self.performanceMonitor, eventLogger: eventLogger, persistentStorage: persistentStorage), networkMonitor: networkMonitor, performanceMonitor: performanceMonitor, eventLogger: eventLogger)
    }()
    private lazy var subsonicApi: BackendApi = {
        let api = SubsonicApi(subsonicServerApi: SubsonicServerApi(performanceMonitor: self.performanceMonitor, eventLogger: eventLogger, persistentStorage: persistentStorage), networkMonitor: networkMonitor, performanceMonitor: performanceMonitor, eventLogger: eventLogger)
        api.authType = .autoDetect
        return api
    }()
    private lazy var subsonicLegacyApi: BackendApi = {
        let api = SubsonicApi(subsonicServerApi: SubsonicServerApi(performanceMonitor: self.performanceMonitor, eventLogger: eventLogger, persistentStorage: persistentStorage), networkMonitor: networkMonitor, performanceMonitor: performanceMonitor, eventLogger: eventLogger)
        api.authType = .legacy
        return api
    }()
    
    init(networkMonitor: NetworkMonitorFacade, performanceMonitor: ThreadPerformanceMonitor, eventLogger: EventLogger, persistentStorage: PersistentStorage) {
        self.networkMonitor = networkMonitor
        self.performanceMonitor = performanceMonitor
        self.eventLogger = eventLogger
        self.persistentStorage = persistentStorage
    }

    public func login(apiType: BackenApiType, credentials: LoginCredentials) -> Promise<BackenApiType> {
        return firstly {
            checkServerReachablity(credentials: credentials)
        }.then {
            return Promise<BackenApiType> { seal in
                var apiFound = BackenApiType.notDetected
                firstly { () -> Guarantee<Void> in
                    if apiFound == .notDetected && (apiType == .notDetected || apiType == .ampache) {
                        return Guarantee<Void> { apiSeal in
                            firstly {
                                self.ampacheApi.isAuthenticationValid(credentials: credentials)
                            }.done {
                                apiFound = .ampache
                            }.catch { error in
                                // error -> ignore this api and check the others
                            }.finally {
                                apiSeal(Void())
                            }
                        }
                    } else {
                        return Guarantee.value
                    }
                }.then { () -> Guarantee<Void> in
                    if apiFound == .notDetected && (apiType == .notDetected || apiType == .subsonic) {
                        return Guarantee<Void> { apiSeal in
                            firstly {
                                self.subsonicApi.isAuthenticationValid(credentials: credentials)
                            }.done {
                                apiFound = .subsonic
                            }.catch { error in
                                // error -> ignore this api and check the others
                            }.finally {
                                apiSeal(Void())
                            }
                        }
                    } else {
                        return Guarantee.value
                    }
                }.then { () -> Guarantee<Void> in
                    if apiFound == .notDetected && (apiType == .notDetected || apiType == .subsonic_legacy) {
                        return Guarantee<Void> { apiSeal in
                            firstly {
                                self.subsonicLegacyApi.isAuthenticationValid(credentials: credentials)
                            }.done {
                                apiFound = .subsonic_legacy
                            }.catch { error in
                                // error -> ignore this api and check the others
                            }.finally {
                                apiSeal(Void())
                            }
                        }
                    } else {
                        return Guarantee.value
                    }
                }.done {
                    if apiFound == .notDetected {
                        seal.reject(AuthenticationError.notAbleToLogin)
                    } else {
                        seal.fulfill(apiFound)
                    }
                }
            }
        }
    }
    
    private func checkServerReachablity(credentials: LoginCredentials) -> Promise<Void> {
        return Promise<Void> { seal in
            guard let serverUrl = URL(string: credentials.serverUrl) else {
                throw AuthenticationError.invalidUrl
            }
            
            let sessionConfig = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfig)
            let request = URLRequest(url: serverUrl)
            let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
                if let error = error {
                    seal.reject(AuthenticationError.downloadError(message: error.localizedDescription))
                } else {
                    if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                        if statusCode >= 400,
                        // ignore 401 Unauthorized (RFC 7235) status code
                        // -> Can occure if root website requires http basic authentication,
                        //    but the REST API endpoints are reachable without http basic authentication
                        statusCode != 401 {
                            seal.reject(AuthenticationError.requestStatusError(message: "\(statusCode)"))
                        } else {
                            os_log("Server url is reachable. Status code: %d", log: self.log, type: .info, statusCode)
                            seal.fulfill(Void())
                        }
                    }
                }
            }
            task.resume()
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
    
    public var isStreamingTranscodingActive: Bool {
        return activeApi.isStreamingTranscodingActive
    }
    
    public func provideCredentials(credentials: LoginCredentials) {
        activeApi.provideCredentials(credentials: credentials)
    }

    public func isAuthenticationValid(credentials: LoginCredentials) -> Promise<Void> {
        return activeApi.isAuthenticationValid(credentials: credentials)
    }
    
    public func generateUrl(forDownloadingPlayable playable: AbstractPlayable) -> Promise<URL> {
        return activeApi.generateUrl(forDownloadingPlayable: playable)
    }
    
    public func generateUrl(forStreamingPlayable playable: AbstractPlayable, maxBitrate: StreamingMaxBitratePreference) -> Promise<URL> {
        return activeApi.generateUrl(forStreamingPlayable: playable, maxBitrate: maxBitrate)
    }
    
    public func generateUrl(forArtwork artwork: Artwork) -> Promise<URL> {
        return activeApi.generateUrl(forArtwork: artwork)
    }
    
    public func determTranscodingInfo(url: URL) -> TranscodingInfo {
        return activeApi.determTranscodingInfo(url: url)
    }
    
    public func checkForErrorResponse(response: APIDataResponse) -> ResponseError? {
        return activeApi.checkForErrorResponse(response: response)
    }
    
    public func createLibrarySyncer(storage: PersistentStorage) -> LibrarySyncer {
        return activeApi.createLibrarySyncer(storage: storage)
    }

    public func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate {
        return activeApi.createArtworkArtworkDownloadDelegate()
    }
    
    public func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        return activeApi.extractArtworkInfoFromURL(urlString: urlString)
    }
    
    public func cleanse(url: URL) -> CleansedURL {
        return activeApi.cleanse(url: url)
    }
    
}
