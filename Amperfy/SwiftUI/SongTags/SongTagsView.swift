//
//  SongTagsView.swift
//  Amperfy
//
//  Created by Amperfy on 25.05.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

import AmperfyKit
import Foundation
import SwiftUI

// MARK: - SongTagKey

enum SongTagKey: String, CaseIterable {
  case title
  case artists
  case albumArtists
  case album
  case genre
  case genres
  case trackNumber
  case discNumber
  case year
  case duration
  case bpm
  case bitrate
  case bitDepth
  case samplingRate
  case channelCount
  case contentType
  case fileSize
  case dateAdded
  case rating
  case favorite
  case explicitStatus
  case comment
  case sortName
  case musicBrainzId
  case isrc
  case moods
  case groupings
  case contributors
  case displayComposer
  case replayGainTrack
  case replayGainAlbum

  var displayName: String {
    switch self {
    case .title: return "Title"
    case .artists: return "Artists"
    case .albumArtists: return "Album Artists"
    case .album: return "Album"
    case .genre: return "Genre"
    case .genres: return "Genres (Multi)"
    case .trackNumber: return "Track"
    case .discNumber: return "Disc"
    case .year: return "Year"
    case .duration: return "Duration"
    case .bpm: return "BPM"
    case .bitrate: return "Bitrate"
    case .bitDepth: return "Bit Depth"
    case .samplingRate: return "Sample Rate"
    case .channelCount: return "Channels"
    case .contentType: return "Format"
    case .fileSize: return "File Size"
    case .dateAdded: return "Date Added"
    case .rating: return "Rating"
    case .favorite: return "Favorite"
    case .explicitStatus: return "Explicit"
    case .comment: return "Comment"
    case .sortName: return "Sort Name"
    case .musicBrainzId: return "MusicBrainz ID"
    case .isrc: return "ISRC"
    case .moods: return "Moods"
    case .groupings: return "Groupings"
    case .contributors: return "Contributors"
    case .displayComposer: return "Composer"
    case .replayGainTrack: return "Replay Gain (Track)"
    case .replayGainAlbum: return "Replay Gain (Album)"
    }
  }

  func value(for song: Song) -> String? {
    // Guard against invalid/deleted Core Data objects — accessing their properties
    // throws an uncatchable ObjC exception if the managed object context is gone.
    guard song.managedObject.managedObjectContext != nil else { return nil }
    switch self {
    case .title:
      return song.title.isEmpty ? nil : song.title
    case .artists:
      let v = song.artistsString ?? song.artist?.name
      return (v?.isEmpty == false) ? v : nil
    case .albumArtists:
      let v = song.albumArtistsString ?? song.displayAlbumArtist
      return (v?.isEmpty == false) ? v : nil
    case .album:
      return song.album?.name
    case .genre:
      return song.genre?.name
    case .genres:
      let v = song.genresList
      return (v?.isEmpty == false) ? v : nil
    case .trackNumber:
      return song.track > 0 ? String(song.track) : nil
    case .discNumber:
      let d = song.disk?.trimmingCharacters(in: .whitespacesAndNewlines)
      return (d?.isEmpty == false) ? d : nil
    case .year:
      return song.year > 0 ? String(song.year) : nil
    case .duration:
      return song.duration > 0 ? song.duration.asDurationString : nil
    case .bpm:
      return song.bpm > 0 ? "\(song.bpm) BPM" : nil
    case .bitrate:
      return song.bitrate > 0 ? "\(song.bitrate / 1000) kbps" : nil
    case .bitDepth:
      return song.bitDepth > 0 ? "\(song.bitDepth)-bit" : nil
    case .samplingRate:
      guard song.samplingRate > 0 else { return nil }
      let khz = Double(song.samplingRate) / 1000.0
      return String(format: "%.1f kHz", khz)
    case .channelCount:
      switch song.channelCount {
      case 1: return "Mono"
      case 2: return "Stereo"
      case let c where c > 2: return "\(c) channels"
      default: return nil
      }
    case .contentType:
      let ct = song.contentType?.trimmingCharacters(in: .whitespacesAndNewlines)
      return (ct?.isEmpty == false) ? ct : nil
    case .fileSize:
      guard song.size > 0 else { return nil }
      return ByteCountFormatter.string(fromByteCount: Int64(song.size), countStyle: .file)
    case .dateAdded:
      guard let date = song.addedDate else { return nil }
      return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
    case .rating:
      return song.rating > 0 ? "\(song.rating) / 5" : nil
    case .favorite:
      return song.isFavorite ? "Yes" : nil
    case .explicitStatus:
      let v = song.explicitStatus
      return (v?.isEmpty == false) ? v : nil
    case .comment:
      let v = song.comment
      return (v?.isEmpty == false) ? v : nil
    case .sortName:
      let v = song.sortName
      return (v?.isEmpty == false) ? v : nil
    case .musicBrainzId:
      let v = song.musicBrainzId
      return (v?.isEmpty == false) ? v : nil
    case .isrc:
      let v = song.isrcList
      return (v?.isEmpty == false) ? v : nil
    case .moods:
      let v = song.moodsList
      return (v?.isEmpty == false) ? v : nil
    case .groupings:
      let v = song.groupingsList
      return (v?.isEmpty == false) ? v : nil
    case .contributors:
      let v = song.contributorsString
      return (v?.isEmpty == false) ? v : nil
    case .displayComposer:
      let v = song.displayComposer
      return (v?.isEmpty == false) ? v : nil
    case .replayGainTrack:
      guard song.replayGainTrackGain != 0 else { return nil }
      return String(format: "%.2f dB", song.replayGainTrackGain)
    case .replayGainAlbum:
      guard song.replayGainAlbumGain != 0 else { return nil }
      return String(format: "%.2f dB", song.replayGainAlbumGain)
    }
  }
}

