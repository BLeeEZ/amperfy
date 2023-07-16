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
import PromiseKit

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
    func notifySyncStarted(ofType parsedObjectType: ParsedObjectType, totalCount: Int)
}

public protocol LibrarySyncer {
    func syncInitial(statusNotifyier: SyncCallbacks?) -> Promise<Void>
    func sync(genre: Genre) -> Promise<Void>
    func sync(artist: Artist) -> Promise<Void>
    func sync(album: Album) -> Promise<Void>
    func sync(song: Song) -> Promise<Void>
    func sync(podcast: Podcast) -> Promise<Void>
    func syncLatestLibraryElements() -> Promise<Void>
    func syncFavoriteLibraryElements() -> Promise<Void>
    func syncDownPlaylistsWithoutSongs() -> Promise<Void>
    func syncDown(playlist: Playlist) -> Promise<Void>
    func syncUpload(playlistToUpdateName playlist: Playlist) -> Promise<Void>
    func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song]) -> Promise<Void>
    func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int) -> Promise<Void>
    func syncUpload(playlistToUpdateOrder playlist: Playlist) -> Promise<Void>
    func syncUpload(playlistIdToDelete id: String) -> Promise<Void>
    func syncDownPodcastsWithoutEpisodes() -> Promise<Void>
    func searchArtists(searchText: String) -> Promise<Void>
    func searchAlbums(searchText: String) -> Promise<Void>
    func searchSongs(searchText: String) -> Promise<Void>
    func syncMusicFolders() -> Promise<Void>
    func syncIndexes(musicFolder: MusicFolder) -> Promise<Void>
    func sync(directory: Directory) -> Promise<Void>
    func requestRandomSongs(playlist: Playlist, count: Int) -> Promise<Void>
    func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) -> Promise<Void>
    func scrobble(song: Song, date: Date?) -> Promise<Void>
    func setRating(song: Song, rating: Int) -> Promise<Void>
    func setRating(album: Album, rating: Int) -> Promise<Void>
    func setRating(artist: Artist, rating: Int) -> Promise<Void>
    func setFavorite(song: Song, isFavorite: Bool) -> Promise<Void>
    func setFavorite(album: Album, isFavorite: Bool) -> Promise<Void>
    func setFavorite(artist: Artist, isFavorite: Bool) -> Promise<Void>
}

protocol AbstractBackgroundLibrarySyncer {
    var isActive: Bool { get }
    func stop()
    func stopAndWait()
}

public protocol BackendApi {
    var clientApiVersion: String { get }
    var serverApiVersion: String { get }
    func provideCredentials(credentials: LoginCredentials)
    func isAuthenticationValid(credentials: LoginCredentials) -> Promise<Void>
    func generateUrl(forDownloadingPlayable playable: AbstractPlayable) -> Promise<URL>
    func generateUrl(forStreamingPlayable playable: AbstractPlayable) -> Promise<URL>
    func generateUrl(forArtwork artwork: Artwork) -> Promise<URL>
    func checkForErrorResponse(inData data: Data) -> ResponseError?
    func createLibrarySyncer(storage: PersistentStorage) -> LibrarySyncer
    func createArtworkArtworkDownloadDelegate() -> DownloadManagerDelegate
    func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo?
}
