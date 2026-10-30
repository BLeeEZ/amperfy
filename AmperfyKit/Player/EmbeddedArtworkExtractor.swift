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

@preconcurrency import ID3TagEditor
import UIKit

final class EmbeddedArtworkExtractor: Sendable {
  private let id3TagEditor = ID3TagEditor()
  private let fileManager = CacheFileManager.shared

  func extractEmbeddedArtwork(
    playableInfo: AbstractPlayableInfo,
    storage: AsyncCoreDataAccessWrapper
  ) async throws {
    let relativeFilePath: URL? = try await storage.performAndGet { asyncCompanion in
      let playable = AbstractPlayable(
        managedObject: asyncCompanion.context
          .object(with: playableInfo.objectID) as! AbstractPlayableMO
      )
      return playable.relFilePath
    }
    guard let relativeFilePath else { return }

    let artworks: [AttachedPicture] = try fileManager.withCacheFile(
      relativePath: relativeFilePath
    ) { fileURL in
      guard let id3Tag = try? id3TagEditor.read(from: fileURL.path) else { return [] }
      return ID3TagContentReader(id3Tag: id3Tag).attachedPictures()
    }

    let embeddedImage: UIImage?
    if let frontCoverArtwork = artworks.lazy.first(where: { $0.type == .frontCover }) {
      embeddedImage = UIImage(data: frontCoverArtwork.picture)
    } else {
      embeddedImage = artworks.lazy.compactMap { UIImage(data: $0.picture) }.first
    }
    guard let pngData = embeddedImage?.pngData() else { return }

    let sourceURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("embedded-artwork-\(UUID().uuidString).png")
    try pngData.write(to: sourceURL, options: [.atomic])
    let rootLease = try fileManager.currentRootLease()

    let preparedCommit = try await storage.performWithCommitValidation { asyncCompanion in
      let playable = AbstractPlayable(
        managedObject: asyncCompanion.context
          .object(with: playableInfo.objectID) as! AbstractPlayableMO
      )
      guard let account = playable.account else { throw CacheRootError.unavailable }
      let embeddedArtwork = asyncCompanion.library.createEmbeddedArtwork(account: account)
      embeddedArtwork.owner = playable
      guard let relFilePath = self.fileManager.createRelPath(for: embeddedArtwork) else {
        throw CacheRootError.unavailable
      }
      let absFilePath = try self.fileManager.getAbsoluteAmperfyPath(
        relFilePath: relFilePath,
        using: rootLease
      )
      let transaction = try self.fileManager.prepareRecoverableFileCommit(
        sourceURL: sourceURL,
        destinationURL: absFilePath,
        accountInfo: account.info,
        using: rootLease
      )
      embeddedArtwork.relFilePath = relFilePath
      return transaction
    } validateBeforeSave: {
      try rootLease.validateCurrent()
    }
    try preparedCommit.finishAfterCoreDataCommit()
  }
}
