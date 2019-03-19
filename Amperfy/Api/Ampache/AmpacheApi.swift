import Foundation

class AmpacheApi: BackendApi {

    private let ampacheXmlServerApi: AmpacheXmlServerApi

    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
    }

    var defaultArtworkUrl: String {
        return ampacheXmlServerApi.defaultArtworkUrl
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

    func updateUrlToken(url: inout String) {
        ampacheXmlServerApi.updateUrlToken(url: &url)
    }

    func createLibrarySyncer() -> LibrarySyncer {
        return AmpacheLibrarySyncer(ampacheXmlServerApi: ampacheXmlServerApi)
    }

}
