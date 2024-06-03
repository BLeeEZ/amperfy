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
        // To avoid crashed due to RAM overflow we need to use
        // autoreleasepool: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmAutoreleasePools.html
        // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/Performance.html
        
        os_log("Artwork Update", log: log, type: .info)
        var artworkRemoteInfos = [ArtworkRemoteInfo]()
        autoreleasepool {
            let artworks = asyncCompanion.library.getArtworksContainingBinaryData()
            artworkRemoteInfos = artworks.compactMap{ $0.remoteInfo }
        }
        notifier.startOperation(name: "Artwork Update", totalCount: artworkRemoteInfos.count)
        for artworkRemoteInfo in artworkRemoteInfos {
            moveArtworkToFileManager(artworkRemoteInfo: artworkRemoteInfo, asyncCompanion: asyncCompanion)
            asyncCompanion.library.saveContext()
            notifier.tickOpersation()
            if !isRunning {
                throw PMKError.cancelled
            }
        }
        
        os_log("Embedded Artwork Update", log: log, type: .info)
        var embeddedArtworkOwners = [AbstractPlayable]()
        autoreleasepool {
            let embeddedArtworks = asyncCompanion.library.getEmbeddedArtworksContainingBinaryData()
            embeddedArtworkOwners = embeddedArtworks.compactMap{ $0.owner }
        }
        notifier.startOperation(name: "Embedded Artwork Update", totalCount: embeddedArtworkOwners.count)
        for embeddedArtworkOwner in embeddedArtworkOwners {
            moveEmbeddedArtworkToFileManager(embeddedArtworkOwner: embeddedArtworkOwner, asyncCompanion: asyncCompanion)
            asyncCompanion.library.saveContext()
            notifier.tickOpersation()
            if !isRunning {
                throw PMKError.cancelled
            }
        }
    
        os_log("Songs/Podcast Episode Update", log: log, type: .info)
        let cachedSongs = asyncCompanion.library.getCachedSongsThatHaveFileDataInCoreData()
        let cachedEpisodes = asyncCompanion.library.getCachedPodcastEpisodesThatHaveFileDataInCoreData()
        notifier.startOperation(name: "Songs/Episodes Update", totalCount: cachedSongs.count + cachedEpisodes.count)
        for cachedSong in cachedSongs {
            movePlayableToFileManager(playable: cachedSong, asyncCompanion: asyncCompanion)
            asyncCompanion.library.saveContext()
            notifier.tickOpersation()
            if !isRunning {
                throw PMKError.cancelled
            }
        }
        for cachedEpisode in cachedEpisodes {
            movePlayableToFileManager(playable: cachedEpisode, asyncCompanion: asyncCompanion)
            asyncCompanion.library.saveContext()
            notifier.tickOpersation()
            if !isRunning {
                throw PMKError.cancelled
            }
        }
    }
    
    private func moveArtworkToFileManager(artworkRemoteInfo: ArtworkRemoteInfo, asyncCompanion: CoreDataCompanion) {
        autoreleasepool {
            if let imageData = asyncCompanion.library.getArtworkData(forArtworkRemoteInfo: artworkRemoteInfo),
               let artwork = asyncCompanion.library.getArtwork(remoteInfo: artworkRemoteInfo),
               let relFilePath = fileManager.createRelPath(for: artwork),
               let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
                do {
                    try self.fileManager.writeDataExcludedFromBackup(data: imageData, to: absFilePath)
                    artwork.relFilePath = relFilePath
                } catch {
                    artwork.relFilePath = nil
                }
                artwork.managedObject.imageData = nil
            }
        }
    }
    
    private func moveEmbeddedArtworkToFileManager(embeddedArtworkOwner: AbstractPlayable, asyncCompanion: CoreDataCompanion) {
        autoreleasepool {
            if let imageData = asyncCompanion.library.getEmbeddedArtworkData(forOwner: embeddedArtworkOwner),
               let embeddedArtwork = asyncCompanion.library.getEmbeddedArtwork(forOwner: embeddedArtworkOwner),
               let relFilePath = fileManager.createRelPath(for: embeddedArtwork),
               let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
                do {
                    try self.fileManager.writeDataExcludedFromBackup(data: imageData, to: absFilePath)
                    embeddedArtwork.relFilePath = relFilePath
                } catch {
                    embeddedArtwork.relFilePath = nil
                }
                embeddedArtwork.managedObject.imageData = nil
            }
        }
    }
    
    private func movePlayableToFileManager(playable: AbstractPlayable, asyncCompanion: CoreDataCompanion) {
        if let playableData = getPlayableDataAndDeleteCoreDataFile(playable: playable, asyncCompanion: asyncCompanion) {
            movePlayableToFileManager(playable: playable, fileData: playableData)
        }
    }
    
    private func getPlayableDataAndDeleteCoreDataFile(playable: AbstractPlayable, asyncCompanion: CoreDataCompanion) -> Data? {
        var data: Data?
        autoreleasepool {
            if let playableFile = asyncCompanion.library.getFile(forPlayable: playable) {
                let playableFileSizeInByte = asyncCompanion.library.getFileSizeOfPlayableFileInByte(playableFile: playableFile)
                // file size must be smaller than 1 GB
                // file data will be loaded into memory -> too big will lead to crash
                if playableFileSizeInByte < 1_000_000_000 {
                    data = playableFile.data
                }
                playableFile.info?.playableManagedObject.file = nil
                asyncCompanion.library.deletePlayableFile(playableFile: playableFile)
            }
        }
        return data
    }
    
    private func movePlayableToFileManager(playable: AbstractPlayable, fileData: Data) {
        if let relFilePath = fileManager.createRelPath(for: playable),
           let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
            do {
                try fileManager.writeDataExcludedFromBackup(data: fileData, to: absFilePath)
                playable.relFilePath = relFilePath
            } catch {
                os_log("File for <%s> could not be written to <%s>", log: log, type: .error, playable.displayString, relFilePath.path)
                playable.relFilePath = nil
            }
        }
    }
    
}
