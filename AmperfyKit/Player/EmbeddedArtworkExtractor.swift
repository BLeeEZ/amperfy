//
//  EmbeddedArtworkExtractor.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 25.11.21.
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

import UIKit
import ID3TagEditor

class EmbeddedArtworkExtractor  {

    private let id3TagEditor = ID3TagEditor()
    private let fileManager = CacheFileManager.shared
    
    @MainActor func extractEmbeddedArtwork(storage: PersistentStorage, playable: AbstractPlayable) async throws {
        try await storage.async.perform { companion in
            guard let playableAsyncMO = companion.context.object(with: playable.objectID) as? AbstractPlayableMO else { return }
            let playableAsync = AbstractPlayable(managedObject: playableAsyncMO)
            
            guard let relFilePath = playableAsync.relFilePath,
                  let absFilePath = self.fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath)
            else { return }
            
            guard let id3Tag = try? self.id3TagEditor.read(from: absFilePath.path) else { return }
            let tagContentReader = ID3TagContentReader(id3Tag: id3Tag)
            let artworks = tagContentReader.attachedPictures()
            // if there is a frontCover artwork take this as embedded artwork
            if let frontCoverArtwork = artworks.lazy.filter({ $0.type == .frontCover }).first,
               let artworkImage = UIImage(data: frontCoverArtwork.picture) {
                self.saveEmbeddedImageInLibrary(library: companion.library, playable: playableAsync, embeddedImage: artworkImage)
                // take the first other available artwork
            } else if let artworkImage = artworks.lazy.compactMap({ UIImage(data: $0.picture) }).first {
                self.saveEmbeddedImageInLibrary(library: companion.library, playable: playableAsync, embeddedImage: artworkImage)
            }
        }
    }

    private func saveEmbeddedImageInLibrary(library: LibraryStorage, playable: AbstractPlayable, embeddedImage: UIImage) {
        let embeddedArtwork = library.createEmbeddedArtwork()
        embeddedArtwork.owner = playable
        
        guard let relFilePath = self.fileManager.createRelPath(for: embeddedArtwork),
              let absFilePath = self.fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath),
              let pngData = embeddedImage.pngData()
        else { return }
        
        do {
            try fileManager.writeDataExcludedFromBackup(data: pngData, to: absFilePath)
            embeddedArtwork.relFilePath = relFilePath
        } catch {
            embeddedArtwork.relFilePath = nil
        }
        library.saveContext()
    }
    
}
