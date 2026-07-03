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
  nonisolated private static let foldOptions: String.CompareOptions = [
    .caseInsensitive,
    .diacriticInsensitive,
  ]

  public static func findBestMatch(
    in items: [PlayableContainable],
    search: String,
    isTokenized: Bool = false,
    searchableText: (PlayableContainable) -> String = { $0.name }
  )
    -> [PlayableContainable] {
    guard isTokenized else {
      return findBestFuzzyMatch(in: items, search: search, searchableText: searchableText)
    }

    let fuse = Fuse()
    let foldedSearch = search.folding(options: foldOptions, locale: nil)
    let searchWords = splitInWords(foldedSearch)
    guard !searchWords.isEmpty else { return [] }
    // Improve performance by creating the patterns once
    let patterns = searchWords.map { fuse.createPattern(from: $0) }

    var matches = [(item: PlayableContainable, rank: Int, name: String, score: Double)]()
    for item in items {
      let foldedName = item.name.folding(options: foldOptions, locale: nil)
      let text = searchableText(item)

      let rank: Int
      if foldedName == foldedSearch {
        rank = 0
      } else if foldedName.hasPrefix(foldedSearch) {
        rank = 1
      } else if isEveryWordMatching(searchWords: searchWords, in: foldedName) {
        rank = 2
      } else if isEveryWordMatching(
        searchWords: searchWords,
        in: text.folding(options: foldOptions, locale: nil)
      ) {
        rank = 3
      } else {
        let score = patterns
          .reduce(0.0) { $0 + (fuse.search($1, in: text)?.score ?? 1) } / Double(patterns.count)
        guard score < 1 else { continue }
        matches.append((item, 4, foldedName, score))
        continue
      }
      matches.append((item, rank, foldedName, 0))
    }
    return matches.sorted {
      if $0.rank != $1.rank { return $0.rank < $1.rank }
      if $0.rank < 4 { return $0.name < $1.name }
      return $0.score < $1.score
    }.map(\.item)
  }

  nonisolated private static func splitInWords(_ text: String) -> [String] {
    text.split { !$0.isLetter && !$0.isNumber }.map { String($0) }
  }

  nonisolated private static func isEveryWordMatching(
    searchWords: [String],
    in text: String
  )
    -> Bool {
    let textWords = splitInWords(text)
    return searchWords.allSatisfy { searchWord in
      textWords.contains { $0.hasPrefix(searchWord) }
    }
  }

  private static func findBestFuzzyMatch(
    in items: [PlayableContainable],
    search: String,
    searchableText: (PlayableContainable) -> String
  )
    -> [PlayableContainable] {
    let fuse = Fuse()
    // Improve performance by creating the pattern once
    let pattern = fuse.createPattern(from: search)

    var matches = [MatchResult]()
    items.forEach {
      let result = fuse.search(pattern, in: searchableText($0))
      if let result = result {
        matches.append(MatchResult(item: $0, score: result.score))
      }
    }
    let sortedMatches = matches.sorted(by: { $0.score < $1.score })
    return sortedMatches.compactMap { $0.item }
  }
}
