//
//  LibraryElementDetailTableHeaderView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 15.01.19.
//  Copyright © 2019 Maximilian Bauer. All rights reserved.
//

import UIKit

class LibraryElementDetailTableHeaderView: UIView {
    
    @IBOutlet weak var playAllButton: UIButton!
    @IBOutlet weak var addAllToPlaylistButton: UIButton!
    
    static let frameHeight: CGFloat = 62.0
    
    private var artist: Artist?
    private var album: Album?
    private var player: Player?
    
    @IBAction func playAllButtonPressed(_ sender: Any) {
        if let artist = artist {
            playAllSongsofArtist(artist: artist)
        } else if let album = album {
            playAllSongsInAlbum(album: album)
        }
    }
    
    @IBAction func addAllToPlaylistButtonPressed(_ sender: Any) {
        if let artist = artist {
            addArtistSongsToPlaylist(artist: artist)
        } else if let album = album {
            addAlbumSongsToPlaylist(album: album)
        }
    }
    
    private func playAllSongsofArtist(artist: Artist) {
        guard let player = player, let _ = artist.albums?.array as? [Album] else {
            return
        }
        player.cleanPlaylist()
        addArtistSongsToPlaylist(artist: artist)
        player.play()
    }
    
    private func addArtistSongsToPlaylist(artist: Artist) {
        if let player = player, let songs = artist.songs?.array as? [Song] {
            for song in songs {
                player.addToPlaylist(song: song)
            }
        }
    }
    
    private func playAllSongsInAlbum(album: Album) {
        guard let player = player, let _ = album.songs?.array as? [Song] else {
            return
        }
        player.cleanPlaylist()
        addAlbumSongsToPlaylist(album: album)
        player.play()
    }
    
    private func addAlbumSongsToPlaylist(album: Album) {
        guard let player = player, let songs = album.songs?.array as? [Song] else {
            return
        }
        for song in songs {
            player.addToPlaylist(song: song)
        }
    }
    
    func prepare(toWorkOnArtist artist: Artist?, with player: Player) {
        self.artist = artist
        self.player = player
    }
    
    func prepare(toWorkOnAlbum album: Album?, with player: Player) {
        self.album = album
        self.player = player
    }
    
}
