//
//  BackendApi.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 19.03.19.
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

import CoreData
import CoreMedia
import Foundation

// MARK: - ParsedObjectType

public enum ParsedObjectType: Sendable {
  case artist
  case album
  case song
  case playlist
  case genre
  case podcast
  case cache
}

// MARK: - ParsedObjectNotifiable

public protocol ParsedObjectNotifiable {
  func notifyParsedObject(ofType parsedObjectType: ParsedObjectType)
}

// MARK: - SyncCallbacks

public protocol SyncCallbacks: ParsedObjectNotifiable, Sendable {
  nonisolated func notifySyncStarted(ofType parsedObjectType: ParsedObjectType, totalCount: Int)
}

// MARK: - ThreadPerformanceMonitor

public protocol ThreadPerformanceMonitor: Sendable {
  var shouldSlowDownExecution: Bool { get }
  var isInForeground: Bool { get set }
}

// MARK: - ThreadPerformanceObserver

final public class ThreadPerformanceObserver: ThreadPerformanceMonitor, Sendable {
  public static let shared = ThreadPerformanceObserver()

  private let _isInForeground = Atomic<Bool>(wrappedValue: true)
  public var isInForeground: Bool {
    get { _isInForeground.wrappedValue }
    set { _isInForeground.wrappedValue = newValue }
  }

  public var shouldSlowDownExecution: Bool {
    !isInForeground
  }
}

// MARK: - NowPlayingSongPosition

public enum NowPlayingSongPosition {
  case start
  case end
}

// MARK: - APIDataResponse

public final class APIDataResponse: Sendable {
  public let data: Data
  public let url: URL?

  init(data: Data, url: URL?) {
    self.data = data
    self.url = url
  }
}

// MARK: - LyricsList

public struct LyricsList {
  public var lyrics = [StructuredLyrics]()

  public func getFirstSyncedLyricsOrUnsyncedAsDefault() -> StructuredLyrics? {
    lyrics.first(where: { $0.synced && $0.kind == .main })
      ?? lyrics.first(where: { $0.synced })
      ?? lyrics.first(where: { $0.kind == .main })
      ?? lyrics.object(at: 0)
  }
}

// MARK: - LyricsKind

/// The layer of a lyrics entry. Only sent for enhanced lyrics (OpenSubsonic songLyrics v2).
public enum LyricsKind: String, Sendable {
  case main
  case translation
  case pronunciation
}

// MARK: - StructuredLyrics

public struct StructuredLyrics {
  /// required
  public var lang =
    "" // The lyrics language (ideally ISO 639). If the language is unknown (e.g. lrc file), the server must return und (ISO standard) or xxx (common value for taggers)
  public var synced = false // True if the lyrics are synced, false otherwise
  public var line =
    [LyricsLine]() // The actual lyrics. Ordered by start time (synced) or appearance order (unsynced)
  /// optional
  public var displayArtist: String? // The artist name to display. This could be the localized name, or any other value
  public var displayTitle: String? // The title to display. This could be the song title (localized), or any other value
  public var offset =
    0 // The offset to apply to all lyrics, in milliseconds. Positive means lyrics appear sooner, negative means later. If not included, the offset must be assumed to be 0
  /// enhanced (OpenSubsonic songLyrics v2)
  public var kind = LyricsKind.main
  public var agents = [LyricsAgent]() // The singers that the cue lines refer to
  public var cueLines =
    [LyricsCueLine]() // Word or syllable timing. Each cue line refers to a line by its index
  public init() {}

  /// Several cue lines can refer to the same line, one for each agent. The main agent comes first.
  public func mainCueLine(forLine index: Int) -> LyricsCueLine? {
    cueLines.first { $0.index == index }
  }

  /// The end of the last line in milliseconds, if the lyrics give it
  public var lastLineEnd: Int? {
    guard let lastLine = line.last else { return nil }
    if let end = lastLine.end { return end }
    guard let cueLine = mainCueLine(forLine: line.count - 1) else { return nil }
    return cueLine.end ?? cueLine.cues.last?.end
  }

