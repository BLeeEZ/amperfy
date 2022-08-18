//
//  BackendApi.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 19.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import CoreData

public enum ParsedObjectType {
    case artist
    case album
    case song
    case playlist
    case genre
    case podcast
}

public protocol ParsedObjectNotifiable {
    func notifyParsedObject(ofType parsedObjectType: ParsedObjectType)
}

public protocol SyncCallbacks: ParsedObjectNotifiable {
    func notifySyncStarted(ofType parsedObjectType: ParsedObjectType)
    func notifySyncFinished()
}

public protocol LibrarySyncer {
    var artistCount: Int { get }
    var albumCount: Int { get }
    var songCount: Int { get }
    var genreCount: Int { get }
    var playlistCount: Int { get }
    var podcastCount: Int { get }
    func sync(currentContext: NSManagedObjectContext, persistentContainer: NSPersistentContainer, statusNotifyier: SyncCallbacks?)
    func sync(genre: Genre, library: LibraryStorage)
    func sync(artist: Artist, library: LibraryStorage)
    func sync(album: Album, library: LibraryStorage)
    func sync(song: Song, library: LibraryStorage)
    func syncLatestLibraryElements(library: LibraryStorage)
    func syncFavoriteLibraryElements(library: LibraryStorage)
    func syncDownPlaylistsWithoutSongs(library: LibraryStorage)
    func syncDown(playlist: Playlist, library: LibraryStorage)
    func syncUpload(playlistToUpdateName playlist: Playlist, library: LibraryStorage)
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
    func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode)
    func scrobble(song: Song, date: Date?)
    func setRating(song: Song, rating: Int)
    func setRating(album: Album, rating: Int)
    func setRating(artist: Artist, rating: Int)
    func setFavorite(song: Song, isFavorite: Bool)
    func setFavorite(album: Album, isFavorite: Bool)
    func setFavorite(artist: Artist, isFavorite: Bool)
}

protocol AbstractBackgroundLibrarySyncer {
    var isActive: Bool { get }
    func stop()
    func stopAndWait()
}

protocol BackgroundLibraryVersionResyncer: AbstractBackgroundLibrarySyncer {
    func resyncDueToNewLibraryVersionInBackground(library: LibraryStorage, libraryVersion: LibrarySyncVersion)
}

public protocol BackendApi {
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
