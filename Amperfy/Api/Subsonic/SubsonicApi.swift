import Foundation
import os.log

class SubsonicApi: BackendApi {
        
    private let subsonicServerApi: SubsonicServerApi

    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
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

    func generateUrl(forSong song: Song) -> URL? {
        return subsonicServerApi.generateUrl(forSong: song)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        return subsonicServerApi.generateUrl(forArtwork: artwork)
    }

    func createLibrarySyncer() -> LibrarySyncer {
        return SubsonicLibrarySyncer(subsonicServerApi: subsonicServerApi)
    }

    func createLibraryBackgroundSyncer() -> BackgroundLibrarySyncer {
        return SubsonicLibraryBackgroundSyncer(subsonicServerApi: subsonicServerApi)
    }

    func createArtworkBackgroundSyncer() -> BackgroundLibrarySyncer {
        return SubsonicArtworkBackgroundSyncer(subsonicServerApi: subsonicServerApi)
    }

}
