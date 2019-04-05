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

enum AuthenticationError: Error {
    case notAbleToLogin
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
        throw AuthenticationError.notAbleToLogin
    }

}
    
extension BackendProxy: BackendApi {
    
    func provideCredentials(credentials: LoginCredentials) {
        activeApi.provideCredentials(credentials: credentials)
    }
    
    func authenticate(credentials: LoginCredentials) {
        activeApi.authenticate(credentials: credentials)
    }
    
    func isAuthenticated() -> Bool {
        return activeApi.isAuthenticated()
    }
    
    func generateUrl(forSong song: Song) -> URL? {
        return activeApi.generateUrl(forSong: song)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        return activeApi.generateUrl(forArtwork: artwork)
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
