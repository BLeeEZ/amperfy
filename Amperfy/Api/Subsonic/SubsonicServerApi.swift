import Foundation
import os.log

protocol SubsonicUrlCreator {
    func getArtUrlString(forArtistId: String) -> String
}

class SubsonicServerApi {
    
    static let defaultClientApiVersionWithToken = SubsonicVersion(major: 1, minor: 13, patch: 0)
    static let defaultClientApiVersionPreToken = SubsonicVersion(major: 1, minor: 11, patch: 0)
    
    var serverApiVersion: SubsonicVersion?
    var clientApiVersion = defaultClientApiVersionWithToken
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "Subsonic")
    private var credentials: LoginCredentials?
    private var isValidCredentials = false

    private func generateAuthenticationToken(password: String, salt: String) -> String {
        // Calculate the authentication token as follows: token = md5(password + salt).
        // The md5() function takes a string and returns the 32-byte ASCII hexadecimal representation of the MD5 hash,
        // using lower case characters for the hex values. The '+' operator represents concatenation of the two strings.
        // Treat the strings as UTF-8 encoded when calculating the hash. Send the result as parameter
        let dataStr = "\(password)\(salt)"
        let authenticationToken = Hasher.md5Hex(dataString: dataStr)
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
        
        let curDelegate = PingParserDelegate()
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
    
    func generateUrl(forSong song: Song) -> URL? {
        return createAuthenticatedApiUrlComponent(forAction: "download", id: song.id)?.url
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        guard !artwork.owners.isEmpty, let firstOwner = artwork.owners.first else {
            return nil
        }
        return createAuthenticatedApiUrlComponent(forAction: "getCoverArt", id: firstOwner.id)?.url
    }
    
    func requestServerApiVersion() -> SubsonicVersion? {
        guard let urlComp = createBasicApiUrlComponent(forAction: "ping") else { return nil }
        let parserDelegate = PingParserDelegate()
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
        guard let serverApiVersionString = parserDelegate.serverApiVersion else { return nil }
        guard let serverApiVersion = SubsonicVersion(serverApiVersionString) else {
            os_log("The server API version '%s' could not be parsed to 'SubsonicVersion'", log: log, type: .info, serverApiVersionString)
            return nil
        }
        return serverApiVersion
    }

    func requestArtists(parserDelegate: XMLParserDelegate) {
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "getArtists") else { return }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }
    
    func requestArtist(parserDelegate: XMLParserDelegate, id: String) {
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "getArtist", id: id) else { return }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }
    
    func requestAlbum(parserDelegate: XMLParserDelegate, id: String) {
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "getAlbum", id: id) else { return }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylists(parserDelegate: XMLParserDelegate) {
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "getPlaylists") else { return }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }

    func requestPlaylistSongs(parserDelegate: XMLParserDelegate, id: String) {
        guard let urlComp = createAuthenticatedApiUrlComponent(forAction: "getPlaylist", id: id) else { return }
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }

    func requestPlaylistCreate(parserDelegate: XMLParserDelegate, playlist: Playlist) {
        guard var urlComp = createAuthenticatedApiUrlComponent(forAction: "createPlaylist") else { return }
        urlComp.addQueryItem(name: "name", value: playlist.name)
        request(fromUrlComponent: urlComp, viaXmlParser: parserDelegate)
    }

    func requestPlaylistUpdate(parserDelegate: XMLParserDelegate, playlist: Playlist, songIndicesToRemove: [Int], songIdsToAdd: [String]) {
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

    private func request(fromUrlComponent: URLComponents, viaXmlParser parserDelegate: XMLParserDelegate) {
        guard let url = fromUrlComponent.url else {
            os_log("URL could not be created: %s", log: log, type: .error, fromUrlComponent.description)
            return
        }
        let parser = XMLParser(contentsOf: url)!
        parser.delegate = parserDelegate
        parser.parse()
    }
    
}

extension SubsonicServerApi: SubsonicUrlCreator {
    func getArtUrlString(forArtistId id: String) -> String {
        if let apiUrlComponent = createAuthenticatedApiUrlComponent(forAction: "getCoverArt", id: id),
           let url = apiUrlComponent.url {
            return url.absoluteString
        } else {
            return ""
        }
        
    }
}

