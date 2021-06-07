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

    func provideCredentials(credentials: LoginCredentials) {
        subsonicServerApi.provideCredentials(credentials: credentials)
    }

    func authenticate(credentials: LoginCredentials) {
        subsonicServerApi.authenticate(credentials: credentials)
    }

    func isAuthenticated() -> Bool {
        return subsonicServerApi.isAuthenticated()
    }

    func generateUrl(forDownloadingSong song: Song) -> URL? {
        return subsonicServerApi.generateUrl(forDownloadingSong: song)
    }

    func generateUrl(forStreamingSong song: Song) -> URL? {
        return subsonicServerApi.generateUrl(forStreamingSong: song)
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

    func createLibraryBackgroundSyncer() -> BackgroundLibrarySyncer {
        return SubsonicLibraryBackgroundSyncer(subsonicServerApi: subsonicServerApi)
    }
    
    func createLibraryVersionBackgroundResyncer() -> BackgroundLibraryVersionResyncer {
        return SubsonicLibraryVersionBackgroundResyncer(subsonicServerApi: subsonicServerApi)
    }

    func createArtworkBackgroundSyncer() -> BackgroundLibrarySyncer {
        return SubsonicArtworkBackgroundSyncer(subsonicServerApi: subsonicServerApi)
    }
    
    func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        return SubsonicServerApi.extractArtworkInfoFromURL(urlString: urlString)
    }

}
