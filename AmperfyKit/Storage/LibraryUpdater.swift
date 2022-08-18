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
    private let persistentStorage : PersistentStorage
    private let backendApi: BackendApi

    init(persistentStorage: PersistentStorage, backendApi: BackendApi) {
        self.persistentStorage = persistentStorage
        self.backendApi = backendApi
    }
    
    public func performBlockingLibraryUpdatesIfNeeded() {
        if persistentStorage.librarySyncVersion < .v9 {
            os_log("Perform blocking library update (START): Artwork ids", log: log, type: .info)
            updateArtworkIdStructure()
            os_log("Perform blocking library update (DONE): Artwork ids", log: log, type: .info)
        }
    }
    
    private func updateArtworkIdStructure() {
        // Extract artwork info from URL
        let library = LibraryStorage(context: persistentStorage.context)
        var artworks = library.getArtworks()
        for artwork in artworks {
            if let artworkUrlInfo = self.backendApi.extractArtworkInfoFromURL(urlString: artwork.url) {
                artwork.type = artworkUrlInfo.type
                artwork.id = artworkUrlInfo.id
            } else {
                library.deleteArtwork(artwork: artwork)
            }
        }
        library.saveContext()

        // Delete duplicate artworks
        artworks = library.getArtworks()
        var uniqueArtworks: [String: Artwork] = [:]
        for artwork in artworks {
            if let existingArtwork = uniqueArtworks[artwork.uniqueID] {
                artwork.owners.forEach{ $0.artwork = existingArtwork }
                library.deleteArtwork(artwork: artwork)
            } else {
                uniqueArtworks[artwork.uniqueID] = artwork
            }
        }
        library.saveContext()
    }
    
}
