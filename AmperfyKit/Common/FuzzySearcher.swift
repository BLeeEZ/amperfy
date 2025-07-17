//
//  FuzzySearcher.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 10.04.24.
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

import Ifrit

// MARK: - MatchResult

public struct MatchResult {
  public let item: PlayableContainable
  public let score: Double
}

// MARK: - FuzzySearcher

public class FuzzySearcher {
  public static func findBestMatch(
    in items: [PlayableContainable],
    search: String
  )
    -> [PlayableContainable] {
    let fuse = Fuse()
    // Improve performance by creating the pattern once
    let pattern = fuse.createPattern(from: search)

    var matches = [MatchResult]()
    items.forEach {
      let result = fuse.search(pattern, in: $0.name)
      if let result = result {
        matches.append(MatchResult(item: $0, score: result.score))
      }
    }
    let sortedMatches = matches.sorted(by: { $0.score < $1.score })
    return sortedMatches.compactMap { $0.item }
  }
}
