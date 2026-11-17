//
//  SongsFetchedResultsControllerTest.swift
//  AmperfyKitTests
//
//  Created by Jerome Mohm on 12.10.26.
//  Copyright (c) 2026 Jerome Mohm. All rights reserved.
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
class SongsFetchedResultsControllerTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var coreDataCompanion: CoreDataCompanion!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    coreDataCompanion = CoreDataCompanion(context: cdHelper.persistentContainer.viewContext)
  }

  func testSongsControllerUsesNoPersistentCache() {
    let sortTypes: [SongElementSortType] = [.name, .rating, .addedDate, .duration, .starredDate]
    for sortType in sortTypes {
      let songsController = SongsFetchedResultsController(
        coreDataCompanion: coreDataCompanion,
        account: account,
        sortType: sortType,
        isGroupedInAlphabeticSections: sortType.hasSectionTitles
      )
      XCTAssertNil(songsController.fetchResultsController.cacheName)
    }
  }

  func testTrackingControllerKeepsPersistentCache() {
    let albumsController = AlbumFetchedResultsController(
      coreDataCompanion: coreDataCompanion,
      account: account,
      sortType: .name,
      isGroupedInAlphabeticSections: true
    )
    XCTAssertNotNil(albumsController.fetchResultsController.cacheName)
  }

  func testTrackingControllerRefetchesAfterSearch() {
    let albumsController = AlbumFetchedResultsController(
      coreDataCompanion: coreDataCompanion,
      account: account,
      sortType: .name,
      isGroupedInAlphabeticSections: true
    )
    // a persistent cache left by an earlier run would be reused
    NSFetchedResultsController<NSFetchRequestResult>
      .deleteCache(withName: albumsController.fetchResultsController.cacheName)
    albumsController.fetch()
    albumsController.search(predicate: NSPredicate(format: "name contains[cd] %@", "a"))
    let album = library.createAlbum(account: account)
    album.name = "Inserted"
    albumsController.fetch()
    XCTAssertTrue(albumsController.fetchedObjects!.contains(album.managedObject))
  }

  func testFetchWithoutChangesReusesResults() {
    let songsController = createFetchedSongsController()
    let section = firstSection(of: songsController)
    XCTAssertNotNil(section)
    songsController.fetch()
    XCTAssertTrue(firstSection(of: songsController) === section)
  }

  func testFetchAfterSearchReusesResultsUntilChange() {
    let song = createUncachedSong(title: "Alpha")
    let songsController = createFetchedSongsController()
    let section = firstSection(of: songsController)
    let searchPredicate = NSPredicate(format: "title contains[cd] %@", "a")
    songsController.search(predicate: searchPredicate)
    songsController.fetch()
    XCTAssertTrue(firstSection(of: songsController) === section)
    songsController.search(predicate: searchPredicate)
    song.title = "Azure"
    coreDataCompanion.context.processPendingChanges()
    songsController.fetch()
    XCTAssertFalse(firstSection(of: songsController) === section)
  }

  func testPlaybackInformationChangeReusesResults() {
    let songsController = createFetchedSongsController()
    let section = firstSection(of: songsController)
    let song = Song(managedObject: songsController.fetchedObjects!.first!)
    song.countPlayed()
    song.playProgress += 30
    library.createPlaylist(account: account).append(playable: song)
    songsController.fetch()
    XCTAssertTrue(firstSection(of: songsController) === section)
  }

  func testSortKeyChangeRefetchesOnce() {
    let song = createUncachedSong(title: "Alpha")
    let songsController = createFetchedSongsController()
    let section = firstSection(of: songsController)
    song.title = "Azure"
    songsController.fetch()
    let refetchedSection = firstSection(of: songsController)
    XCTAssertFalse(refetchedSection === section)
    songsController.fetch()
    XCTAssertTrue(firstSection(of: songsController) === refetchedSection)
  }

  func testUnrelatedChangeKeepsPendingRefetch() {
    let songsController = createFetchedSongsController()
    let section = firstSection(of: songsController)
    let song = Song(managedObject: songsController.fetchedObjects!.first!)
    song.title = "Renamed"
    coreDataCompanion.context.processPendingChanges()
    song.playProgress += 30
    songsController.fetch()
    XCTAssertFalse(firstSection(of: songsController) === section)
  }

  func testInsertedSongIsFetched() {
    let songsController = createFetchedSongsController()
    let song = createUncachedSong(title: "Inserted")
    songsController.fetch()
    XCTAssertTrue(songsController.fetchedObjects!.contains(song.managedObject))
  }

  func testDeletedSongIsRemoved() {
    let song = createUncachedSong(title: "Deleted")
    let songsController = createFetchedSongsController()
    XCTAssertTrue(songsController.fetchedObjects!.contains(song.managedObject))
    coreDataCompanion.context.delete(song.managedObject)
    songsController.fetch()
    XCTAssertFalse(songsController.fetchedObjects!.contains(song.managedObject))
  }

  func testDeletedAlbumHidesItsUncachedSongs() {
    let album = library.createAlbum(account: account)
    let song = createUncachedSong(title: "On Album", album: album)
    let songsController = createFetchedSongsController()
    XCTAssertTrue(songsController.fetchedObjects!.contains(song.managedObject))
    album.remoteStatus = .deleted
    songsController.fetch()
    XCTAssertFalse(songsController.fetchedObjects!.contains(song.managedObject))
  }

  func testMergedBackgroundChangeIsFetched() {
    let songMO = createUncachedSong(title: "Synced").managedObject
    library.saveContext()
    let songsController = createFetchedSongsController()
    XCTAssertTrue(songsController.fetchedObjects!.contains(songMO))
    let songID = songMO.objectID
    saveInBackground { context in
      (context.object(with: songID) as! SongMO).size = 0
    }
    songsController.fetch()
    XCTAssertFalse(songsController.fetchedObjects!.contains(songMO))
  }

  func testMergedChangeOfUnloadedAlbumIsFetched() {
    let accountID = account.managedObject.objectID
    // saved without a merge, so the main context never loads them
    let backgroundContext = cdHelper.persistentContainer.newBackgroundContext()
    let (albumID, songID) = backgroundContext.performAndWait {
      let albumMO = AlbumMO(context: backgroundContext)
      albumMO.account = backgroundContext.object(with: accountID) as? AccountMO
      albumMO.remoteStatus = Int16(RemoteStatus.deleted.rawValue)
      let songMO = SongMO(context: backgroundContext)
      songMO.account = albumMO.account
      songMO.title = "Revived"
      songMO.size = 1
      songMO.album = albumMO
      try! backgroundContext.save()
      return (albumMO.objectID, songMO.objectID)
    }
    let songsController = createFetchedSongsController()
    XCTAssertFalse(songsController.fetchedObjects!.contains { $0.objectID == songID })
    saveInBackground { context in
      (context.object(with: albumID) as! AlbumMO)
        .remoteStatus = Int16(RemoteStatus.available.rawValue)
    }
    songsController.fetch()
    XCTAssertTrue(songsController.fetchedObjects!.contains { $0.objectID == songID })
  }

  func testUnrelatedMergeKeepsPendingRefetch() {
    let songMO = createUncachedSong(title: "Synced").managedObject
    library.saveContext()
    let songsController = createFetchedSongsController()
    let songID = songMO.objectID
    let accountID = account.managedObject.objectID
    saveInBackground { context in
      (context.object(with: songID) as! SongMO).size = 0
    }
    saveInBackground { context in
      ArtistMO(context: context).account = context.object(with: accountID) as? AccountMO
    }
    songsController.fetch()
    XCTAssertFalse(songsController.fetchedObjects!.contains(songMO))
  }

  func testUnrelatedMergeReusesResults() {
    let songsController = createFetchedSongsController()
    let section = firstSection(of: songsController)
    let accountID = account.managedObject.objectID
    saveInBackground { context in
      ArtistMO(context: context).account = context.object(with: accountID) as? AccountMO
    }
    songsController.fetch()
    XCTAssertTrue(firstSection(of: songsController) === section)
  }

  func testUnanalyzablePredicateAlwaysRefetches() {
    let fetchRequest = SongMO.alphabeticSortedFetchRequest
    fetchRequest.predicate = NSPredicate(value: true)
    let songsController = CachedFetchedResultsController(
      coreDataCompanion: coreDataCompanion,
      fetchRequest: fetchRequest,
      account: account,
      isGroupedInAlphabeticSections: true,
      keepAllResultsUpdated: false
    )
    songsController.fetch()
    let section = firstSection(of: songsController)
    songsController.fetch()
    XCTAssertFalse(firstSection(of: songsController) === section)
  }

  private func createUncachedSong(title: String, album: Album? = nil) -> Song {
    let song = library.createSong(account: account)
    song.title = title
    song.size = 1
    song.album = album
    return song
  }

  private func createFetchedSongsController() -> SongsFetchedResultsController {
    let songsController = SongsFetchedResultsController(
      coreDataCompanion: coreDataCompanion,
      account: account,
      sortType: .name,
      isGroupedInAlphabeticSections: true
    )
    songsController.fetch()
    return songsController
  }

  private func saveInBackground(_ changes: @Sendable (NSManagedObjectContext) -> ()) {
    let context = coreDataCompanion.context
    context.automaticallyMergesChangesFromParent = true
    let merged = expectation(
      forNotification: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
      object: context
    )
    let backgroundContext = cdHelper.persistentContainer.newBackgroundContext()
    backgroundContext.performAndWait {
      changes(backgroundContext)
      try! backgroundContext.save()
    }
    wait(for: [merged], timeout: 5)
  }

  // every performFetch creates new section infos
  private func firstSection(of songsController: BasicFetchedResultsController<SongMO>)
    -> AnyObject? {
    songsController.sections?.first as AnyObject?
  }
}
