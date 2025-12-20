//
//  CoreDataSeeder.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 30.12.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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
import Foundation

class CoreDataSeeder {
  let accounts = [
    (
      serverHash: TestAccountInfo.test1ServerHash,
      userHash: TestAccountInfo.test1UserHash,
      apiType: BackenApiType.ampache.rawValue
    ),
    (
      serverHash: TestAccountInfo.test2ServerHash,
      userHash: TestAccountInfo.test2UserHash,
      apiType: BackenApiType.subsonic.rawValue
    ),
  ]
  let artists = [
    (accountIndex: 0, id: "4", name: "My Dream"),
    (accountIndex: 0, id: "RopLcTz92", name: "She or He"),
    (accountIndex: 0, id: "93", name: "Bang!"),
    (accountIndex: 1, id: "4", name: "My Dream acc2"),
    (accountIndex: 1, id: "Acc2Artist", name: "Acc 2 Artist"),
  ]
  let albums = [
    (accountIndex: 0, id: "12", artistId: "4", name: "High Voltage", year: 2018),
    (accountIndex: 0, id: "34", artistId: "RopLcTz92", name: "Du Hast", year: 1987),
    (accountIndex: 0, id: "59", artistId: "93", name: "Dreams", year: 2002),
    (accountIndex: 0, id: "6BTR0", artistId: "93", name: "Let it go", year: 2007),
    (accountIndex: 1, id: "12", artistId: "4", name: "High Voltage acc2", year: 2018),
    (accountIndex: 1, id: "acc2", artistId: "acc2Album", name: "Dreams for acc 2", year: 2002),
  ]
  let songs = [
    (
      accountIndex: 0,
      id: "3",
      artistId: "4",
      albumId: "12",
      track: 3,
      isCached: false,
      title: "go home",
      url: "www.blub.de/ahhh"
    ),
    (
      accountIndex: 0,
      id: "5",
      artistId: "4",
      albumId: "12",
      track: 4,
      isCached: false,
      title: "well",
      url: "www.blub.de/ahhh2"
    ),
    (
      accountIndex: 0,
      id: "10T",
      artistId: "4",
      albumId: "12",
      track: 8,
      isCached: false,
      title: "maybe alright",
      url: "www.blub.de/dd"
    ),
    (
      accountIndex: 0,
      id: "19",
      artistId: "RopLcTz92",
      albumId: "34",
      track: 0,
      isCached: false,
      title: "baby",
      url: "www.blub.de/dddtd"
    ),
    (
      accountIndex: 0,
      id: "36",
      artistId: "RopLcTz92",
      albumId: "34",
      track: 1,
      isCached: true,
      title: "son",
      url: "www.blub.de/dddtdiuz"
    ),
    (
      accountIndex: 0,
      id: "38",
      artistId: "93",
      albumId: "59",
      track: 4,
      isCached: true,
      title: "oh no",
      url: "www.blub.de/dddtd23iuz"
    ),
    (
      accountIndex: 0,
      id: "41",
      artistId: "93",
      albumId: "59",
      track: 5,
      isCached: true,
      title: "please",
      url: "www.blub.de/dddtd233iuz"
    ),
    (
      accountIndex: 0,
      id: "54",
      artistId: "93",
      albumId: "6BTR0",
      track: 1,
      isCached: true,
      title: "see",
      url: "www.blub.de/ddf"
    ),
    (
      accountIndex: 0,
      id: "55",
      artistId: "93",
      albumId: "6BTR0",
      track: 2,
      isCached: true,
      title: "feel",
      url: "www.blub.de/654"
    ),
    (
      accountIndex: 0,
      id: "56",
      artistId: "93",
      albumId: "6BTR0",
      track: 3,
      isCached: true,
      title: "house",
      url: "www.blub.de/trd"
    ),
    (
      accountIndex: 0,
      id: "57",
      artistId: "93",
      albumId: "6BTR0",
      track: 4,
      isCached: true,
      title: "car",
      url: "www.blub.de/jhrf"
    ),
    (
      accountIndex: 0,
      id: "59",
      artistId: "asd",
      albumId: "6BTR0",
      track: 7,
      isCached: true,
      title: "vllll",
      url: "www.blub.de/jads324hrf"
    ),
    (
      accountIndex: 0,
      id: "99",
      artistId: "asd",
      albumId: "6BTR0",
      track: 8,
      isCached: true,
      title: "cllll",
      url: "www.blub.de/jds32s4hrf"
    ),
    (
      accountIndex: 0,
      id: "5a9",
      artistId: "asd",
      albumId: "6BTR0",
      track: 10,
      isCached: true,
      title: "allll",
      url: "www.blub.de/sjds324hrf"
    ),
    (
      accountIndex: 0,
      id: "59e",
      artistId: "asd",
      albumId: "6BTR0",
      track: 158,
      isCached: true,
      title: "3llll",
      url: "www.blub.de/gjds324hrf"
    ),
    (
      accountIndex: 0,
      id: "5e9lll",
      artistId: "asd",
      albumId: "6BTR0",
      track: 198,
      isCached: true,
      title: "3lldll",
      url: "www.blub.de/aajds324hrf"
    ),
    // Account 2
    (
      accountIndex: 1,
      id: "3",
      artistId: "4",
      albumId: "12",
      track: 3,
      isCached: false,
      title: "go home acc2",
      url: "www.blub.de/ahhh"
    ),
    (
      accountIndex: 1,
      id: "5",
      artistId: "4",
      albumId: "12",
      track: 4,
      isCached: false,
      title: "well acc2",
      url: "www.blub.de/ahhh2"
    ),
    (
      accountIndex: 1,
      id: "10T",
      artistId: "4",
      albumId: "12",
      track: 8,
      isCached: false,
      title: "maybe alright acc2",
      url: "www.blub.de/dd"
    ),
    (
      accountIndex: 1,
      id: "acc2Song",
      artistId: "Acc2Artist",
      albumId: "acc2",
      track: 0,
      isCached: false,
      title: "baby acc2",
      url: "www.blub.de/dddtd"
    ),
  ]
  let playlists = [
    (accountIndex: 0, id: "3", name: "With One Cached", songIds: ["3", "5", "10T", "36", "19"]),
    (
      accountIndex: 0,
      id: "9",
      name: "With Three Cached",
      songIds: ["3", "5", "10T", "36", "19", "10T", "38", "5", "41"]
    ),
    (accountIndex: 0, id: "dRsa11", name: "No Cached", songIds: ["3", "10T", "19"]),
    (accountIndex: 0, id: "d23884", name: "All Cached", songIds: ["99", "5a9", "59e", "5e9lll"]),
    (
      accountIndex: 1,
      id: "3",
      name: "With One Cached for Acc2",
      songIds: ["3", "5", "10T", "acc2Song"]
    ),
    (
      accountIndex: 1,
      id: "acc2playlist",
      name: "With Three Cached",
      songIds: ["acc2Song", "5", "10T", "acc2Song"]
    ),
  ]
  let radios = [
    (
      accountIndex: 0,
      id: "12",
      title: "GoGo Radio",
      url: "www.blub.de/aaa",
      siteUrl: "www.blub.de/ddf"
    ),
    (
      accountIndex: 0,
      id: "36",
      title: "Wau",
      url: "www.blub.de/fjjuf",
      siteUrl: "www.blub.de/23452"
    ),
    (accountIndex: 0, id: "dRsa11", title: "Invalid Url", url: "", siteUrl: "www.blub.de/daeeaa"),
    (
      accountIndex: 0,
      id: "dFrDF",
      title: "Radio Channel 2",
      url: "www.blub.de/ffhnnnza",
      siteUrl: "www.blub.de/44re4t"
    ),
    (
      accountIndex: 1,
      id: "12",
      title: "GoGo Radio Acc 2",
      url: "www.blub.de/aaa",
      siteUrl: "www.blub.de/ddf"
    ),
    (
      accountIndex: 1,
      id: "3445",
      title: "WauWau",
      url: "www.blub.de/fjjssuf",
      siteUrl: "www.blub.de/2s3452"
    ),
  ]

