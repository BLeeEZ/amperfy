import Foundation

protocol ParsedObjectNotifiable {
    func notifyParsedObject()
}

protocol SyncCallbacks: ParsedObjectNotifiable {
    func notifyArtistSyncStarted()
    func notifyAlbumsSyncStarted()
    func notifySongsSyncStarted()
    func notifyPlaylistSyncStarted()
    func notifyPlaylistCount(playlistCount: Int)
    func notifySyncFinished()
}

protocol PlaylistSyncCallbacks {
    func notifyPlaylistWillCleared()
    func notifyPlaylistSyncFinished(playlist: Playlist)
    func notifyPlaylistUploadFinished(success: Bool)
}

protocol LibrarySyncer {

    var isActive: Bool { get }
    var artistCount: Int { get }
    var albumCount: Int { get }
    var songCount: Int { get }
    func sync(libraryStorage: LibraryStorage, statusNotifyier: SyncCallbacks?)
    func syncDownPlaylistsWithoutSongs(libraryStorage: LibraryStorage)
    func syncDown(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks?)
    func syncUpload(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks?)
    func syncInBackground(libraryStorage: LibraryStorage)
    func resync(libraryStorage: LibraryStorage, syncWave: SyncWaveMO, previousAddDate: Date)
    func stop()
    func stopAndWait()

}

protocol BackendApi {

    var defaultArtworkUrl: String { get }
    func provideCredentials(credentials: LoginCredentials)
    func authenticate(credentials: LoginCredentials) 
    func isAuthenticated() -> Bool
    func updateUrlToken(url: inout String)
    func createLibrarySyncer() -> LibrarySyncer

}
