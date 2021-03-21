import Foundation
import os.log

enum BackenApiType: Int {
    case notDetected = 0
    case ampache = 1
    case subsonic = 2
    
    var description : String {
        switch self {
        case .notDetected: return "NotDetected"
        case .ampache: return "Ampache"
        case .subsonic: return "Subsonic"
        }
    }
}

struct AuthenticationError: Error {
    enum ErrorKind {
        case notAbleToLogin
        case invalidUrl
        case requestStatusError
        case downloadError
    }
    
    var message: String = ""
    let kind: ErrorKind
}

struct ResponseError {
    var statusCode: Int = 0
    var message: String = ""
}

class BackendProxy {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "BackendProxy")
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
        }
    }
 
    private lazy var ampacheApi: BackendApi = {
        return AmpacheApi(ampacheXmlServerApi: AmpacheXmlServerApi())
    }()
    private lazy var subsonicApi: BackendApi = {
        return SubsonicApi(subsonicServerApi: SubsonicServerApi())
    }()

    func login(credentials: LoginCredentials) throws -> BackenApiType {
        try checkServerReachablity(credentials: credentials)
        ampacheApi.authenticate(credentials: credentials)
        if ampacheApi.isAuthenticated() {
            selectedApi = .ampache
            return .ampache
        }
        subsonicApi.authenticate(credentials: credentials)
        if subsonicApi.isAuthenticated() {
            selectedApi = .subsonic
            return .subsonic
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
                    if statusCode > 400 {
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
    
    func provideCredentials(credentials: LoginCredentials) {
        activeApi.provideCredentials(credentials: credentials)
    }
    
    func authenticate(credentials: LoginCredentials) {
        activeApi.authenticate(credentials: credentials)
    }
    
    func isAuthenticated() -> Bool {
        return activeApi.isAuthenticated()
    }
    
    func generateUrl(forDownloadingSong song: Song) -> URL? {
        return activeApi.generateUrl(forDownloadingSong: song)
    }
    
    func generateUrl(forStreamingSong song: Song) -> URL? {
        return activeApi.generateUrl(forStreamingSong: song)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        return activeApi.generateUrl(forArtwork: artwork)
    }
    
    func checkForErrorResponse(inData data: Data) -> ResponseError? {
        return activeApi.checkForErrorResponse(inData: data)
    }
    
    func createLibrarySyncer() -> LibrarySyncer {
        return activeApi.createLibrarySyncer()
    }

    func createLibraryBackgroundSyncer() -> BackgroundLibrarySyncer {
        return activeApi.createLibraryBackgroundSyncer()
    }

    func createArtworkBackgroundSyncer() -> BackgroundLibrarySyncer {
        return activeApi.createArtworkBackgroundSyncer()
    }
    
}
