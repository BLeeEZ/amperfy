import Foundation
import os.log

protocol SubsonicUrlCreator {
    func getArtUrlString(forCoverArtId: String) -> String
}

class SubsonicServerApi {
    
    static let defaultClientApiVersionWithToken = SubsonicVersion(major: 1, minor: 13, patch: 0)
    static let defaultClientApiVersionPreToken = SubsonicVersion(major: 1, minor: 11, patch: 0)
    
    var serverApiVersion: SubsonicVersion?
    var clientApiVersion = defaultClientApiVersionWithToken
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "Subsonic")
    private let eventLogger: EventLogger
    private var credentials: LoginCredentials?
    private var isValidCredentials = false
    
    init(eventLogger: EventLogger) {
        self.eventLogger = eventLogger
    }

    private func generateAuthenticationToken(password: String, salt: String) -> String {
        // Calculate the authentication token as follows: token = md5(password + salt).
        // The md5() function takes a string and returns the 32-byte ASCII hexadecimal representation of the MD5 hash,
        // using lower case characters for the hex values. The '+' operator represents concatenation of the two strings.
        // Treat the strings as UTF-8 encoded when calculating the hash. Send the result as parameter
        let dataStr = "\(password)\(salt)"
        let authenticationToken = StringHasher.md5Hex(dataString: dataStr)
        return authenticationToken
    }
    
    private func determeClientApiVersionToUse() {
        if serverApiVersion == nil {
            serverApiVersion = requestServerApiVersion()
            guard let serverApiVersion = serverApiVersion else {
                clientApiVersion = SubsonicServerApi.defaultClientApiVersionWithToken
                return
            }
            os_log("The server API version is '%s'", log: log, type: .info, serverApiVersion.description)
            if serverApiVersion < SubsonicVersion.authenticationTokenRequiredServerApi {
                clientApiVersion = SubsonicServerApi.defaultClientApiVersionPreToken
            } else {
                clientApiVersion = SubsonicServerApi.defaultClientApiVersionWithToken
            }
            os_log("The client API version is '%s'", log: log, type: .info, clientApiVersion.description)
        }
    }
    
    private func createBasicApiUrlComponent(forAction: String) -> URLComponents? {
        guard let hostname = credentials?.serverUrl,
              var apiUrl = URL(string: hostname)
        else { return nil }
        
        apiUrl.appendPathComponent("rest")
        apiUrl.appendPathComponent("\(forAction).view")
    
        return URLComponents(url: apiUrl, resolvingAgainstBaseURL: false)
    }
    
    private func createAuthenticatedApiUrlComponent(forAction: String) -> URLComponents? {
        guard let username = credentials?.username,
              let password = credentials?.password,
              var urlComp = createBasicApiUrlComponent(forAction: forAction)
        else { return nil }
        
        determeClientApiVersionToUse()
        
        urlComp.addQueryItem(name: "u", value: username)
        urlComp.addQueryItem(name: "v", value: clientApiVersion.description)
        urlComp.addQueryItem(name: "c", value: AppDelegate.name)
        
        if clientApiVersion < SubsonicVersion.authenticationTokenRequiredServerApi {
            urlComp.addQueryItem(name: "p", value: password)
        } else {
            let salt = String.generateRandomString(ofLength: 16)
            let authenticationToken = generateAuthenticationToken(password: password, salt: salt)
            urlComp.addQueryItem(name: "t", value: authenticationToken)
            urlComp.addQueryItem(name: "s", value: salt)
        }

        return urlComp
    }
    
    private func createAuthenticatedApiUrlComponent(forAction: String, id: String) -> URLComponents? {
        guard var urlComp = createAuthenticatedApiUrlComponent(forAction: forAction) else { return nil }
        urlComp.addQueryItem(name: "id", value: id)
        return urlComp
    }
    
    func provideCredentials(credentials: LoginCredentials) {
        self.credentials = credentials
    }
    
    func authenticate(credentials: LoginCredentials) {
        self.credentials = credentials
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "ping"),
              let url = urlComp.url else {
            os_log("Subsonic server url invalid", log: log, type: .error)
            return
        }

        guard let parser = XMLParser(contentsOf: url) else {
            os_log("Couldn't load the ping response.", log: log, type: .error)
            isValidCredentials = false
            return
        }
        
        let curDelegate = SsPingParserDelegate()
        parser.delegate = curDelegate
        let success = parser.parse()
        
        if let serverApiVersion = curDelegate.serverApiVersion {
            os_log("The server API version is '%s'", log: log, type: .info, serverApiVersion)
        }
        
        if let error = parser.parserError {
            isValidCredentials = false
            os_log("Error during login parsing: %s", log: log, type: .error, error.localizedDescription)
            return
        }
        if success, curDelegate.isAuthValid {
            isValidCredentials = true
        } else {
            isValidCredentials = false
            os_log("Couldn't login.", log: log, type: .error)
        }
    }
    
    func isAuthenticated() -> Bool {
        return isValidCredentials
    }
    
    func generateUrl(forDownloadingSong song: Song) -> URL? {
        return createAuthenticatedApiUrlComponent(forAction: "download", id: song.id)?.url
    }
    
    func generateUrl(forStreamingSong song: Song) -> URL? {
        return createAuthenticatedApiUrlComponent(forAction: "stream", id: song.id)?.url
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        guard let urlComp = URLComponents(string: artwork.url),
           let queryItems = urlComp.queryItems,
           let coverArtQuery = queryItems.first(where: {$0.name == "id"}),
           let coverArtId = coverArtQuery.value
            else { return nil }
        return createAuthenticatedApiUrlComponent(forAction: "getCoverArt", id: coverArtId)?.url
    }
    
    func requestServerApiVersion() -> SubsonicVersion? {
        guard let urlComp = createBasicApiUrlComponent(forAction: "ping") else { return nil }
        let parserDelegate = SsPingParserDelegate()
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate, ignoreErrorResponse: true)
        guard let serverApiVersionString = parserDelegate.serverApiVersion else { return nil }
        guard let serverApiVersion = SubsonicVersion(serverApiVersionString) else {
            os_log("The server API version '%s' could not be parsed to 'SubsonicVersion'", log: log, type: .info, serverApiVersionString)
            return nil
        }
        return serverApiVersion
    }

    func requestGenres(parserDelegate: SsXmlParser) {
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "getGenres") else { return }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }

    func requestArtists(parserDelegate: SsXmlParser) {
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "getArtists") else { return }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }
    
    func requestArtist(parserDelegate: SsXmlParser, id: String) {
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "getArtist", id: id) else { return }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }
    
    func requestAlbum(parserDelegate: SsXmlParser, id: String) {
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "getAlbum", id: id) else { return }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }

    func requestSearchSongs(parserDelegate: SsXmlParser, searchText: String) {
        guard var urlComp = createAuthenticatedApiUrlComponent(forAction: "search3") else { return }
        urlComp.addQueryItem(name: "query", value: searchText)
        urlComp.addQueryItem(name: "artistCount", value: 0)
        urlComp.addQueryItem(name: "artistOffset", value: 0)
        urlComp.addQueryItem(name: "albumCount", value: 0)
        urlComp.addQueryItem(name: "albumOffset", value: 0)
        urlComp.addQueryItem(name: "songCount", value: 200)
        urlComp.addQueryItem(name: "songOffset", value: 0)
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylists(parserDelegate: SsXmlParser) {
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "getPlaylists") else { return }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }

    func requestPlaylistSongs(parserDelegate: SsXmlParser, id: String) {
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "getPlaylist", id: id) else { return }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }

    func requestPlaylistCreate(parserDelegate: SsXmlParser, playlist: Playlist) {
        guard var urlComp = createAuthenticatedApiUrlComponent(forAction: "createPlaylist") else { return }
        urlComp.addQueryItem(name: "name", value: playlist.name)
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylistDelete(parserDelegate: SsXmlParser, playlist: Playlist) {
        guard var urlComp = createAuthenticatedApiUrlComponent(forAction: "deletePlaylist") else { return }
        urlComp.addQueryItem(name: "id", value: playlist.id)
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }
    
    func checkForErrorResponse(inData data: Data) -> ResponseError? {
        let errorParser = SsXmlParser()
        let parser = XMLParser(data: data)
        parser.delegate = errorParser
        parser.parse()
        if let error = errorParser.error {
            eventLogger.report(error: error)
        }
        return errorParser.error
    }

    func requestPlaylistUpdate(parserDelegate: SsXmlParser, playlist: Playlist, songIndicesToRemove: [Int], songIdsToAdd: [String]) {
        guard var urlComp = createAuthenticatedApiUrlComponent(forAction: "updatePlaylist") else { return }
        urlComp.addQueryItem(name: "playlistId", value: playlist.id)
        urlComp.addQueryItem(name: "name", value: playlist.name)
        for songIndex in songIndicesToRemove {
            urlComp.addQueryItem(name: "songIndexToRemove", value: songIndex)
        }
        for songId in songIdsToAdd {
            urlComp.addQueryItem(name: "songIdToAdd", value: songId)
        }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }

    private func request(fromUrlComponent: URLComponents, viaXmlParser parserDelegate: SsXmlParser, ignoreErrorResponse: Bool = false) {
        guard let url = fromUrlComponent.url else {
            os_log("URL could not be created: %s", log: log, type: .error, fromUrlComponent.description)
            return
        }
        let parser = XMLParser(contentsOf: url)!
        parser.delegate = parserDelegate
        parser.parse()
        if !ignoreErrorResponse, let error = parserDelegate.error {
            eventLogger.report(error: error)
        }
    }
    
}

extension SubsonicServerApi: SubsonicUrlCreator {
    func getArtUrlString(forCoverArtId id: String) -> String {
        if let apiUrlComponent = createAuthenticatedApiUrlComponent(forAction: "getCoverArt", id: id),
           let url = apiUrlComponent.url {
            return url.absoluteString
        } else {
            return ""
        }
        
    }
}