// MARK: - TagVisibilityStore

class TagVisibilityStore: ObservableObject {
  @Published
  var hiddenKeys: Set<String>

  init() {
    self.hiddenKeys = Set(
      (UIApplication.shared.delegate as! AppDelegate).storage.settings.user.hiddenSongTagKeys
    )
  }

  func setVisible(_ key: SongTagKey, visible: Bool) {
    if visible {
      hiddenKeys.remove(key.rawValue)
    } else {
      hiddenKeys.insert(key.rawValue)
    }
    persist()
  }

  func showAll() {
    hiddenKeys = []
    persist()
  }

  private func persist() {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var userSettings = appDelegate.storage.settings.user
    userSettings.hiddenSongTagKeys = Array(hiddenKeys)
    appDelegate.storage.settings.user = userSettings
  }
}

// MARK: - SongTagsView

struct SongTagsView: View {
  let song: Song
  @StateObject
  private var store = TagVisibilityStore()
  @State
  private var showFilter = false

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 4) {
          Text(song.title)
            .font(.title2)
            .fontWeight(.semibold)
          Text(song.creatorName)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
      }
      Section {
        if visibleTags.isEmpty {
          Text("No tags to display")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
        } else {
          ForEach(visibleTags, id: \.key.rawValue) { item in
            HStack(alignment: .top) {
              Text(item.key.displayName)
                .foregroundColor(.secondary)
                .frame(minWidth: 110, alignment: .leading)
              Spacer()
              Text(item.value)
                .multilineTextAlignment(.trailing)
            }
          }
        }
      }
    }
    .navigationTitle("Song Info")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          showFilter = true
        } label: {
          Image(systemName: "line.3.horizontal.decrease.circle")
        }
      }
    }
    .sheet(isPresented: $showFilter) {
      NavigationView {
        SongTagsFilterView(store: store)
      }
    }
  }

  private var visibleTags: [(key: SongTagKey, value: String)] {
    SongTagKey.allCases.compactMap { key in
      guard !store.hiddenKeys.contains(key.rawValue),
            let value = key.value(for: song)
      else { return nil }
      return (key: key, value: value)
    }
  }
}
