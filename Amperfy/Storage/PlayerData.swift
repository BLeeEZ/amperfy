import Foundation
import CoreData

public class PlayerData {
    
    private let storage: LibraryStorage
    private let managed: PlayerManaged
    let playlist: Playlist
    
    init(storage: LibraryStorage, managedPlayer: PlayerManaged, playlist: Playlist) {
        self.storage = storage
        self.managed = managedPlayer
        self.playlist = playlist
    }
    
    public var currentSong: Song? {
        get {
            guard currentSongIndex < playlist.songs.count else {
                return nil
            }
            return playlist.songs[currentSongIndex]
        }
    }
    
    public var currentPlaylistElement: PlaylistElement? {
        get {
            guard currentSongIndex < playlist.songs.count else {
                return nil
            }
            return playlist.entries[currentSongIndex]
        }
    }
    
    var isShuffel: Bool {
        get {
            return managed.shuffelSetting == 1
        }
        set {
            managed.shuffelSetting = newValue ? 1 : 0
            storage.saveContext()
        }
    }
    var repeatMode: RepeatMode {
        get {
            return RepeatMode(rawValue: managed.repeatSetting) ?? .off
        }
        set {
            managed.repeatSetting = newValue.rawValue
            storage.saveContext()
        }
    }
    
    var currentSongIndex: Int {
        get {
            if managed.currentSongIndex >= playlist.songs.count, managed.currentSongIndex < 0 {
                managed.currentSongIndex = 0
                storage.saveContext()
            }
            return Int(managed.currentSongIndex)
        }
        set {
            if newValue >= 0, newValue < playlist.songs.count {
                managed.currentSongIndex = Int32(newValue)
            } else {
                managed.currentSongIndex = 0
            }
            storage.saveContext()
        }
    }

    var previousSongIndex: Int? {
        let prevSongIndex = currentSongIndex - 1
        guard prevSongIndex >= 0 else { return nil }
        if prevSongIndex >= playlist.songs.count {
            return nil
        } else if playlist.songs.count == 0 {
            return nil
        } else {
            return prevSongIndex
        }
    }
    
    var nextSongIndex: Int? {
        let nextSongIndex = currentSongIndex + 1
        if nextSongIndex >= playlist.songs.count {
            return nil
        } else {
            return nextSongIndex
        }
    }
    
    func removeAllSongs() {
        currentSongIndex = 0
        playlist.removeAllSongs()
    }
    
    func removeSongFromPlaylist(at index: Int) {
        if index < playlist.songs.count {
            playlist.remove(at: index)
            if index < currentSongIndex {
                currentSongIndex = currentSongIndex - 1
            }
        }
    }
    
    func movePlaylistSong(fromIndex: Int, to: Int) {
        if fromIndex < playlist.songs.count, to < playlist.songs.count {
            playlist.movePlaylistSong(fromIndex: fromIndex, to: to)
            if currentSongIndex == fromIndex {
                currentSongIndex = to
            } else if currentSongIndex == to {
                currentSongIndex = fromIndex
            }
        }
    }
}