  /// The lyrics time in milliseconds at a playback time, with the offset applied
  public func lyricsTime(at playbackTime: CMTime) -> Int {
    lyricsTime(atSeconds: playbackTime.seconds)
  }

  /// The lyrics time in milliseconds at a playback time in seconds, with the offset applied
  public func lyricsTime(atSeconds seconds: TimeInterval) -> Int {
    guard seconds.isFinite else { return offset }
    return Int((seconds * 1_000).rounded(.down)) + offset
  }

  /// The playback time in seconds at which a line is shown, with the offset applied
  public func playbackSeconds(of line: LyricsLine) -> TimeInterval {
    max(Double((line.start ?? 0) - offset) / 1_000, 0)
  }
}

// MARK: - LyricsAgent

public struct LyricsAgent {
  public var id = "" // Unique in its lyrics entry
  public var role = "" // main, voice, bg or group
  public var name: String?

  public init() {}
}

// MARK: - LyricsCueLine

public struct LyricsCueLine {
  public var index = 0 // The zero-based index of the line that this cue line refers to
  public var start: Int?
  public var end: Int?
  public var value = "" // The text of the agent of this cue line. The cue byte offsets refer to it
  public var agentId: String?
  public var cues = [LyricsCue]()

  public init() {}

  /// The cue that is sung at a lyrics time in milliseconds. A cue stays active until the next cue starts.
  public func activeCueIndex(at time: Int) -> Int? {
    cues.lastIndex { $0.start <= time }
  }

  /// The active cue at a lyrics time in milliseconds and the sung part of it
  public func progress(at time: Int) -> LyricsCueProgress? {
    guard let index = activeCueIndex(at: time) else { return nil }
    let cue = cues[index]
    let end = cue.end ?? cues.object(at: index + 1)?.start ?? end ?? cue.start
    guard end > cue.start else { return LyricsCueProgress(cueIndex: index, fraction: 1) }
    let fraction = Double(time - cue.start) / Double(end - cue.start)
    return LyricsCueProgress(cueIndex: index, fraction: min(max(fraction, 0), 1))
  }

  /// The range of each cue in `text`, or nil if a cue cannot be found
  public func cueRanges(in text: String) -> [Range<String.Index>]? {
    var byteShift = 0
    if text != value, let valueRange = text.range(of: value) {
      byteShift = text.utf8.distance(from: text.startIndex, to: valueRange.lowerBound)
    }
    var ranges = [Range<String.Index>]()
    var searchStart = text.startIndex
    for cue in cues {
      if cue.value.isEmpty {
        ranges.append(searchStart ..< searchStart)
        continue
      }
      guard let range = cue.range(in: text, byteShift: byteShift, searchingFrom: searchStart)
      else { return nil }
      ranges.append(range)
      searchStart = range.upperBound
    }
    return ranges
  }
}

// MARK: - LyricsCueProgress

public struct LyricsCueProgress: Equatable, Sendable {
  public var cueIndex: Int
  public var fraction: Double // The sung part of the cue, from 0 to 1

  public init(cueIndex: Int, fraction: Double) {
    self.cueIndex = cueIndex
    self.fraction = fraction
  }
}

// MARK: - LyricsPlaybackClock

/// Gives a smooth playback time for each display frame. The player time changes in steps, so the clock
/// runs on with the host time and follows the player time again only when the two drift apart.
public struct LyricsPlaybackClock: Sendable {
  public static let maxDrift: TimeInterval = 0.08

  private var anchorTime: TimeInterval?
  private var anchorHostTime: TimeInterval = 0
  private var anchorRate: Double = 1

  public init() {}

