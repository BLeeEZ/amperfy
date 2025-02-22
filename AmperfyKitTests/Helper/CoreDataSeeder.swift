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
  let artists = [
    (id: "4", name: "My Dream"),
    (id: "RopLcTz92", name: "She or He"),
    (id: "93", name: "Bang!"),
  ]
  let albums = [
    (id: "12", artistId: "4", name: "High Voltage", year: 2018),
    (id: "34", artistId: "RopLcTz92", name: "Du Hast", year: 1987),
    (id: "59", artistId: "93", name: "Dreams", year: 2002),
    (id: "6BTR0", artistId: "93", name: "Let it go", year: 2007),
  ]
  let songs = [
    (
      id: "3",
      artistId: "4",
      albumId: "12",
      track: 3,
      isCached: false,
      title: "go home",
      url: "www.blub.de/ahhh"
    ),
    (
      id: "5",
      artistId: "4",
      albumId: "12",
      track: 4,
      isCached: false,
      title: "well",
      url: "www.blub.de/ahhh2"
    ),
    (
      id: "10T",
      artistId: "4",
      albumId: "12",
      track: 8,
      isCached: false,
      title: "maybe alright",
      url: "www.blub.de/dd"
    ),
    (
      id: "19",
      artistId: "RopLcTz92",
      albumId: "34",
      track: 0,
      isCached: false,
      title: "baby",
      url: "www.blub.de/dddtd"
    ),
    (
      id: "36",
      artistId: "RopLcTz92",
      albumId: "34",
      track: 1,
      isCached: true,
      title: "son",
      url: "www.blub.de/dddtdiuz"
    ),
    (
      id: "38",
      artistId: "93",
      albumId: "59",
      track: 4,
      isCached: true,
      title: "oh no",
      url: "www.blub.de/dddtd23iuz"
    ),
    (
      id: "41",
      artistId: "93",
      albumId: "59",
      track: 5,
      isCached: true,
      title: "please",
      url: "www.blub.de/dddtd233iuz"
    ),
    (
      id: "54",
      artistId: "93",
      albumId: "6BTR0",
      track: 1,
      isCached: true,
      title: "see",
      url: "www.blub.de/ddf"
    ),
    (
      id: "55",
      artistId: "93",
      albumId: "6BTR0",
      track: 2,
      isCached: true,
      title: "feel",
      url: "www.blub.de/654"
    ),
    (
      id: "56",
      artistId: "93",
      albumId: "6BTR0",
      track: 3,
      isCached: true,
      title: "house",
      url: "www.blub.de/trd"
    ),
    (
      id: "57",
      artistId: "93",
      albumId: "6BTR0",
      track: 4,
      isCached: true,
      title: "car",
      url: "www.blub.de/jhrf"
    ),
    (
      id: "59",
      artistId: "asd",
      albumId: "6BTR0",
      track: 7,
      isCached: true,
      title: "vllll",
      url: "www.blub.de/jads324hrf"
    ),
    (
      id: "99",
      artistId: "asd",
      albumId: "6BTR0",
      track: 8,
      isCached: true,
      title: "cllll",
      url: "www.blub.de/jds32s4hrf"
    ),
    (
      id: "5a9",
      artistId: "asd",
      albumId: "6BTR0",
      track: 10,
      isCached: true,
      title: "allll",
      url: "www.blub.de/sjds324hrf"
    ),
    (
      id: "59e",
      artistId: "asd",
      albumId: "6BTR0",
      track: 158,
      isCached: true,
      title: "3llll",
      url: "www.blub.de/gjds324hrf"
    ),
    (
      id: "5e9lll",
      artistId: "asd",
      albumId: "6BTR0",
      track: 198,
      isCached: true,
      title: "3lldll",
      url: "www.blub.de/aajds324hrf"
    ),
  ]
  let playlists = [
    (id: "3", name: "With One Cached", songIds: ["3", "5", "10T", "36", "19"]),
    (
      id: "9",
      name: "With Three Cached",
      songIds: ["3", "5", "10T", "36", "19", "10T", "38", "5", "41"]
    ),
    (id: "dRsa11", name: "No Cached", songIds: ["3", "10T", "19"]),
    (id: "d23884", name: "All Cached", songIds: ["99", "5a9", "59e", "5e9lll"]),
  ]
  let radios = [
    (id: "12", title: "GoGo Radio", url: "www.blub.de/aaa", siteUrl: "www.blub.de/ddf"),
    (id: "36", title: "Wau", url: "www.blub.de/fjjuf", siteUrl: "www.blub.de/23452"),
    (id: "dRsa11", title: "Invalid Url", url: "", siteUrl: "www.blub.de/daeeaa"),
    (
      id: "dFrDF",
      title: "Radio Channel 2",
      url: "www.blub.de/ffhnnnza",
      siteUrl: "www.blub.de/44re4t"
    ),
  ]

  func seed(context: NSManagedObjectContext) {
    let library = LibraryStorage(context: context)

    for artistSeed in artists {
      let artist = library.createArtist()
      artist.id = artistSeed.id
      artist.name = artistSeed.name
    }

    for albumSeed in albums {
      let album = library.createAlbum()
      album.id = albumSeed.id
      album.name = albumSeed.name
      album.year = albumSeed.year
      let artist = library.getArtist(id: albumSeed.artistId)
      album.artist = artist
    }

    let relFilePath = URL(string: "testSong")!
    let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)!
    try! CacheFileManager.shared.writeDataExcludedFromBackup(
      data: Data(base64Encoded: "Test", options: .ignoreUnknownCharacters)!,
      to: absFilePath
    )

    for songSeed in songs {
      let song = library.createSong()
      song.id = songSeed.id
      song.title = songSeed.title
      song.track = songSeed.track
      song.url = songSeed.url
      let artist = library.getArtist(id: songSeed.artistId)
      song.artist = artist
      let album = library.getAlbum(id: songSeed.albumId, isDetailFaultResolution: true)
      song.album = album
      if songSeed.isCached {
        song.relFilePath = relFilePath
      }
    }

    for playlistSeed in playlists {
      let playlist = library.createPlaylist()
      playlist.id = playlistSeed.id
      playlist.name = playlistSeed.name
      for songId in playlistSeed.songIds {
        if let song = library.getSong(id: songId) {
          playlist.append(playable: song)
        } else {
          let logMsg = "Song id <" + String(songId) + "> for playlist id <" +
            String(playlistSeed.id) + "> could not be found"
          print(logMsg)
        }
      }
    }

    for radioSeed in radios {
      let radio = library.createRadio()
      radio.id = radioSeed.id
      radio.title = radioSeed.title
      radio.url = radioSeed.url
      radio.siteURL = URL(string: radioSeed.siteUrl)
    }

    library.saveContext()
  }
}
