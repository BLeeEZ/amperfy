//
//  AbstractSsTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 01.06.21.
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

@testable import AmperfyKit
import CoreData
import XCTest

@MainActor
class AbstractSsParserTest: XCTestCase {
  var context: NSManagedObjectContext!
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var xmlData: Data?
  var xmlErrorData: Data!
  var ssIdParserDelegate: SsIDsParserDelegate!
  var ssParserDelegate: SsXmlParser?

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    context = cdHelper.createInMemoryManagedObjectContext()
    cdHelper.clearContext(context: context)
    library = LibraryStorage(context: context)
    xmlErrorData = getTestFileData(name: "error_example_1")
    ssIdParserDelegate = SsIDsParserDelegate(performanceMonitor: MOCK_PerformanceMonitor())
  }

  override func tearDown() {}

  func testErrorParsing() {
    if Self.typeName == "AbstractSsParserTest" { return }

    createParserDelegate()
    guard let parserDelegate = ssParserDelegate else {
      return
    }
    let parser = XMLParser(data: xmlErrorData)
    parser.delegate = ssParserDelegate
    parser.parse()

    guard let error = parserDelegate.error else { XCTFail(); return }
    XCTAssertEqual(error.statusCode, 40)
    XCTAssertEqual(error.message, "Wrong username or password")
  }

  func testParsing() {
    reTestParsing()
  }

  func testParsingTwice() {
    reTestParsing()
    ssIdParserDelegate = SsIDsParserDelegate(performanceMonitor: MOCK_PerformanceMonitor())
    adjustmentsForSecondParsingDelegate()
    reTestParsing()
  }

  func reTestParsing() {
    if Self.typeName == "AbstractSsParserTest" { return }

    guard let data = xmlData, let ssIdParserDelegate else {
      return
    }
    let idParser = XMLParser(data: data)
    idParser.delegate = ssIdParserDelegate
    idParser.parse()
    XCTAssertNil(ssIdParserDelegate.error)

    createParserDelegate()
    guard let ssParserDelegate else { return }

    let parser = XMLParser(data: data)
    parser.delegate = ssParserDelegate
    parser.parse()
    XCTAssertNil(ssParserDelegate.error)
    checkCorrectParsing()
  }

  // Override in concrete test class if needed
  func createParserDelegate() {
    XCTFail()
  }

  // Override in concrete test class if needed
  func adjustmentsForSecondParsingDelegate() {}

  // Override in concrete test class
  func checkCorrectParsing() {
    XCTFail()
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

    XCTAssertEqual(artworkCount, ssIdParserDelegate.prefetchIDs.artworkIDs.count)
    XCTAssertEqual(genreIdCount, ssIdParserDelegate.prefetchIDs.genreIDs.count)
    XCTAssertEqual(genreNameCount, ssIdParserDelegate.prefetchIDs.genreNames.count)
    XCTAssertEqual(artistCount, ssIdParserDelegate.prefetchIDs.artistIDs.count)
    XCTAssertEqual(localArtistCount, ssIdParserDelegate.prefetchIDs.localArtistNames.count)
    XCTAssertEqual(albumCount, ssIdParserDelegate.prefetchIDs.albumIDs.count)
    XCTAssertEqual(songCount, ssIdParserDelegate.prefetchIDs.songIDs.count)
    XCTAssertEqual(podcastEpisodeCount, ssIdParserDelegate.prefetchIDs.podcastEpisodeIDs.count)
    XCTAssertEqual(radioCount, ssIdParserDelegate.prefetchIDs.radioIDs.count)
    XCTAssertEqual(musicFolderCount, ssIdParserDelegate.prefetchIDs.musicFolderIDs.count)
    XCTAssertEqual(directoryCount, ssIdParserDelegate.prefetchIDs.directoryIDs.count)
    XCTAssertEqual(podcastCount, ssIdParserDelegate.prefetchIDs.podcastIDs.count)
    // summed
    XCTAssertEqual(summedCount, ssIdParserDelegate.prefetchIDs.counts)

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

    let prefetch = library.getElements(prefetchIDs: ssIdParserDelegate.prefetchIDs)
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

    XCTAssertEqual(artworkLibraryCount ?? actArtworkFetchCount, library.artworkCount)
    XCTAssertEqual(genreLibraryCount ?? actGenreFetchCount, library.genreCount)
    XCTAssertEqual(
      artistLibraryCount ?? (actArtistFetchCount + actLocalArtistFetchCount),
      library.artistCount
    )
    XCTAssertEqual(albumLibraryCount ?? actAlbumFetchCount, library.albumCount)
    XCTAssertEqual(songLibraryCount ?? actSongFetchCount, library.songCount)
    XCTAssertEqual(
      podcastEpisodeLibraryCount ?? actPodcastEpisodeFetchCount,
      library.podcastEpisodeCount
    )
    XCTAssertEqual(radioLibraryCount ?? actRadioFetchCount, library.radioCount)
    XCTAssertEqual(musicFolderLibraryCount ?? actMusicFolderFetchCount, library.musicFolderCount)
    XCTAssertEqual(directoryLibraryCount ?? actDirectoryFetchCount, library.directoryCount)
    XCTAssertEqual(podcastLibraryCount ?? actPodcastFetchCount, library.podcastCount)
  }
}
