import Foundation
import os.log

protocol SubsonicUrlCreator {
    func getArtUrlString(forArtistId: Int) -> String
}

class SubsonicServerApi {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "Subsonic")
    private var credentials: LoginCredentials?
    private var isValidCredentials = false

    private func urlString(forAction: String) -> String {
        guard let credentials = self.credentials else { return "" }
        let version = "1.11.0"

        guard let userUrl = credentials.username.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
            let passwordUrl = credentials.password.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            return ""
        }
        return "\(credentials.serverUrl)/rest/\(forAction).view?u=\(userUrl)&p=\(passwordUrl)&v=\(version)&c=\(AppDelegate.name)"
    }
    
    private func urlString(forAction: String, id: Int) -> String {
        return urlString(forAction: forAction) + "&id=\(id)"
    }
    
    func provideCredentials(credentials: LoginCredentials) {
        self.credentials = credentials
    }
    
    func authenticate(credentials: LoginCredentials) {
        self.credentials = credentials

        let urlPath = urlString(forAction: "ping")
        os_log("%s", log: log, type: .default, urlPath)
        
        guard let url = URL(string: urlPath) else {
            os_log("Subsonic server url invalid: %s", log: log, type: .error, urlPath)
            return
        }
        
        let parser = XMLParser(contentsOf: url)!
        let curDelegate = PingParserDelegate()
        parser.delegate = curDelegate
        let success = parser.parse()
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
        let downloadUrlString = urlString(forAction: "download", id: song.id)
        return URL(string: downloadUrlString)
    }
    
    func generateUrl(forArtwork artwork: Artwork) -> URL? {
        guard !artwork.owners.isEmpty, let firstOwner = artwork.owners.first else {
            return nil
        }
        let coverArtUrlString = urlString(forAction: "getCoverArt", id: firstOwner.id)
        return URL(string: coverArtUrlString)
    }

    func requestArtists(parserDelegate: XMLParserDelegate) {
        let urlPath = urlString(forAction: "getArtists")
        request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
    }
    
    func requestArtist(parserDelegate: XMLParserDelegate, id: Int) {
        let urlPath = urlString(forAction: "getArtist", id: id)
        request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
    }
    
    func requestAlbum(parserDelegate: XMLParserDelegate, id: Int) {
        let urlPath = urlString(forAction: "getAlbum", id: id)
        request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
    }
    
    func requestPlaylists(parserDelegate: XMLParserDelegate) {
        let urlPath = urlString(forAction: "getPlaylists")
        request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
    }

    func requestPlaylistSongs(parserDelegate: XMLParserDelegate, id: Int) {
        let urlPath = urlString(forAction: "getPlaylist", id: id)
        request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
    }

    func requestPlaylistCreate(parserDelegate: XMLParserDelegate, playlist: Playlist) {
        var urlPath = urlString(forAction: "createPlaylist")
        let playlistNameUrl = playlist.name.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) ?? "InvalidPlaylistName"
        urlPath += "&name=" + playlistNameUrl
        request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
    }

    func requestPlaylistUpdate(parserDelegate: XMLParserDelegate, playlist: Playlist, songIndicesToRemove: [Int], songIdsToAdd: [Int]) {
        var urlPath = urlString(forAction: "updatePlaylist")
        urlPath += "&playlistId=\(playlist.id)"
        let playlistNameUrl = playlist.name.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) ?? "InvalidPlaylistName"
        urlPath += "&name=" + playlistNameUrl
        for songIndex in songIndicesToRemove {
            urlPath += "&songIndexToRemove=\(songIndex)"
        }
        for songId in songIdsToAdd {
            urlPath += "&songIdToAdd=\(songId)"
        }
        request(fromUrlString: urlPath, viaXmlParser: parserDelegate)
    }

    private func request(fromUrlString urlPath: String, viaXmlParser parserDelegate: XMLParserDelegate) {
        let url = NSURL(string: urlPath)
        let parser = XMLParser(contentsOf: url! as URL)!
        parser.delegate = parserDelegate
        parser.parse()
    }
    
}

extension SubsonicServerApi: SubsonicUrlCreator {
    func getArtUrlString(forArtistId id: Int) -> String {
        return urlString(forAction: "getCoverArt", id: id)
    }
}