  public mutating func time(
    playerTime: TimeInterval,
    rate: Double,
    hostTime: TimeInterval
  )
    -> TimeInterval {
    if let anchorTime, rate == anchorRate {
      let predicted = anchorTime + (hostTime - anchorHostTime) * rate
      if abs(predicted - playerTime) <= Self.maxDrift {
        return predicted
      }
    }
    anchorTime = playerTime
    anchorHostTime = hostTime
    anchorRate = rate
    return playerTime
  }

  public mutating func reset() {
    anchorTime = nil
  }
}

// MARK: - LyricsCue

public struct LyricsCue {
  public var start = 0
  public var end: Int?
  public var value = "" // The text of this word or syllable
  public var byteStart = 0 // Zero-based inclusive UTF-8 byte offset into the cue line value
  public var byteEnd = 0 // Zero-based inclusive UTF-8 byte offset into the cue line value

  public init() {}

  /// The range of this cue in `text`. The byte offsets are used if they point at the cue value.
  /// Else the cue value is searched from `searchStart`.
  public func range(
    in text: String,
    byteShift: Int = 0,
    searchingFrom searchStart: String.Index? = nil
  )
    -> Range<String.Index>? {
    if let range = byteRange(in: text, shift: byteShift), text[range] == value {
      return range
    }
    let lowerBound = searchStart ?? text.startIndex
    guard !value.isEmpty, lowerBound <= text.endIndex else { return nil }
    return text.range(of: value, range: lowerBound ..< text.endIndex)
  }

  /// The range of the byte offsets in `text`, or nil if they are outside of it or split a character
  func byteRange(in text: String, shift: Int = 0) -> Range<String.Index>? {
    let utf8 = text.utf8
    guard byteStart >= 0, byteEnd >= byteStart,
          let lower = utf8.index(
            utf8.startIndex,
            offsetBy: byteStart + shift,
            limitedBy: utf8.endIndex
          ),
          let upper = utf8.index(
            utf8.startIndex,
            offsetBy: byteEnd + shift + 1,
            limitedBy: utf8.endIndex
          ),
          lower.samePosition(in: text) != nil,
          upper.samePosition(in: text) != nil
    else { return nil }
    return lower ..< upper
  }
}

// MARK: - LyricsLine

public struct LyricsLine {
  public var start: Int? // The start time of the lyrics, relative to the start time of the track, in milliseconds. If this is not part of synced lyrics, start must be omitted
  public var end: Int? // The end time of the line in milliseconds. Only sent for enhanced lyrics, if the source has it
  public var value = "" // The actual text of this line

  public init() {}
  public var startTime: CMTime {
    guard let start = start else { return CMTime(value: Int64(0), timescale: 1) }
    return CMTime(value: Int64(start), timescale: 1_000)
  }
}

// MARK: - LibrarySyncer

