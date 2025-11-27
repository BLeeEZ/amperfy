//
//  HomeSection.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 26.11.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

public enum HomeSection: Int, Sendable, CaseIterable, Encodable, Decodable {

  case lastTimePlayedPlaylists
  case recentAlbums
  case latestAlbums
  case randomAlbums
  case latestPodcastEpisodes
  case podcasts
  case radios

  static let defaultValue: [HomeSection] = [.randomAlbums, .recentAlbums, .lastTimePlayedPlaylists, .latestAlbums]

  public var title: String {
    switch self {
    case .recentAlbums: return "Recent Albums"
    case .latestAlbums: return "Latest Albums"
    case .randomAlbums: return "Random Albums"
    case .lastTimePlayedPlaylists: return "Last time played Playlists"
    case .latestPodcastEpisodes: return "Latest Podcast Episodes"
    case .podcasts: return "Podcasts"
    case .radios: return "Radios"
    }
  }
}
