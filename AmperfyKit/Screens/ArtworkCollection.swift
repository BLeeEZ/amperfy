//
//  ArtworkCollection.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 06.06.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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
import UIKit

public class ArtworkCollection {
  public let defaultArtworkType: ArtworkType
  public let singleImageEntity: AbstractLibraryEntity?
  public let quadImageEntity: [AbstractLibraryEntity]?
  /// Cover provided by the server (e.g. for a playlist). Shown instead of the entities as soon
  /// as it is downloaded, until then the entities are shown.
  public let serverArtwork: Artwork?

  init(
    defaultArtworkType: ArtworkType,
    singleImageEntity: AbstractLibraryEntity?,
    quadImageEntity: [AbstractLibraryEntity]? = nil,
    serverArtwork: Artwork? = nil
  ) {
    self.serverArtwork = serverArtwork
    self.defaultArtworkType = defaultArtworkType
    self.singleImageEntity = singleImageEntity
    self.quadImageEntity = quadImageEntity
  }

  /// The server cover if it is downloaded, it then replaces the entities
  public var downloadedServerArtwork: Artwork? {
    guard let serverArtwork, serverArtwork.imagePath != nil else { return nil }
    return serverArtwork
  }
}
