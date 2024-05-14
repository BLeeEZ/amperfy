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
import PromiseKit
import os.log

public protocol LibraryUpdaterCallbacks {
    func startOperation(name: String, totalCount: Int)
    func tickOpersation()
}

public class LibraryUpdater {
    
    private let log = OSLog(subsystem: "Amperfy", category: "BackgroundSyncer")
    private let storage : PersistentStorage
    private let backendApi: BackendApi
    private let fileManager = CacheFileManager.shared

    init(storage: PersistentStorage, backendApi: BackendApi) {
        self.storage = storage
        self.backendApi = backendApi
    }
    
    public var isVisualUpadateNeeded: Bool {
        return storage.librarySyncVersion != .newestVersion
    }
    
    /// This function will block the execution before the scene handler
    /// Perform here only small/fast opersation
    /// Use UpdateVC for longer operations to display progress to user
    public func performSmallBlockingLibraryUpdatesIfNeeded() {
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
        if storage.librarySyncVersion < .v13 {
            storage.librarySyncVersion = .v13 // if App crashes don't do this step again -> This step is only for convenience
            os_log("Perform blocking library update (START): AbstractPlayable.duration", log: log, type: .info)
            updateAbstractPlayableDuration()
            os_log("Perform blocking library update (DONE): AbstractPlayable.duration", log: log, type: .info)
        }
        if storage.librarySyncVersion < .v15 {
            storage.librarySyncVersion = .v15 // if App crashes don't do this step again -> This step is only for convenience
            os_log("Perform blocking library update (START): Artist,Album,Playlist duration,remoteSongCount", log: log, type: .info)
            updateArtistAlbumPlaylistDurationAndSongCount()
            os_log("Perform blocking library update (DONE): Artist,Album,Playlist duration,remoteSongCount", log: log, type: .info)
        }
        if storage.librarySyncVersion < .v16 {
            storage.librarySyncVersion = .v16 // if App crashes don't do this step again -> This step is only for convenience
            os_log("Perform blocking library update (START): Playlist artworkItems", log: log, type: .info)
            updatePlaylistArtworkItems()
            os_log("Perform blocking library update (DONE): Playlist artworkItems", log: log, type: .info)
        }
    }
    
    private var isRunning = true
    
    public func cancleLibraryUpdate() {
        os_log("LibraryUpdate: cancle", log: self.log, type: .info)
        isRunning = false
    }
    
