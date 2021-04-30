import Foundation
import CoreData

protocol ParsedObjectNotifiable {
    func notifyParsedObject()
}

protocol SyncCallbacks: ParsedObjectNotifiable {
    func notifyGenreSyncStarted()
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
    func sync(currentContext: NSManagedObjectContext, persistentContainer: NSPersistentContainer, statusNotifyier: SyncCallbacks?)
    func syncDownPlaylistsWithoutSongs(libraryStorage: LibraryStorage)
    func syncDown(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks?)
    func syncUpload(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks?)
}

protocol AbstractBackgroundLibrarySyncer {
    var isActive: Bool { get }
    func stop()
    func stopAndWait()
}

protocol BackgroundLibrarySyncer: AbstractBackgroundLibrarySyncer {
    func syncInBackground(libraryStorage: LibraryStorage)
}

protocol BackgroundLibraryVersionResyncer: AbstractBackgroundLibrarySyncer {
    func resyncDueToNewLibraryVersionInBackground(libraryStorage: LibraryStorage, libraryVersion: LibrarySyncVersion)
}

protocol BackendApi {
    var clientApiVersion: String { get }
    var serverApiVersion: String { get }
    func provideCredentials(credentials: LoginCredentials)
    func authenticate(credentials: LoginCredentials) 
    func isAuthenticated() -> Bool
    func generateUrl(forDownloadingSong song: Song) -> URL?
    func generateUrl(forStreamingSong song: Song) -> URL?
    func generateUrl(forArtwork artwork: Artwork) -> URL?
    func checkForErrorResponse(inData data: Data) -> ResponseError?
    func createLibrarySyncer() -> LibrarySyncer
    func createLibraryBackgroundSyncer() -> BackgroundLibrarySyncer
    func createLibraryVersionBackgroundResyncer() -> BackgroundLibraryVersionResyncer
    func createArtworkBackgroundSyncer() -> BackgroundLibrarySyncer
}
