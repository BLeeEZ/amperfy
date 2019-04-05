import Foundation

class AmpacheApi: BackendApi {

    private let ampacheXmlServerApi: AmpacheXmlServerApi

    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
    }

    func provideCredentials(credentials: LoginCredentials) {
        ampacheXmlServerApi.provideCredentials(credentials: credentials)
    }

    func authenticate(credentials: LoginCredentials) {
        ampacheXmlServerApi.authenticate(credentials: credentials)
    }

    func isAuthenticated() -> Bool {
        return ampacheXmlServerApi.isAuthenticated()
    }

    func generateUrl(forSong song: Song) -> URL? {
        return ampacheXmlServerApi.generateUrl(forSong: song)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        return ampacheXmlServerApi.generateUrl(forArtwork: artwork)
    }

    func createLibrarySyncer() -> LibrarySyncer {
        return AmpacheLibrarySyncer(ampacheXmlServerApi: ampacheXmlServerApi)
    }    
    
    func createLibraryBackgroundSyncer() -> BackgroundLibrarySyncer {
        return AmpacheLibraryBackgroundSyncer(ampacheXmlServerApi: ampacheXmlServerApi)
    }

    func createArtworkBackgroundSyncer() -> BackgroundLibrarySyncer {
        return AmpacheArtworkSyncer(ampacheXmlServerApi: ampacheXmlServerApi)
    }

}
