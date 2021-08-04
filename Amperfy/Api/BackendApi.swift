import Foundation
import CoreData

enum ParsedObjectType {
    case artist
    case album
    case song
    case playlist
    case genre
    case podcast
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
    var podcastCount: Int { get }
    func sync(currentContext: NSManagedObjectContext, persistentContainer: NSPersistentContainer, statusNotifyier: SyncCallbacks?)
    func sync(artist: Artist, library: LibraryStorage)
    func sync(album: Album, library: LibraryStorage)
    func syncDownPlaylistsWithoutSongs(library: LibraryStorage)
    func syncDown(playlist: Playlist, library: LibraryStorage)
    func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song], library: LibraryStorage)
    func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int, library: LibraryStorage)
    func syncUpload(playlistToUpdateOrder playlist: Playlist, library: LibraryStorage)
    func syncUpload(playlistToDelete playlist: Playlist)
    func syncDownPodcastsWithoutEpisodes(library: LibraryStorage)
    func sync(podcast: Podcast, library: LibraryStorage)
    func searchArtists(searchText: String, library: LibraryStorage)
    func searchAlbums(searchText: String, library: LibraryStorage)
    func searchSongs(searchText: String, library: LibraryStorage)
    func syncMusicFolders(library: LibraryStorage)
    func syncIndexes(musicFolder: MusicFolder, library: LibraryStorage)
    func sync(directory: Directory, library: LibraryStorage)
    func requestRandomSongs(playlist: Playlist, count: Int, library: LibraryStorage)
}

protocol AbstractBackgroundLibrarySyncer {
    var isActive: Bool { get }
    func stop()
    func stopAndWait()
}

protocol BackgroundLibrarySyncer: AbstractBackgroundLibrarySyncer {
    func syncInBackground(library: LibraryStorage)
}

protocol BackgroundLibraryVersionResyncer: AbstractBackgroundLibrarySyncer {
    func resyncDueToNewLibraryVersionInBackground(library: LibraryStorage, libraryVersion: LibrarySyncVersion)
}

protocol BackendApi {
    var clientApiVersion: String { get }
    var serverApiVersion: String { get }
    var isPodcastSupported: Bool { get }
    func provideCredentials(credentials: LoginCredentials)
    func authenticate(credentials: LoginCredentials) 
    func isAuthenticated() -> Bool
    func isAuthenticationValid(credentials: LoginCredentials) -> Bool
    func generateUrl(forDownloadingPlayable playable: AbstractPlayable) -> URL?
    func generateUrl(forStreamingPlayable playable: AbstractPlayable) -> URL?
    func generateUrl(forArtwork artwork: Artwork) -> URL?
    func checkForErrorResponse(inData data: Data) -> ResponseError?
    func createLibrarySyncer() -> LibrarySyncer
    func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate
    func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo?
}
