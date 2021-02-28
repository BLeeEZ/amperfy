import Foundation

protocol ParsedObjectNotifiable {
    func notifyParsedObject()
}

protocol SyncCallbacks: ParsedObjectNotifiable {
    func notifyArtistSyncStarted()
    func notifyAlbumsSyncStarted()
    func notifySongsSyncStarted()
    func notifyPlaylistSyncStarted()
    func notifySyncFinished()
}

protocol PlaylistSyncCallbacks {
    func notifyPlaylistWillCleared()
    func notifyPlaylistSyncFinished(playlist: Playlist)
    func notifyPlaylistUploadFinished(success: Bool)
}

protocol LibrarySyncer {
    var artistCount: Int { get }
    var albumCount: Int { get }
    var songCount: Int { get }
    var playlistCount: Int { get }
    func sync(libraryStorage: LibraryStorage, statusNotifyier: SyncCallbacks?)
    func syncDownPlaylistsWithoutSongs(libraryStorage: LibraryStorage)
    func syncDown(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks?)
    func syncUpload(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks?)
}

protocol BackgroundLibrarySyncer {
    var isActive: Bool { get }
    func syncInBackground(libraryStorage: LibraryStorage)
    func stop()
    func stopAndWait()
}

protocol BackendApi {
    var clientApiVersion: String { get }
    var serverApiVersion: String { get }
    func provideCredentials(credentials: LoginCredentials)
    func authenticate(credentials: LoginCredentials) 
    func isAuthenticated() -> Bool
    func generateUrl(forSong song: Song) -> URL?
    func generateUrl(forArtwork artwork: Artwork) -> URL?
    func createLibrarySyncer() -> LibrarySyncer
    func createLibraryBackgroundSyncer() -> BackgroundLibrarySyncer
    func createArtworkBackgroundSyncer() -> BackgroundLibrarySyncer
}
