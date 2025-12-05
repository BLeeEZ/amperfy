//
//  PrefetchIdTester.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 26.03.25.
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

@testable import AmperfyKit
import CoreData
import XCTest

@MainActor
class PrefetchIdTester {
  let library: LibraryStorage
  let prefetchIDs: LibraryStorage.PrefetchIdContainer

  init(library: LibraryStorage, prefetchIDs: LibraryStorage.PrefetchIdContainer) {
    self.library = library
    self.prefetchIDs = prefetchIDs
  }

  func checkPrefetchIdCounts(
    artworkCount: Int = 0,
    genreIdCount: Int = 0,
    genreNameCount: Int = 0,
    artistCount: Int = 0,
    localArtistCount: Int = 0,
    albumCount: Int = 0,
    songCount: Int = 0,
    podcastEpisodeCount: Int = 0,
    radioCount: Int = 0,
    musicFolderCount: Int = 0,
    directoryCount: Int = 0,
    podcastCount: Int = 0,

    artworkFetchCount: Int? = nil,
    genreFetchCount: Int? = nil,
    artistFetchCount: Int? = nil,
    localArtistFetchCount: Int? = nil,
    albumFetchCount: Int? = nil,
    songFetchCount: Int? = nil,
    podcastEpisodeFetchCount: Int? = nil,
    radioFetchCount: Int? = nil,
    musicFolderFetchCount: Int? = nil,
    directoryFetchCount: Int? = nil,
    podcastFetchCount: Int? = nil,

    artworkLibraryCount: Int? = nil,
    genreLibraryCount: Int? = nil,
    artistLibraryCount: Int? = nil,
    albumLibraryCount: Int? = nil,
    songLibraryCount: Int? = nil,
    podcastEpisodeLibraryCount: Int? = nil,
    radioLibraryCount: Int? = nil,
    musicFolderLibraryCount: Int? = nil,
    directoryLibraryCount: Int? = nil,
    podcastLibraryCount: Int? = nil
  ) {
    let summedCount = artworkCount + genreIdCount + genreNameCount + artistCount +
      localArtistCount + albumCount + songCount + podcastEpisodeCount + radioCount +
      musicFolderCount + directoryCount + podcastCount

    XCTAssertEqual(artworkCount, prefetchIDs.artworkIDs.count)
    XCTAssertEqual(genreIdCount, prefetchIDs.genreIDs.count)
    XCTAssertEqual(genreNameCount, prefetchIDs.genreNames.count)
    XCTAssertEqual(artistCount, prefetchIDs.artistIDs.count)
    XCTAssertEqual(localArtistCount, prefetchIDs.localArtistNames.count)
    XCTAssertEqual(albumCount, prefetchIDs.albumIDs.count)
    XCTAssertEqual(songCount, prefetchIDs.songIDs.count)
    XCTAssertEqual(podcastEpisodeCount, prefetchIDs.podcastEpisodeIDs.count)
    XCTAssertEqual(radioCount, prefetchIDs.radioIDs.count)
    XCTAssertEqual(musicFolderCount, prefetchIDs.musicFolderIDs.count)
    XCTAssertEqual(directoryCount, prefetchIDs.directoryIDs.count)
    XCTAssertEqual(podcastCount, prefetchIDs.podcastIDs.count)
    // summed
    XCTAssertEqual(summedCount, prefetchIDs.counts)

    let actArtworkFetchCount = artworkFetchCount ?? artworkCount
    let actGenreFetchCount = genreFetchCount ?? (genreIdCount + genreNameCount)
    let actArtistFetchCount = artistFetchCount ?? artistCount
    let actLocalArtistFetchCount = localArtistFetchCount ?? localArtistCount
    let actAlbumFetchCount = albumFetchCount ?? albumCount
    let actSongFetchCount = songFetchCount ?? songCount
    let actPodcastEpisodeFetchCount = podcastEpisodeFetchCount ?? podcastEpisodeCount
    let actRadioFetchCount = radioFetchCount ?? radioCount
    let actMusicFolderFetchCount = musicFolderFetchCount ?? musicFolderCount
    let actDirectoryFetchCount = directoryFetchCount ?? directoryCount
    let actPodcastFetchCount = podcastFetchCount ?? podcastCount

    let summedFetchCount = actArtworkFetchCount + actGenreFetchCount + actArtistFetchCount +
      actLocalArtistFetchCount +
      actAlbumFetchCount + actSongFetchCount + actPodcastEpisodeFetchCount + actRadioFetchCount +
      actMusicFolderFetchCount + actDirectoryFetchCount + actPodcastFetchCount

    let account = library.getAccount(info: TestAccountInfo.create1())
    let prefetch = library.getElements(account: account, prefetchIDs: prefetchIDs)
    XCTAssertEqual(actArtworkFetchCount, prefetch.prefetchedArtworkDict.count)
    XCTAssertEqual(
      actGenreFetchCount,
      prefetch.prefetchedGenreDict.count
    )
    XCTAssertEqual(actArtistFetchCount, prefetch.prefetchedArtistDict.count)
    XCTAssertEqual(
      actLocalArtistFetchCount,
      prefetch.prefetchedLocalArtistDict.count
    )
    XCTAssertEqual(actAlbumFetchCount, prefetch.prefetchedAlbumDict.count)
    XCTAssertEqual(actSongFetchCount, prefetch.prefetchedSongDict.count)
    XCTAssertEqual(
      actPodcastEpisodeFetchCount,
      prefetch.prefetchedPodcastEpisodeDict.count
    )
    XCTAssertEqual(actRadioFetchCount, prefetch.prefetchedRadioDict.count)
    XCTAssertEqual(
      actMusicFolderFetchCount,
      prefetch.prefetchedMusicFolderDict.count
    )
    XCTAssertEqual(actDirectoryFetchCount, prefetch.prefetchedDirectoryDict.count)
    XCTAssertEqual(actPodcastFetchCount, prefetch.prefetchedPodcastDict.count)
    // summed
    XCTAssertEqual(summedFetchCount, prefetch.counts)

    XCTAssertEqual(
      artworkLibraryCount ?? actArtworkFetchCount,
      library.getArtworkCount(for: account)
    )
    XCTAssertEqual(genreLibraryCount ?? actGenreFetchCount, library.getGenreCount(for: account))
    XCTAssertEqual(
      artistLibraryCount ?? (actArtistFetchCount + actLocalArtistFetchCount),
      library.getArtistCount(for: account)
    )
    XCTAssertEqual(albumLibraryCount ?? actAlbumFetchCount, library.getAlbumCount(for: account))
    XCTAssertEqual(songLibraryCount ?? actSongFetchCount, library.getSongCount(for: account))
    XCTAssertEqual(
      podcastEpisodeLibraryCount ?? actPodcastEpisodeFetchCount,
      library.getPodcastEpisodeCount(for: account)
    )
    XCTAssertEqual(radioLibraryCount ?? actRadioFetchCount, library.getRadioCount(for: account))
    XCTAssertEqual(
      musicFolderLibraryCount ?? actMusicFolderFetchCount,
      library.getMusicFolderCount(for: account)
    )
    XCTAssertEqual(
      directoryLibraryCount ?? actDirectoryFetchCount,
      library.getDirectoryCount(for: account)
    )
    XCTAssertEqual(
      podcastLibraryCount ?? actPodcastFetchCount,
      library.getPodcastCount(for: account)
    )
  }
}
