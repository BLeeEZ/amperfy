import Foundation
import os.log

class SubsonicApi: BackendApi {
        
    private let subsonicServerApi: SubsonicServerApi

    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }
    
    public var clientApiVersion: String {
        return subsonicServerApi.clientApiVersion.description
    }
    
    public var serverApiVersion: String {
        return subsonicServerApi.serverApiVersion?.description ?? "-"
    }
    
    public var isPodcastSupported: Bool {
        return subsonicServerApi.isPodcastSupported
    }

    func provideCredentials(credentials: LoginCredentials) {
        subsonicServerApi.provideCredentials(credentials: credentials)
    }

    func authenticate(credentials: LoginCredentials) {
        subsonicServerApi.authenticate(credentials: credentials)
    }

    func isAuthenticated() -> Bool {
        return subsonicServerApi.isAuthenticated()
    }
    
    func isAuthenticationValid(credentials: LoginCredentials) -> Bool {
        return subsonicServerApi.isAuthenticationValid(credentials: credentials)
    }

    func generateUrl(forDownloadingPlayable playable: AbstractPlayable) -> URL? {
        return subsonicServerApi.generateUrl(forDownloadingPlayable: playable)
    }

    func generateUrl(forStreamingPlayable playable: AbstractPlayable) -> URL? {
        return subsonicServerApi.generateUrl(forStreamingPlayable: playable)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        return subsonicServerApi.generateUrl(forArtwork: artwork)
    }

    func checkForErrorResponse(inData data: Data) -> ResponseError? {
        return subsonicServerApi.checkForErrorResponse(inData: data)
    }
    
    func createLibrarySyncer() -> LibrarySyncer {
        return SubsonicLibrarySyncer(subsonicServerApi: subsonicServerApi)
    }
    
    func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate {
        return SubsonicArtworkDownloadDelegate(subsonicServerApi: subsonicServerApi)
    }
    
    func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        return SubsonicServerApi.extractArtworkInfoFromURL(urlString: urlString)
    }

}
