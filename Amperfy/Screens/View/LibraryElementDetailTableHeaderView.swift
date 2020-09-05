import UIKit

class LibraryElementDetailTableHeaderView: UIView {
    
    @IBOutlet weak var playAllButton: UIButton!
    @IBOutlet weak var addAllToPlaylistButton: UIButton!
    
    static let frameHeight: CGFloat = 62.0
    
    private var artist: Artist?
    private var album: Album?
    private var playlist: Playlist?
    private var player: MusicPlayer?
    
    @IBAction func playAllButtonPressed(_ sender: Any) {
        if let artist = artist {
            playAllSongsofArtist(artist: artist)
        } else if let album = album {
            playAllSongsInAlbum(album: album)
        } else if let playlist = playlist {
            playAllSongsInPlaylist(playlist: playlist)
        }
    }
    
    @IBAction func addAllToPlayNextButtonPressed(_ sender: Any) {
        if let artist = artist {
            addArtistSongsToPlaylist(artist: artist)
        } else if let album = album {
            addAlbumSongsToPlaylist(album: album)
        } else if let playlist = playlist {
            addPlaylistSongsToPlaylist(playlist: playlist)
        }
    }
    
    private func playAllSongsofArtist(artist: Artist) {
        guard let player = player else {
            return
        }
        player.cleanPlaylist()
        addArtistSongsToPlaylist(artist: artist)
        player.play()
    }
    
    private func addArtistSongsToPlaylist(artist: Artist) {
        if let player = player {
            for song in artist.songs {
                player.addToPlaylist(song: song)
            }
        }
    }
    
    private func playAllSongsInAlbum(album: Album) {
        guard let player = player else {
            return
        }
        player.cleanPlaylist()
        addAlbumSongsToPlaylist(album: album)
        player.play()
    }
    
    private func addAlbumSongsToPlaylist(album: Album) {
        guard let player = player else {
            return
        }
        for song in album.songs {
            player.addToPlaylist(song: song)
        }
    }
    
    private func playAllSongsInPlaylist(playlist: Playlist) {
        guard let player = player else {
            return
        }
        player.cleanPlaylist()
        addPlaylistSongsToPlaylist(playlist: playlist)
        player.play()
    }
    
    private func addPlaylistSongsToPlaylist(playlist: Playlist) {
        guard let player = player else {
            return
        }
        for song in playlist.songs {
            player.addToPlaylist(song: song)
        }
    }
    
    func prepare(toWorkOnArtist artist: Artist?, with player: MusicPlayer) {
        self.artist = artist
        self.player = player
    }
    
    func prepare(toWorkOnAlbum album: Album?, with player: MusicPlayer) {
        self.album = album
        self.player = player
    }
    
    func prepare(toWorkOnPlaylist playlist: Playlist?, with player: MusicPlayer) {
        self.playlist = playlist
        self.player = player
    }
    
}
