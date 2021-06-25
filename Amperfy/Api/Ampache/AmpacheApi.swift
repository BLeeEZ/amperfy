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
    
    public var isPodcastSupported: Bool {
        return ampacheXmlServerApi.isPodcastSupported
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
    
    func isAuthenticationValid(credentials: LoginCredentials) -> Bool {
        return ampacheXmlServerApi.isAuthenticationValid(credentials: credentials)
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

    func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate {
        return AmpacheArtworkDownloadDelegate(ampacheXmlServerApi: ampacheXmlServerApi)
    }
    
    func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? {
        AmpacheXmlServerApi.extractArtworkInfoFromURL(urlString: urlString)
    }

}