  func seed(context: NSManagedObjectContext) {
    let library = LibraryStorage(context: context)

    let accs = accounts.compactMap {
      library.createAccount(info: AccountInfo(
        serverHash: $0.serverHash,
        userHash: $0.userHash,
        apiType: BackenApiType(rawValue: $0.apiType)!
      ))
    }

    for artistSeed in artists {
      let artist = library.createArtist(account: accs[artistSeed.accountIndex])
      artist.id = artistSeed.id
      artist.name = artistSeed.name
    }

    for albumSeed in albums {
      let album = library.createAlbum(account: accs[albumSeed.accountIndex])
      album.id = albumSeed.id
      album.name = albumSeed.name
      album.year = albumSeed.year
      let artist = library.getArtist(for: accs[albumSeed.accountIndex], id: albumSeed.artistId)
      album.artist = artist
    }

    let relFilePath = URL(string: "testSong")!
    let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)!
    try! CacheFileManager.shared.writeDataExcludedFromBackup(
      data: Data(base64Encoded: "Test", options: .ignoreUnknownCharacters)!,
      to: absFilePath, accountInfo: nil
    )

    for songSeed in songs {
      let song = library.createSong(account: accs[songSeed.accountIndex])
      song.id = songSeed.id
      song.title = songSeed.title
      song.track = songSeed.track
      song.url = songSeed.url
      let artist = library.getArtist(for: accs[songSeed.accountIndex], id: songSeed.artistId)
      song.artist = artist
      let album = library.getAlbum(
        for: accs[songSeed.accountIndex],
        id: songSeed.albumId,
        isDetailFaultResolution: true
      )
      song.album = album
      if songSeed.isCached {
        song.relFilePath = relFilePath
      }
    }

    for playlistSeed in playlists {
      let playlist = library.createPlaylist(account: accs[playlistSeed.accountIndex])
      playlist.id = playlistSeed.id
      playlist.name = playlistSeed.name
      for songId in playlistSeed.songIds {
        if let song = library.getSong(for: accs[playlistSeed.accountIndex], id: songId) {
          playlist.append(playable: song)
        } else {
          let logMsg = "Song id <" + String(songId) + "> for playlist id <" +
            String(playlistSeed.id) + "> could not be found"
          print(logMsg)
        }
      }
    }

    for radioSeed in radios {
      let radio = library.createRadio(account: accs[radioSeed.accountIndex])
      radio.id = radioSeed.id
      radio.title = radioSeed.title
      radio.url = radioSeed.url
      radio.siteURL = URL(string: radioSeed.siteUrl)
    }

    library.saveContext()
  }
}
