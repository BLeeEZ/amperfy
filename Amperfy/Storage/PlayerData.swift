import Foundation
import CoreData

public class PlayerData {
    
    private let storage: LibraryStorage
    private let managed: PlayerManaged
    private let normalPlaylist: Playlist
    private let shuffledPlaylist: Playlist
    
    init(storage: LibraryStorage, managedPlayer: PlayerManaged, normalPlaylist: Playlist, shuffledPlaylist: Playlist) {
        self.storage = storage
        self.managed = managedPlayer
        self.normalPlaylist = normalPlaylist
        self.shuffledPlaylist = shuffledPlaylist
    }
    
    private var activePlaylist: Playlist {
        get {
            if !isShuffle {
                return normalPlaylist
            } else {
                return shuffledPlaylist
            }
        }
    }
    
    private var inactivePlaylist: Playlist {
        get {
            if !isShuffle {
                return shuffledPlaylist
            } else {
                return normalPlaylist
            }
        }
    }
    
    public var playlist: Playlist {
        get { return activePlaylist }
    }
    public var currentSong: Song? {
        get {
            guard currentSongIndex < playlist.songs.count else {
                return nil
            }
            return playlist.songs[currentSongIndex]
        }
    }
    
    public var currentPlaylistItem: PlaylistItem? {
        get {
            guard currentSongIndex < playlist.songs.count else {
                return nil
            }
            return playlist.items[currentSongIndex]
        }
    }
    
    var isShuffle: Bool {
        get {
            return managed.shuffleSetting == 1
        }
        set {
            if newValue {
                shuffledPlaylist.shuffle()
                if let curSong = currentSong, let indexOfCurrentSongInShuffledPlaylist = shuffledPlaylist.getFirstIndex(song: curSong) {
                    shuffledPlaylist.movePlaylistSong(fromIndex: indexOfCurrentSongInShuffledPlaylist, to: 0)
                    currentSongIndex = 0
                }
            } else {
                if let curSong = currentSong, let indexOfCurrentSongInNormalPlaylist = normalPlaylist.getFirstIndex(song: curSong) {
                    currentSongIndex = indexOfCurrentSongInNormalPlaylist
                }
            }
            managed.shuffleSetting = newValue ? 1 : 0
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
    
    func addToPlaylist(song: Song) {
        normalPlaylist.append(song: song)
        shuffledPlaylist.append(song: song)
    }
    
    func removeAllSongs() {
        currentSongIndex = 0
        normalPlaylist.removeAllSongs()
        shuffledPlaylist.removeAllSongs()
    }
    
    func removeSongFromPlaylist(at index: Int) {
        if index < playlist.songs.count {
            let songToRemove = playlist.songs[index]
            activePlaylist.remove(at: index)
            inactivePlaylist.remove(firstOccurrenceOfSong: songToRemove)
            if index < currentSongIndex {
                currentSongIndex = currentSongIndex - 1
            }
        }
    }
    
    func movePlaylistSong(fromIndex: Int, to: Int) {
        if fromIndex < playlist.songs.count, to < playlist.songs.count, fromIndex != to {
            playlist.movePlaylistSong(fromIndex: fromIndex, to: to)
            if currentSongIndex == fromIndex {
                currentSongIndex = to
            } else if fromIndex < currentSongIndex, currentSongIndex <= to {
                currentSongIndex = currentSongIndex - 1
            } else if to <= currentSongIndex, currentSongIndex < fromIndex {
                currentSongIndex = currentSongIndex + 1
            }
        }
    }
}
