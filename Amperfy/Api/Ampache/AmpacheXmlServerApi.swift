import Foundation
import CoreData
import os.log

protocol AmpacheUrlCreationable {
    func getArtUrlString(forArtistId: String) -> String
}


class AmpacheXmlServerApi {
    
    static let maxItemCountToPollAtOnce: Int = 500
    
    var serverApiVersion: String?
    let clientApiVersion = "500000"
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "Ampache")
    let eventLogger: EventLogger
    private var credentials: LoginCredentials?
    private var authHandshake: AuthentificationHandshake?
    
    var artistCount: Int {
        reauthenticateIfNeccessary()
        return authHandshake?.artistCount ?? 0
    }
    var albumCount: Int {
        reauthenticateIfNeccessary()
        return authHandshake?.albumCount ?? 0
    }
    var songCount: Int {
        reauthenticateIfNeccessary()
        return authHandshake?.songCount ?? 0
    }
    var genreCount: Int {
        reauthenticateIfNeccessary()
        return authHandshake?.genreCount ?? 0
    }
    var playlistCount: Int {
        reauthenticateIfNeccessary()
        return authHandshake?.playlistCount ?? 0
    }

    var defaultArtworkUrl: String {
        reauthenticateIfNeccessary()
        guard
        let hostname = credentials?.serverUrl,
        let auth = authHandshake,
        var url = URL(string: hostname)
        else { return "" }

        url.appendPathComponent("image.php")
        guard var urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return "" }
        urlComp.addQueryItem(name: "object_id", value: "0")
        urlComp.addQueryItem(name: "object_type", value: "album")
        urlComp.addQueryItem(name: "auth", value: auth.token)
        guard let urlString = urlComp.string else { return ""}
        return urlString
    }
    
    init(eventLogger: EventLogger) {
        self.eventLogger = eventLogger
    }

    func isAuthenticated() -> Bool {
        guard let auth = authHandshake else { return false }
        let deltaTime:TimeInterval = auth.reauthenicateTime.timeIntervalSince(Date())
        return !deltaTime.isLess(than: 0.0)
    }
    
    private func generatePassphrase(passwordHash: String, timestamp: Int) -> String {
        // Ampache passphrase: sha256(unixtime + sha256(password)) where '+' denotes concatenation
        // Concatenate timestamp and password hash
        let dataStr = "\(timestamp)\(passwordHash)"
        let passphrase = StringHasher.sha256(dataString: dataStr)
        return passphrase
    }

    private func createApiUrl() -> URL? {
        guard let hostname = credentials?.serverUrl else { return nil }
        var apiUrl = URL(string: hostname)
        apiUrl?.appendPathComponent("server")
        apiUrl?.appendPathComponent("xml.server.php")
        return apiUrl
    }

    private func createAuthenticatedApiUrlComponent() -> URLComponents? {
        reauthenticateIfNeccessary()
        guard let apiUrl = createApiUrl(),
            let auth = authHandshake,
            var urlComp = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false)
          else { return nil }
        urlComp.addQueryItem(name: "auth", value: auth.token)
        return urlComp
    }
 
    func provideCredentials(credentials: LoginCredentials) {
        self.credentials = credentials
    }
    
    func authenticate(credentials: LoginCredentials) {
        self.credentials = credentials
        let timestamp = Int(NSDate().timeIntervalSince1970)
        let passphrase = generatePassphrase(passwordHash: credentials.passwordHash, timestamp: timestamp)

        guard let apiUrl = createApiUrl(), var urlComp = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else { return }
        urlComp.addQueryItem(name: "action", value: "handshake")
        urlComp.addQueryItem(name: "auth", value: passphrase)
        urlComp.addQueryItem(name: "timestamp", value: timestamp)
        urlComp.addQueryItem(name: "version", value: clientApiVersion)
        urlComp.addQueryItem(name: "user", value: credentials.username)
        guard let url = urlComp.url else {
            os_log("Ampache authentication url is invalid: %s", log: log, type: .error, urlComp.description)
            return
        }
        let parser = XMLParser(contentsOf: url)!
        let curDelegate = AuthParserDelegate()
        parser.delegate = curDelegate
        let success = parser.parse()
        if let serverApiVersion = curDelegate.serverApiVersion {
            self.serverApiVersion = serverApiVersion
        }
        if let error = parser.parserError {
            authHandshake = nil
            os_log("Error during AuthPars: %s", log: log, type: .error, error.localizedDescription)
            return
        }
        if success && curDelegate.authHandshake != nil {
            authHandshake = curDelegate.authHandshake
        } else {
            authHandshake = nil
            os_log("Couldn't get a login token.", log: log, type: .error)
            if let apiError = curDelegate.error {
                eventLogger.report(error: apiError)
            }
        }
    }
    
    private func reauthenticateIfNeccessary() {
        if !isAuthenticated() {
            if let cred = credentials {
                authenticate(credentials: cred)
            }
        }
    }
    
    func requestGenres(parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "genres")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }

    func requestArtists(parserDelegate: AmpacheXmlParser) {
        reauthenticateIfNeccessary()
        guard let auth = authHandshake else { return }
        let pollCount = (auth.artistCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        for i in 0...pollCount {
            requestArtists(parserDelegate: parserDelegate, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        }
    }

    func requestArtists(parserDelegate: AmpacheXmlParser, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.artistCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "artists")
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }

    func requestArtists(parserDelegate: AmpacheXmlParser, addDate: Date, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.artistCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "artists")
        apiUrlComponent.addQueryItem(name: "add", value: addDate.asIso8601String)
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestArtistAlbums(of artist: Artist, parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "artist_albums")
        apiUrlComponent.addQueryItem(name: "filter", value: artist.id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestArtistSongs(of artist: Artist, parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "artist_songs")
        apiUrlComponent.addQueryItem(name: "filter", value: artist.id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestAlbumSongs(of album: Album, parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "album_songs")
        apiUrlComponent.addQueryItem(name: "filter", value: album.id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestAlbums(parserDelegate: AmpacheXmlParser) {
        reauthenticateIfNeccessary()
        guard let auth = authHandshake else { return }
        let pollCount = (auth.albumCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        for i in 0...pollCount {
            requestAlbums(parserDelegate: parserDelegate, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        }
    }

    func requestAlbums(parserDelegate: AmpacheXmlParser, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.albumCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "albums")
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }

    func requestAlbums(parserDelegate: AmpacheXmlParser, addDate: Date, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.albumCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "albums")
        apiUrlComponent.addQueryItem(name: "add", value: addDate.asIso8601String)
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }

    func requestSongs(parserDelegate: AmpacheXmlParser) {
        reauthenticateIfNeccessary()
        guard let auth = authHandshake else { return }
        let pollCount = (auth.songCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        for i in 0...pollCount {
            requestSongs(parserDelegate: parserDelegate, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        }
    }

    func requestSongs(parserDelegate: AmpacheXmlParser, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.songCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "songs")
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestSongs(parserDelegate: AmpacheXmlParser, addDate: Date, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent(), let auth = authHandshake, startIndex < auth.songCount else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "songs")
        apiUrlComponent.addQueryItem(name: "add", value: addDate.asIso8601String)
        apiUrlComponent.addQueryItem(name: "offset", value: startIndex)
        apiUrlComponent.addQueryItem(name: "limit", value: pollCount)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylists(parserDelegate: AmpacheXmlParser) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlists")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylist(parserDelegate: AmpacheXmlParser, id: String) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist")
        apiUrlComponent.addQueryItem(name: "filter", value: id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylistSongs(parserDelegate: AmpacheXmlParser, id: String) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_songs")
        apiUrlComponent.addQueryItem(name: "filter", value: id)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylistCreate(parserDelegate: AmpacheXmlParser, playlist: Playlist) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_create")
        apiUrlComponent.addQueryItem(name: "name", value: playlist.name)
        apiUrlComponent.addQueryItem(name: "type", value: "private")
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylistDelete(playlist: Playlist) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_delete")
        apiUrlComponent.addQueryItem(name: "filter", value: playlist.id)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestPlaylistAddSong(playlist: Playlist, song: Song) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_add_song")
        apiUrlComponent.addQueryItem(name: "filter", value: playlist.id)
        apiUrlComponent.addQueryItem(name: "song", value: song.id)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestPlaylistDeleteItem(playlist: Playlist, index: Int) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_remove_song")
        apiUrlComponent.addQueryItem(name: "filter", value: playlist.id)
        apiUrlComponent.addQueryItem(name: "track", value: index + 1)
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestPlaylistEdit(playlist: Playlist) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "playlist_edit")
        apiUrlComponent.addQueryItem(name: "filter", value: playlist.id)
        let playlistSongs = playlist.songs
        if playlistSongs.count > 0 {
            apiUrlComponent.addQueryItem(name: "items", value: playlist.songs.compactMap{ $0.id }.joined(separator: ","))
            apiUrlComponent.addQueryItem(name: "tracks", value: Array(1...playlist.songs.count).compactMap{"\($0)"}.joined(separator: ","))
        }
        let errorParser = AmpacheXmlParser()
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: errorParser)
    }
    
    func requestSearchSongs(parserDelegate: AmpacheXmlParser, searchText: String) {
        guard var apiUrlComponent = createAuthenticatedApiUrlComponent() else { return }
        apiUrlComponent.addQueryItem(name: "action", value: "search_songs")
        apiUrlComponent.addQueryItem(name: "filter", value: searchText)
        apiUrlComponent.addQueryItem(name: "limit", value: 40)
        request(fromUrlComponent: apiUrlComponent, viaXmlParser: parserDelegate)
    }
    
    private func request(fromUrlComponent: URLComponents, viaXmlParser parserDelegate: AmpacheXmlParser) {
        guard let url = fromUrlComponent.url else {
            os_log("URL could not be created: %s", log: log, type: .error, fromUrlComponent.description)
            return
        }
        let parser = XMLParser(contentsOf: url)!
        parser.delegate = parserDelegate
        parser.parse()
        if let error = parserDelegate.error, error.statusCode != 0 {
            eventLogger.report(error: error)
        }
    }

    func requesetLibraryMetaData() -> AuthentificationHandshake? {
        reauthenticateIfNeccessary()
        return authHandshake
    }
    
    func generateUrl(forDownloadingSong song: Song) -> URL? {
        guard var urlString = song.url else { return nil }
        updateUrlToken(urlString: &urlString)
        return URL(string: urlString)
    }
    
    func generateUrl(forStreamingSong song: Song) -> URL? {
        return generateUrl(forDownloadingSong: song)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        var updatedUrl = artwork.url
        updateUrlToken(urlString: &updatedUrl)
        return URL(string: updatedUrl)
    }
    
    func checkForErrorResponse(inData data: Data) -> ResponseError? {
        let errorParser = AmpacheXmlParser()
        let parser = XMLParser(data: data)
        parser.delegate = errorParser
        parser.parse()
        if let error = errorParser.error, error.statusCode != 0 {
            eventLogger.report(error: error)
        }
        return errorParser.error
    }
    
    private func updateUrlToken(urlString: inout String) {
        reauthenticateIfNeccessary()
        guard 
        let auth = authHandshake,
        var urlComp = URLComponents(string: urlString),
        let queryItems = urlComp.queryItems
        else { return }

        var newItems = [URLQueryItem]()
        for queryItem in queryItems {
            if queryItem.name.isContainedIn(["ssid", "auth"]) {
                newItems.append(URLQueryItem(name: queryItem.name, value: auth.token))
            } else {
                newItems.append(queryItem)
            }
        }
        urlComp.queryItems = newItems
        urlString = urlComp.string!
    }
    
}

extension AmpacheXmlServerApi: AmpacheUrlCreationable {
    func getArtUrlString(forArtistId id: String) -> String {
        guard let hostname = credentials?.serverUrl, var url = URL(string: hostname) else { return "" }
        url.appendPathComponent("image.php")
        guard var urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return "" }
        let token = authHandshake?.token ?? "NA"
        urlComp.addQueryItem(name: "auth", value: token)
        urlComp.addQueryItem(name: "object_id", value: id)
        urlComp.addQueryItem(name: "object_type", value: "artist")
        return urlComp.string ?? ""
    }
}