    /// Opersation can be cancled. Opersation must be able to be restarted
    public func performLibraryUpdateWithStatus(notifier: LibraryUpdaterCallbacks) -> Promise<Void> {
        isRunning = true
        return storage.async.perform { asyncCompanion in
            if self.storage.librarySyncVersion < .v17 {
                os_log("Perform blocking library update (START): Extract Binary Data", log: self.log, type: .info)
                try self.extractBinaryDataToFileManager(notifier: notifier, asyncCompanion: asyncCompanion)
                os_log("Perform blocking library update (DONE): Extract  Binary Data", log: self.log, type: .info)
                if self.isRunning {
                    self.storage.librarySyncVersion = .v17
                }
            }
        }
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
    
    private func updateAbstractPlayableDuration() {
        os_log("Library update: Songs", log: log, type: .info)
        let songs = storage.main.library.getSongs()
        songs.forEach{ _ = $0.updateDuration(updateArtistAndAlbumToo: false) }
        os_log("Library update: PodcastEpisodes", log: log, type: .info)
        let podcastEpisodes = storage.main.library.getPodcastEpisodes()
        podcastEpisodes.forEach{ _ = $0.updateDuration() }
        storage.main.saveContext()
    }
    
    private func updateArtistAlbumPlaylistDurationAndSongCount() {
        os_log("Library update: Albums Duration", log: log, type: .info)
        let albums = storage.main.library.getAlbums()
        albums.forEach{ $0.updateDuration(updateArtistToo: false) }
        os_log("Library update: Artists Duration", log: log, type: .info)
        let artists = storage.main.library.getArtists()
        artists.forEach{ $0.updateDuration() }
        os_log("Library update: Playlists Duration and SongCount", log: log, type: .info)
        let playlists = storage.main.library.getPlaylists()
        playlists.forEach{
            $0.updateDuration()
            $0.remoteSongCount = $0.songCount
        }
        storage.main.saveContext()
    }
    
    private func updatePlaylistArtworkItems() {
        let playlists = storage.main.library.getPlaylists()
        playlists.forEach{
            $0.updateArtworkItems(isInitialUpdate: true)
        }
        storage.main.saveContext()
    }
    
    private func extractBinaryDataToFileManager(notifier: LibraryUpdaterCallbacks, asyncCompanion: CoreDataCompanion) throws {
        os_log("Artwork Update", log: log, type: .info)
        let artworks = asyncCompanion.library.getArtworksContainingBinaryData()
        notifier.startOperation(name: "Artwork Update", totalCount: artworks.count)
        for artwork in artworks {
            if let imageData = artwork.managedObject.imageData,
               let relFilePath = fileManager.createRelPath(for: artwork),
               let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
                do {
                    try self.fileManager.writeDataExcludedFromBackup(data: imageData, to: absFilePath)
                    artwork.relFilePath = relFilePath
                } catch {
                    artwork.relFilePath = nil
                }
            }
            artwork.managedObject.imageData = nil
            asyncCompanion.library.saveContext()
            notifier.tickOpersation()
            if !isRunning {
                throw PMKError.cancelled
            }
        }
        os_log("Embedded Artwork Update", log: log, type: .info)
        let embeddedArtworks = asyncCompanion.library.getEmbeddedArtworksContainingBinaryData()
        notifier.startOperation(name: "Embedded Artwork Update", totalCount: embeddedArtworks.count)
        for embeddedArtwork in embeddedArtworks {
            if let imageData = embeddedArtwork.managedObject.imageData,
               let relFilePath = fileManager.createRelPath(for: embeddedArtwork),
               let absfilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
                do {
                    try self.fileManager.writeDataExcludedFromBackup(data: imageData, to: absfilePath)
                    embeddedArtwork.relFilePath = relFilePath
                } catch {
                    embeddedArtwork.relFilePath = nil
                }
            }
            embeddedArtwork.managedObject.imageData = nil
            asyncCompanion.library.saveContext()
            notifier.tickOpersation()
            if !isRunning {
                throw PMKError.cancelled
            }
        }
        os_log("Songs/Podcast Episode Update", log: log, type: .info)
        let playableFiles = asyncCompanion.library.getPlayableFiles()
        notifier.startOperation(name: "Songs/Episodes Update", totalCount: playableFiles.count)
        for playableFile in playableFiles {
            if let fileData = playableFile.data {
                if let song = playableFile.info?.asSong,
                   let relFilePath = fileManager.createRelPath(for: song),
                   let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
                    do {
                        try fileManager.writeDataExcludedFromBackup(data: fileData, to: absFilePath)
                        song.playableManagedObject.file = nil
                        song.relFilePath = relFilePath
                    } catch {
                        os_log("File for <%s> could not be written to <%s>", log: log, type: .error, song.displayString, relFilePath.path)
                        song.relFilePath = nil
                    }
                } else if let episode = playableFile.info?.asPodcastEpisode,
                          let relFilePath = fileManager.createRelPath(for: episode),
                          let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
                    do {
                        try fileManager.writeDataExcludedFromBackup(data: fileData, to: absFilePath)
                        episode.playableManagedObject.file = nil
                        episode.relFilePath = relFilePath
                    } catch {
                       os_log("File for <%s> could not be written to <%s>", log: log, type: .error, episode.displayString, relFilePath.path)
                        episode.relFilePath = nil
                    }
                }
            }
            asyncCompanion.library.deletePlayableFile(playableFile: playableFile)
            asyncCompanion.library.saveContext()
            notifier.tickOpersation()
            if !isRunning {
                throw PMKError.cancelled
            }
        }
    }
    
}
