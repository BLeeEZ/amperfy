//
//  ArtistTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 01.01.20.
//  Copyright (c) 2020 Maximilian Bauer. All rights reserved.
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
import XCTest

@MainActor
class ArtistTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var testArtist: Artist!
  let testId = "10089"

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    testArtist = library.createArtist(account: account)
    testArtist.id = testId
  }

  override func tearDown() {}

  func testCreation() {
    let artist = library.createArtist(account: account)
    XCTAssertEqual(artist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.id, "")
    XCTAssertEqual(artist.identifier, "Unknown Artist")
    XCTAssertEqual(artist.name, "Unknown Artist")
    XCTAssertEqual(artist.songs.count, 0)
    XCTAssertEqual(artist.songCount, 0)
    XCTAssertFalse(artist.playables.hasCachedItems)
    XCTAssertEqual(artist.albums.count, 0)
    XCTAssertEqual(artist.albumCount, 0)
    XCTAssertNil(artist.artwork)
    XCTAssertNil(
      artist.imagePath(setting: .serverArtworkOnly)
    )
    XCTAssertEqual(
      artist.getDefaultArtworkType(),
      .artist
    )
  }

  func testName() {
    let testTitle = "Alright"
    testArtist.name = testTitle
    XCTAssertEqual(testArtist.name, testTitle)
    XCTAssertEqual(testArtist.identifier, testTitle)
    library.saveContext()
    guard let artistFetched = library.getArtist(for: account, id: testId) else { XCTFail(); return }
    XCTAssertEqual(artistFetched.name, testTitle)
    XCTAssertEqual(artistFetched.identifier, testTitle)
  }

  func testSongs() {
    guard let artist3Items = library.getArtist(for: account, id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    XCTAssertEqual(artist3Items.songs.count, 3)
    XCTAssertEqual(artist3Items.songCount, 3)
    guard let artist2Items = library.getArtist(for: account, id: cdHelper.seeder.artists[1].id)
    else { XCTFail(); return }
    XCTAssertEqual(artist2Items.songs.count, 2)
    XCTAssertEqual(artist2Items.songCount, 2)
  }

  func testHasCachedSongs() {
    guard let artistNoCached = library.getArtist(for: account, id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    XCTAssertFalse(artistNoCached.playables.hasCachedItems)
    guard let artistTwoCached = library.getArtist(for: account, id: cdHelper.seeder.artists[2].id)
    else { XCTFail(); return }
    XCTAssertTrue(artistTwoCached.playables.hasCachedItems)
  }

  func testAlbums() {
    guard let artist1Items = library.getArtist(for: account, id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    XCTAssertEqual(artist1Items.albums.count, 1)
    XCTAssertEqual(artist1Items.albumCount, 1)
    guard let artist2Items = library.getArtist(for: account, id: cdHelper.seeder.artists[2].id)
    else { XCTFail(); return }
    XCTAssertEqual(artist2Items.albums.count, 2)
    XCTAssertEqual(artist2Items.albumCount, 2)
  }

  func testArtworkAndImage() {
    let testData = UIImage.getGeneratedArtwork(theme: .blue, artworkType: .artist).pngData()!
    let relFilePath = URL(string: "testArtwork")!
    let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)!
    try! CacheFileManager.shared.writeDataExcludedFromBackup(
      data: testData,
      to: absFilePath,
      accountInfo: account.info
    )
    testArtist.artwork = library.createArtwork(account: account)
    testArtist.artwork?.relFilePath = relFilePath
    testArtist.artwork?.status = .CustomImage
    XCTAssertEqual(testArtist.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(testArtist.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertNotNil(testArtist.artwork?.imagePath)
    XCTAssertEqual(testArtist.imagePath(setting: .serverArtworkOnly), absFilePath.path)
    library.saveContext()
    guard let artistFetched = library.getArtist(for: account, id: testId) else { XCTFail(); return }
    XCTAssertNotNil(artistFetched.artwork?.imagePath)
    XCTAssertEqual(artistFetched.imagePath(setting: .serverArtworkOnly), absFilePath.path)
    try! CacheFileManager.shared.removeItem(at: absFilePath, accountInfo: account.info)
  }

  // MARK: - Related album/song counts

  /// The count helpers must return the same numbers as the fetch based functions.
  private func assertRelatedCountsMatchFetch(
    _ artist: Artist,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard let account = artist.account else {
      XCTFail("artist without account", file: file, line: line)
      return
    }
    XCTAssertEqual(
      library.getAlbumsCount(for: account, whichContainsSongsWithArtist: artist),
      library.getAlbums(for: account, whichContainsSongsWithArtist: artist).count,
      "albums of artist \(artist.id)",
      file: file,
      line: line
    )
    XCTAssertEqual(
      library.getSongsCount(for: account, whichContainsSongsWithArtist: artist),
      library.getSongs(for: account, whichContainsSongsWithArtist: artist).count,
      "songs of artist \(artist.id)",
      file: file,
      line: line
    )
  }

  private func countInfo(
    _ artist: Artist,
    type: DetailType,
    filter: ArtistCategoryFilter
  )
    -> [String] {
    var details = DetailInfoType(type: type, settings: AmperfySettings())
    details.artistFilterSetting = filter
    return artist.infoDetails(for: nil, details: details).filter {
      $0.hasSuffix(" Album") || $0.hasSuffix(" Albums") || $0.hasSuffix(" Song") ||
        $0.hasSuffix(" Songs")
    }
  }

  @discardableResult
  private func createSong(
    id: String,
    artist: Artist?,
    album: Album?,
    size: Int = 1000
  )
    -> Song {
    let song = library.createSong(account: account)
    song.id = id
    song.size = size
    song.artist = artist
    song.album = album
    return song
  }

  func testRelatedCountsMatchFetchForSeededArtists() {
    let account2 = library.getAccount(info: TestAccountInfo.create2())
    let artists = library.getArtists(for: account) + library.getArtists(for: account2)
    XCTAssertGreaterThanOrEqual(artists.count, 5)
    for artist in artists {
      assertRelatedCountsMatchFetch(artist)
    }
  }

  func testRelatedCountsSeededArtists() {
    // "93": own albums "59" and "6BTR0"; 6 own cached songs + 5 cached songs without artist on "6BTR0"
    guard let artist93 = library.getArtist(for: account, id: "93") else { XCTFail(); return }
    XCTAssertEqual(library.getAlbumsCount(for: account, whichContainsSongsWithArtist: artist93), 2)
    XCTAssertEqual(library.getSongsCount(for: account, whichContainsSongsWithArtist: artist93), 11)
    XCTAssertEqual(artist93.songCount, 6)
    // "Acc2Artist": no own album, but a song on an album without album artist
    let account2 = library.getAccount(info: TestAccountInfo.create2())
    guard let acc2Artist = library.getArtist(for: account2, id: "Acc2Artist")
    else { XCTFail(); return }
    XCTAssertEqual(acc2Artist.albumCount, 0)
    XCTAssertEqual(
      library.getAlbumsCount(for: account2, whichContainsSongsWithArtist: acc2Artist),
      1
    )
    // its only song is neither cached nor has a size
    XCTAssertEqual(
      library.getSongsCount(for: account2, whichContainsSongsWithArtist: acc2Artist),
      0
    )
  }

  func testRelatedCountsCompilationAndFeaturedArtists() {
    guard let albumArtist4 = library.getArtist(for: account, id: "4"),
          let album12 = library.getAlbum(for: account, id: "12", isDetailFaultResolution: true)
    else { XCTFail(); return }
    let variousArtists = library.createArtist(account: account)
    variousArtists.id = "va"
    let artistA = library.createArtist(account: account)
    artistA.id = "a"
    let artistB = library.createArtist(account: account)
    artistB.id = "b"
    let compilation = library.createAlbum(account: account)
    compilation.id = "comp"
    compilation.artist = variousArtists
    let deletedAlbum = library.createAlbum(account: account)
    deletedAlbum.id = "del"
    deletedAlbum.artist = artistA

    createSong(id: "a1", artist: artistA, album: compilation)
    createSong(id: "b1", artist: artistB, album: compilation)
    createSong(id: "n1", artist: nil, album: compilation)
    createSong(id: "b2", artist: artistB, album: album12) // featured on "4"'s album
    createSong(id: "a2", artist: artistA, album: nil) // song without album
    let albumlessDeleted = createSong(id: "a3", artist: artistA, album: nil)
    albumlessDeleted.remoteStatus = .deleted
    createSong(id: "a4", artist: artistA, album: deletedAlbum)
    let cachedOnDeletedAlbum = createSong(id: "a5", artist: artistA, album: deletedAlbum)
    cachedOnDeletedAlbum.relFilePath = URL(string: "testSong")!
    createSong(id: "a6", artist: artistA, album: compilation, size: 0) // neither size nor cached
    deletedAlbum.markAsRemoteDeleted()
    library.saveContext()

    for artist in [variousArtists, artistA, artistB, albumArtist4] {
      assertRelatedCountsMatchFetch(artist)
    }
    // albums: own albums + albums with own songs, remote deleted albums included
    XCTAssertEqual(library.getAlbumsCount(for: account, whichContainsSongsWithArtist: artistA), 2)
    XCTAssertEqual(library.getAlbumsCount(for: account, whichContainsSongsWithArtist: artistB), 2)
    XCTAssertEqual(
      library.getAlbumsCount(for: account, whichContainsSongsWithArtist: variousArtists),
      1
    )
    XCTAssertEqual(artistB.albumCount, 0)
    // songs: a1, a2, a5 (cached on a remote deleted album)
    XCTAssertEqual(library.getSongsCount(for: account, whichContainsSongsWithArtist: artistA), 3)
    // songs of all artists on the compilation (a1, b1, n1)
    XCTAssertEqual(
      library.getSongsCount(for: account, whichContainsSongsWithArtist: variousArtists),
      3
    )
    XCTAssertEqual(variousArtists.songCount, 0)
    // seeded songs of "4" have no size and are not cached, the featured song counts
    XCTAssertEqual(
      library.getSongsCount(for: account, whichContainsSongsWithArtist: albumArtist4),
      1
    )
  }

  func testInfoDetailsShortAndLongShowSameCounts() {
    let variousArtists = library.createArtist(account: account)
    variousArtists.id = "va"
    let artistA = library.createArtist(account: account)
    artistA.id = "a"
    let compilation = library.createAlbum(account: account)
    compilation.id = "comp"
    compilation.artist = variousArtists
    createSong(id: "a1", artist: artistA, album: compilation)
    createSong(id: "n1", artist: nil, album: compilation)
    library.saveContext()

    for filter in [ArtistCategoryFilter.albumArtists, .all] {
      for artist in library.getArtists(for: account) {
        XCTAssertEqual(
          countInfo(artist, type: .short, filter: filter),
          countInfo(artist, type: .long, filter: filter),
          "artist \(artist.id) filter \(filter)"
        )
      }
    }
    XCTAssertEqual(countInfo(artistA, type: .short, filter: .albumArtists), ["1 Album", "1 Song"])
    XCTAssertEqual(
      countInfo(variousArtists, type: .short, filter: .albumArtists),
      ["1 Album", "2 Songs"]
    )
    // "All" keeps showing the stored song count (own songs only)
    XCTAssertEqual(countInfo(variousArtists, type: .short, filter: .all), ["1 Album"])
  }
}
