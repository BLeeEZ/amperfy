import Foundation
import CoreData
import os.log

protocol AmpacheUrlCreationable {
    func getArtUrlString(forArtistId: Int32) -> String
}

class AmpacheXmlServerApi {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "Ampache")
    private var credentials: LoginCredentials?
    private var authHandshake: AuthentificationHandshake?
    static let maxItemCountToPollAtOnce: Int = 500
    
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

    var defaultArtworkUrl: String {
        var url = ""
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake {
            url = "\(hostname)/image.php?object_id=0&object_type=album&auth=\(auth.token)"
        }
        return url
    }

    func isAuthenticated() -> Bool {
        guard let auth = authHandshake else {
            return false
        }
        let deltaTime:TimeInterval = auth.reauthenicateTime.timeIntervalSince(Date())
        if deltaTime.isLess(than: 0.0) {
            return false
        }
        return true
    }
    
    private func generatePassphrase(passwordHash: String, timestamp: Int) -> String {
        // Ampache passphrase: sha256(unixtime + sha256(password)) where '+' denotes concatenation
        // Concatenate timestamp and password hash
        let dataStr = "\(timestamp)\(passwordHash)"
        let passphrase = Hasher.sha256(dataString: dataStr)
        return passphrase
    }
    
    func provideCredentials(credentials: LoginCredentials) {
        self.credentials = credentials
    }
    
    func authenticate(credentials: LoginCredentials) {
        self.credentials = credentials
        let timestamp = Int(NSDate().timeIntervalSince1970)
        let passphrase = generatePassphrase(passwordHash: credentials.passwordHash, timestamp: timestamp)
        
        guard let userUrl = credentials.username.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            os_log("Username could not be url escaped: %s", log: log, type: .error, credentials.username)
            return
        }
        
        let urlPath = "\(credentials.serverUrl)/server/xml.server.php?action=handshake&auth=\(passphrase)&timestamp=\(timestamp)&version=350001&user=\(userUrl)"
        os_log("%s", log: log, type: .default, urlPath)
        
        guard let url = URL(string: urlPath) else {
            os_log("Ampache server url is invalid: %s", log: log, type: .error, urlPath)
            return
        }
        
        let parser = XMLParser(contentsOf: url)!
        let curDelegate = AuthParserDelegate()
        parser.delegate = curDelegate
        let success = parser.parse()
        if success && curDelegate.authHandshake != nil {
            authHandshake = curDelegate.authHandshake
        } else {
            authHandshake = nil
            os_log("Couldn't get a login token.", log: log, type: .error)
        }
    }
    
    private func reauthenticateIfNeccessary() {
        if !isAuthenticated() {
            if let cred = credentials {
                authenticate(credentials: cred)
            }
        }
    }
 
    func requestArtists(parserDelegate: XMLParserDelegate) {
        reauthenticateIfNeccessary()
        if let auth = authHandshake {
            let pollCount = (auth.artistCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
            for i in 0...pollCount {
                requestArtists(parserDelegate: parserDelegate, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
            }
        }
    }

    func requestArtists(parserDelegate: XMLParserDelegate, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake, startIndex < auth.artistCount {
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=artists&offset=\(startIndex)&limit=\(pollCount)"
            request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
        }
    }

    func requestArtists(parserDelegate: XMLParserDelegate, addDate: Date, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake, startIndex < auth.artistCount {
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=artists&add=\(addDate.asIso8601String)&offset=\(startIndex)&limit=\(pollCount)"
            request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
        }
    }
    
    func requestAlbums(parserDelegate: XMLParserDelegate) {
        reauthenticateIfNeccessary()
        if let auth = authHandshake {
            let pollCount = (auth.albumCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
            for i in 0...pollCount {
                requestAlbums(parserDelegate: parserDelegate, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
            }
        }
    }

    func requestAlbums(parserDelegate: XMLParserDelegate, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake, startIndex < auth.albumCount {
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=albums&offset=\(startIndex)&limit=\(pollCount)"
            request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
        }
    }

    func requestAlbums(parserDelegate: XMLParserDelegate, addDate: Date, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake, startIndex < auth.albumCount {
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=albums&add=\(addDate.asIso8601String)&offset=\(startIndex)&limit=\(pollCount)"
            request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
        }
    }

    func requestSongs(parserDelegate: XMLParserDelegate) {
        reauthenticateIfNeccessary()
        if let auth = authHandshake {
            let pollCount = (auth.songCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
            for i in 0...pollCount {
                requestSongs(parserDelegate: parserDelegate, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
            }
        }
    }

    func requestSongs(parserDelegate: XMLParserDelegate, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake, startIndex < auth.songCount {
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=songs&offset=\(startIndex)&limit=\(pollCount)"
            request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
        }
    }
    
    func requestSongs(parserDelegate: XMLParserDelegate, addDate: Date, startIndex: Int, pollCount: Int = maxItemCountToPollAtOnce) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake, startIndex < auth.songCount {
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=songs&add=\(addDate.asIso8601String)&offset=\(startIndex)&limit=\(pollCount)"
            request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
        }
    }
    
    func requestPlaylists(parserDelegate: XMLParserDelegate) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake {
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=playlists"
            request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
        }
    }
    
    func requestPlaylist(parserDelegate: XMLParserDelegate, id: Int32) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake {
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=playlist&filter=\(id)"
            request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
        }
    }
    
    func requestPlaylistSongs(parserDelegate: XMLParserDelegate, id: Int32) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake {
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=playlist_songs&filter=\(id)"
            request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
        }
    }
    
    func requestPlaylistCreate(parserDelegate: XMLParserDelegate, playlist: Playlist) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake {
            let playlistNameUrl = playlist.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "InvalidPlaylistName"
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=playlist_create&name=\(playlistNameUrl)"
            request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
        }
    }
    
    func requestPlaylistDelete(id: Int32) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake {
            let errorParser = ErrorParserDelegate()
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=playlist_delete&filter=\(id)"
            request(fromUrlString: urlPath, viaXmlParser: errorParser)
            if let error = errorParser.error {
                os_log("%d: %s", log: log, type: .error, error.code, error.message)
            }
        }
    }

    func requestPlaylist(addSongId: Int, toPlaylistId: Int32) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake {
            let errorParser = ErrorParserDelegate()
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=playlist_add_song&filter=\(toPlaylistId)&song=\(addSongId)"
            request(fromUrlString: urlPath, viaXmlParser: errorParser)
            if let error = errorParser.error {
                os_log("%d: %s", log: log, type: .error, error.code, error.message)
            }
        }
    }
    
    func requestPlaylist(removeSongIndex: Int, fromPlaylistId: Int32) {
        reauthenticateIfNeccessary()
        if let hostname = credentials?.serverUrl, let auth = authHandshake {
            let errorParser = ErrorParserDelegate()
            let urlPath = "\(hostname)/server/xml.server.php?auth=\(auth.token)&action=playlist_remove_song&filter=\(fromPlaylistId)&track=\(removeSongIndex)"
            request(fromUrlString: urlPath, viaXmlParser: errorParser)
            if let error = errorParser.error {
                os_log("%d: %s", log: log, type: .error, error.code, error.message)
            }
        }
    }

    private func request(fromUrlString urlPath: String, viaXmlParser parserDelegate: XMLParserDelegate) {
        let url = NSURL(string: urlPath)
        let parser = XMLParser(contentsOf: url! as URL)!
        parser.delegate = parserDelegate
        parser.parse()
    }

    func requesetLibraryMetaData() -> AuthentificationHandshake? {
        reauthenticateIfNeccessary()
        return authHandshake
    }
    
    func generateUrl(forSong song: Song) -> URL? {
        guard var urlString = song.url else {
            return nil
        }
        updateUrlToken(url: &urlString)
        return URL(string: urlString)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        var updatedUrl = artwork.url
        updateUrlToken(url: &updatedUrl)
        return URL(string: updatedUrl)
    }
    
    private func updateUrlToken(url: inout String) {
        reauthenticateIfNeccessary()
        if let auth = authHandshake {
            if let query = URL(string: url)?.query {
                let authIdentifiers = ["ssid", "auth"]
                for authIdentifier in authIdentifiers {
                    let regex = try! NSRegularExpression(pattern: "\(authIdentifier)=([a-z0-9]+)", options: .caseInsensitive)
                    if let match = regex.firstMatch(in: query, options: [], range: NSRange(location: 0, length: query.count)) {
                        if let tokenRange = Range(match.range(at: 1), in: query) {
                            let foundToken = query[tokenRange]
                            url = url.replacingOccurrences(of: foundToken, with: auth.token)
                            break
                        }
                    }
                }
            }
        }
    }
    
}

extension AmpacheXmlServerApi: AmpacheUrlCreationable {
    func getArtUrlString(forArtistId id: Int32) -> String {
        guard let hostname = credentials?.serverUrl else { return "" }
        let token = authHandshake?.token ?? "aaaa"
        return "\(hostname)/image.php?auth=\(token)&object_id=\(id)&object_type=artist"
    }
}
