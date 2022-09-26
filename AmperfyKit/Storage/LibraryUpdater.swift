//
//  LibraryUpdater.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 16.06.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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
import os.log

public class LibraryUpdater {
    
    private let log = OSLog(subsystem: "Amperfy", category: "BackgroundSyncer")
    private let storage : PersistentStorage
    private let backendApi: BackendApi

    init(storage: PersistentStorage, backendApi: BackendApi) {
        self.storage = storage
        self.backendApi = backendApi
    }
    
    public func performBlockingLibraryUpdatesIfNeeded() {
        if storage.librarySyncVersion < .v9 {
            os_log("Perform blocking library update (START): Artwork ids", log: log, type: .info)
            updateArtworkIdStructure()
            os_log("Perform blocking library update (DONE): Artwork ids", log: log, type: .info)
        }
        if storage.librarySyncVersion < .v12 {
            os_log("Perform blocking library update (START): alphabeticSectionInitial", log: log, type: .info)
            updateAlphabeticSectionInitial()
            os_log("Perform blocking library update (DONE): alphabeticSectionInitial", log: log, type: .info)
        }
        storage.librarySyncVersion = .newestVersion
    }
    
    private func updateArtworkIdStructure() {
        // Extract artwork info from URL
        var artworks = storage.main.library.getArtworks()
        for artwork in artworks {
            if let artworkUrlInfo = self.backendApi.extractArtworkInfoFromURL(urlString: artwork.url) {
                artwork.type = artworkUrlInfo.type
                artwork.id = artworkUrlInfo.id
            } else {
                storage.main.library.deleteArtwork(artwork: artwork)
            }
        }
        storage.main.saveContext()

        // Delete duplicate artworks
        artworks = storage.main.library.getArtworks()
        var uniqueArtworks: [String: Artwork] = [:]
        for artwork in artworks {
            if let existingArtwork = uniqueArtworks[artwork.uniqueID] {
                artwork.owners.forEach{ $0.artwork = existingArtwork }
                storage.main.library.deleteArtwork(artwork: artwork)
            } else {
                uniqueArtworks[artwork.uniqueID] = artwork
            }
        }
        storage.main.saveContext()
    }
    
    private func updateAlphabeticSectionInitial() {
        os_log("Library update: Genres", log: log, type: .info)
        let genres = storage.main.library.getGenres()
        genres.forEach{ $0.updateAlphabeticSectionInitial(section: $0.name) }
        os_log("Library update: Artists", log: log, type: .info)
        let artists = storage.main.library.getArtists()
        artists.forEach{ $0.updateAlphabeticSectionInitial(section: $0.name) }
        os_log("Library update: Albums", log: log, type: .info)
        let albums = storage.main.library.getAlbums()
        albums.forEach{ $0.updateAlphabeticSectionInitial(section: $0.name) }
        os_log("Library update: Songs", log: log, type: .info)
        let songs = storage.main.library.getSongs()
        songs.forEach{ $0.updateAlphabeticSectionInitial(section: $0.name) }
        os_log("Library update: Podcasts", log: log, type: .info)
        let podcasts = storage.main.library.getPodcasts()
        podcasts.forEach{ $0.updateAlphabeticSectionInitial(section: $0.name) }
        os_log("Library update: PodcastEpisodes", log: log, type: .info)
        let podcastEpisodes = storage.main.library.getPodcastEpisodes()
        podcastEpisodes.forEach{ $0.updateAlphabeticSectionInitial(section: $0.name) }
        os_log("Library update: Directories", log: log, type: .info)
        let directories = storage.main.library.getDirectories()
        directories.forEach{ $0.updateAlphabeticSectionInitial(section: $0.name) }
        os_log("Library update: Playlists", log: log, type: .info)
        let playlists = storage.main.library.getPlaylists()
        playlists.forEach{ $0.updateAlphabeticSectionInitial(section: $0.name) }
        storage.main.saveContext()
    }
    
}
