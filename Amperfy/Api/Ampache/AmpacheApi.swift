import Foundation

class AmpacheApi: BackendApi {

    private let ampacheXmlServerApi: AmpacheXmlServerApi

    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
    }
    
    public var clientApiVersion: String {
        return ampacheXmlServerApi.clientApiVersion
    }
    
    public var serverApiVersion: String {
        return ampacheXmlServerApi.serverApiVersion ?? "-"
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

    func generateUrl(forDownloadingSong song: Song) -> URL? {
        return ampacheXmlServerApi.generateUrl(forDownloadingSong: song)
    }

    func generateUrl(forStreamingSong song: Song) -> URL? {
        return ampacheXmlServerApi.generateUrl(forStreamingSong: song)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        return ampacheXmlServerApi.generateUrl(forArtwork: artwork)
    }
    
    func checkForErrorResponse(inData data: Data) -> ResponseError? {
        return ampacheXmlServerApi.checkForErrorResponse(inData: data)
    }

    func createLibrarySyncer() -> LibrarySyncer {
        return AmpacheLibrarySyncer(ampacheXmlServerApi: ampacheXmlServerApi)
    }    
    
    func createLibraryBackgroundSyncer() -> BackgroundLibrarySyncer {
        return AmpacheLibraryBackgroundSyncer(ampacheXmlServerApi: ampacheXmlServerApi)
    }
    
    func createLibraryVersionBackgroundResyncer() -> BackgroundLibraryVersionResyncer {
        return AmpacheLibraryVersionBackgroundResyncer(ampacheXmlServerApi: ampacheXmlServerApi)
    }

    func createArtworkBackgroundSyncer() -> BackgroundLibrarySyncer {
        return AmpacheArtworkSyncer(ampacheXmlServerApi: ampacheXmlServerApi)
    }

}