public protocol LibrarySyncer: Sendable {
  @MainActor
  func syncInitial(statusNotifyier: SyncCallbacks?) async throws
  @MainActor
  func sync(genre: Genre) async throws
  @MainActor
  func sync(artist: Artist) async throws
  @MainActor
  func sync(album: Album) async throws
  @MainActor
  func sync(song: Song) async throws
  @MainActor
  func sync(podcast: Podcast) async throws
  @MainActor
  func syncNewestAlbums(offset: Int, count: Int) async throws
  @MainActor
  func syncRecentAlbums(offset: Int, count: Int) async throws
  @MainActor
  func syncNewestPodcastEpisodes() async throws
  @MainActor
  func syncFavoriteLibraryElements() async throws
  @MainActor
  func syncRadios() async throws
  @MainActor
  func syncDownPlaylistsWithoutSongs() async throws
  @MainActor
  func syncDown(playlist: Playlist) async throws
  @MainActor
  func syncUpload(playlistToUpdateName playlist: Playlist) async throws
  @MainActor
  func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song]) async throws
  @MainActor
  func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int) async throws
  @MainActor
  func syncUpload(playlistToUpdateOrder playlist: Playlist) async throws
  @MainActor
  func syncUpload(playlistIdToDelete id: String) async throws
  @MainActor
  func syncDownPodcastsWithoutEpisodes() async throws
  @MainActor
  func searchArtists(searchText: String) async throws
  @MainActor
  func searchAlbums(searchText: String) async throws
  @MainActor
  func searchSongs(searchText: String) async throws
  @MainActor
  func syncMusicFolders() async throws
  @MainActor
  func syncIndexes(musicFolder: MusicFolder) async throws
  @MainActor
  func sync(directory: Directory) async throws
  @MainActor
  func requestRandomSongs(playlist: Playlist, count: Int) async throws
  @MainActor
  func requestSimilarSongs(song: Song, count: Int) async throws -> [Song]
  @MainActor
  func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) async throws
  @MainActor
  func syncNowPlaying(song: Song, songPosition: NowPlayingSongPosition) async throws
  @MainActor
  func scrobble(song: Song, date: Date?) async throws
  @MainActor
  func setRating(song: Song, rating: Int) async throws
  @MainActor
  func setRating(album: Album, rating: Int) async throws
  @MainActor
  func setRating(artist: Artist, rating: Int) async throws
  @MainActor
  func setFavorite(song: Song, isFavorite: Bool) async throws
  @MainActor
  func setFavorite(album: Album, isFavorite: Bool) async throws
  @MainActor
  func setFavorite(artist: Artist, isFavorite: Bool) async throws
  @MainActor
  func parseLyrics(relFilePath: URL) async throws -> LyricsList
}

// MARK: - AbstractBackgroundLibrarySyncer

protocol AbstractBackgroundLibrarySyncer {
  var isActive: Bool { get }
  func stop()
}

// MARK: - CleansedURL

final public class CleansedURL: Sendable {
  private let urlString: String

  init(urlString: String) {
    self.urlString = urlString
  }

  var description: String {
    urlString
  }
}

extension URL {
  nonisolated func asCleansedURL(cleanser: URLCleanser) -> CleansedURL {
    cleanser.cleanse(url: self)
  }
}

// MARK: - URLCleanser

public protocol URLCleanser: Sendable {
  func cleanse(url: URL?) -> CleansedURL
}

// MARK: - TranscodingInfo

public struct TranscodingInfo {
  var format: CacheTranscodingFormatPreference?
  var bitrate: StreamingMaxBitratePreference?

  var description: String {
    "Format: \(format?.description ?? "-"), Bitrate: \(bitrate?.description ?? "-")"
  }
}

// MARK: - BackendApi

public protocol BackendApi: URLCleanser, Sendable {
  var clientApiVersion: String { get }
  var serverApiVersion: String { get }
  var httpHeaders: [String: String] { get }
  func provideCredentials(credentials: LoginCredentials)
  func isAuthenticationValid(credentials: LoginCredentials) async throws
  func generateUrl(forDownloadingPlayable playableInfo: AbstractPlayableInfo) async throws -> URL
  func generateUrl(
    forStreamingPlayable playableInfo: AbstractPlayableInfo,
    maxBitrate: StreamingMaxBitratePreference,
    formatPreference: StreamingFormatPreference
  ) async throws -> URL
  /// Stream starting at `timeOffset` seconds; throws `BackendError.notSupported` if the server can't do it
  func generateUrl(
    forStreamingPlayable playableInfo: AbstractPlayableInfo,
    maxBitrate: StreamingMaxBitratePreference,
    formatPreference: StreamingFormatPreference,
    timeOffset: Int
  ) async throws -> URL
  func generateUrl(forArtwork artwork: Artwork) async throws -> URL
  func checkForErrorResponse(response: APIDataResponse) -> ResponseError?
  @MainActor
  func createLibrarySyncer(account: Account, storage: PersistentStorage) -> LibrarySyncer
  func createArtworkDownloadDelegate() -> DownloadManagerDelegate
  func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo?
}
