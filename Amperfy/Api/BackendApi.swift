import Foundation
import CoreData

enum ParsedObjectType {
    case artist
    case album
    case song
    case playlist
    case genre
}

protocol ParsedObjectNotifiable {
    func notifyParsedObject(ofType parsedObjectType: ParsedObjectType)
}

protocol SyncCallbacks: ParsedObjectNotifiable {
    func notifySyncStarted(ofType parsedObjectType: ParsedObjectType)
    func notifySyncFinished()
}

protocol LibrarySyncer {
    var artistCount: Int { get }
    var albumCount: Int { get }
    var songCount: Int { get }
    var genreCount: Int { get }
    var playlistCount: Int { get }
    func sync(currentContext: NSManagedObjectContext, persistentContainer: NSPersistentContainer, statusNotifyier: SyncCallbacks?)
    func sync(artist: Artist, libraryStorage: LibraryStorage)
    func sync(album: Album, libraryStorage: LibraryStorage)
    func syncDownPlaylistsWithoutSongs(libraryStorage: LibraryStorage)
    func syncDown(playlist: Playlist, libraryStorage: LibraryStorage)
    func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song], libraryStorage: LibraryStorage)
    func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int, libraryStorage: LibraryStorage)
    func syncUpload(playlistToUpdateOrder playlist: Playlist, libraryStorage: LibraryStorage)
    func syncUpload(playlistToDelete playlist: Playlist)
    func searchSongs(searchText: String, libraryStorage: LibraryStorage)
    func syncMusicFolders(libraryStorage: LibraryStorage)
    func syncIndexes(musicFolder: MusicFolder, libraryStorage: LibraryStorage)
    func sync(directory: Directory, libraryStorage: LibraryStorage)
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
