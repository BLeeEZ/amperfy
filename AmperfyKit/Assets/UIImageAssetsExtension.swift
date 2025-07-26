//
//  UIImageAssetsExtension.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 06.06.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

import Foundation
import UIKit

// MARK: - ArtworkIconSizeType

public enum ArtworkIconSizeType: CGFloat {
  // rawValue will be used as insets
  case small = 50.0
  case big = 20.0

  public static let defaultSize: CGFloat = 200.0
}

// MARK: - LightDarkModeType

public enum LightDarkModeType: CaseIterable {
  case light
  case dark

  public var description: String {
    switch self {
    case .light:
      return "Light"
    case .dark:
      return "Dark"
    }
  }
}

extension UIUserInterfaceStyle {
  public var asModeType: LightDarkModeType {
    switch self {
    case .unspecified:
      return .light
    case .light:
      return .light
    case .dark:
      return .dark
    @unknown default:
      return .light
    }
  }
}

// MARK: - ArtworkType

public enum ArtworkType: CaseIterable {
  case song
  case album
  case genre
  case artist
  case podcast
  case podcastEpisode
  case playlist
  case folder
  case radio

  public var description: String {
    switch self {
    case .song:
      return "Song"
    case .album:
      return "Album"
    case .genre:
      return "Genre"
    case .artist:
      return "Artist"
    case .podcast:
      return "Podcast"
    case .podcastEpisode:
      return "PodcastEpisode"
    case .playlist:
      return "Playlist"
    case .folder:
      return "Folder"
    case .radio:
      return "Radio"
    }
  }
}

@MainActor
extension UIImage {
  public static func symbolImageSize(scale: UIImage.SymbolScale) -> CGSize {
    let config = UIImage.SymbolConfiguration(scale: scale)
    let image = UIImage(systemName: "plus", withConfiguration: config)!
    return image.size
  }

  public static let appIcon = UIImage.create("Icon-1024")

  public static let xmark = UIImage.create(systemName: "xmark")
  public static let unSelected = UIImage.create(systemName: "circle")
  public static let isSelected = UIImage.create(systemName: "checkmark.circle.fill")
  public static let systemPlus = UIImage.create(systemName: "plus")
  public static let check = UIImage.create(systemName: "checkmark")
  public static let backwardFill = UIImage.create(systemName: "backward.fill")
  public static let forwardFill = UIImage.create(systemName: "forward.fill")
  public static let goBackward15 = UIImage.create(systemName: "gobackward.15")
  public static let goForward30 = UIImage.create(systemName: "goforward.30")
  public static let redo = UIImage.create(systemName: "gobackward")
  public static let clear = UIImage.create(systemName: "clear")
  public static let cancleDownloads = UIImage.create(systemName: "xmark.icloud")
  public static let startDownload = UIImage.create(systemName: "arrow.down.circle")
  public static let systemTrash = UIImage.create(systemName: "trash")
  public static let clipboard = UIImage.create(systemName: "doc.on.doc")
  public static let info = UIImage.create(systemName: "info.circle")
  public static let ban = UIImage.create(systemName: "circle.slash")
  public static let starEmpty = UIImage.create(systemName: "star")
  public static let starFill = UIImage.create(systemName: "star.fill")
  public static let bars = UIImage.create(systemName: "line.3.horizontal")
  public static let triangleDown = UIImage.create(systemName: "arrowtriangle.down.fill")
  public static let playlistDisplayStyle = UIImage.create(systemName: "list.bullet")
  public static let playlistX = UIImage.create(systemName: "text.badge.xmark")
  public static let playlistPlus = UIImage.create(systemName: "text.badge.plus")
  public static let squareArrow = UIImage.create(systemName: "arrow.forward.square")
  public static let grid = UIImage.create(systemName: "square.grid.2x2")

  public static let ellipsis = UIImage.create(systemName: "ellipsis")
  public static let filter = UIImage.create(systemName: "line.3.horizontal.decrease")
  public static let settings = UIImage.create(systemName: "gear")
  public static let search = UIImage.create(systemName: "magnifyingglass")
  public static let genre = UIImage.create(systemName: "guitars.fill")
  public static let artist = UIImage.create(systemName: "music.mic")
  public static let album = UIImage.create(systemName: "square.stack")
  public static let folder = UIImage.create(systemName: "folder.fill")
  public static let radio = UIImage.create(systemName: "dot.radiowaves.left.and.right")
  public static let playlist = UIImage.create(systemName: "music.note.list")
  public static let musicLibrary = UIImage.create(systemName: "music.note.house")
  public static let musicalNotes = UIImage.create(systemName: "music.note")
  public static let download = UIImage.create(systemName: "arrow.down.circle")
  public static let trash = UIImage.create(systemName: "trash")
  public static let cloudX = UIImage.create(systemName: "xmark.icloud")
  public static let plus = UIImage.create(systemName: "plus")
  public static let plusCircle = UIImage.create(systemName: "plus.circle")
  public static let play = UIImage.create(systemName: "play.fill")
  public static let pause = UIImage.create(systemName: "pause.fill")
  public static let stop = UIImage.create(systemName: "stop.fill")
  public static let sleep = UIImage.create(systemName: "moon.zzz")
  public static let sleepFill = UIImage.create(systemName: "moon.zzz.fill")
  public static let cache = download
  public static let antenna = UIImage.create(systemName: "antenna.radiowaves.left.and.right")
  public static let skipForward30 = UIImage.create(systemName: "goforward.30")
  public static let skipBackward15 = UIImage.create(systemName: "gobackward.15")
  public static let repeatAll = UIImage.create(systemName: "repeat")
  public static let repeatOne = UIImage.create(systemName: "repeat.1")
  public static let repeatOff = UIImage.create(systemName: "repeat")
  public static let shuffle = UIImage.create(systemName: "shuffle")
  public static let airplayaudio = UIImage.create(systemName: "airplayaudio")
  public static let sort = UIImage.create(systemName: "arrow.up.arrow.down")
  public static let heartFill = UIImage.create(systemName: "heart.fill")
  public static let heartEmpty = UIImage.create(systemName: "heart")
  public static let heartSlash = UIImage.create(systemName: "heart.slash")
  public static let followLink = UIImage.create(systemName: "arrowshape.turn.up.forward.fill")
  public static let clock = UIImage.create(systemName: "clock")
  public static let refresh = UIImage.create(systemName: "arrow.triangle.2.circlepath")
  public static let exclamation = UIImage.create(systemName: "exclamationmark")
  public static let bell = UIImage.create(systemName: "bell.fill")
  public static let resize = UIImage.create(systemName: "arrow.down.left.and.arrow.up.right")
  public static let display = UIImage.create(systemName: "display")
  public static let server = UIImage.create(systemName: "server.rack")
  public static let playCircle = UIImage.create(systemName: "play.circle.fill")
  public static let arrowRight = UIImage.create(systemName: "arrow.right.circle.fill")
  public static let photo = UIImage.create(systemName: "photo.fill")
  public static let person = UIImage.create(systemName: "person.circle")
  public static let equalizer = UIImage.create(systemName: "chart.bar.xaxis")
  public static let doc = UIImage.create(systemName: "doc.fill")
  public static let arrowTurnUp = UIImage
    .create(systemName: "arrowshape.turn.up.backward.circle.fill")
  public static let hammer = UIImage.create(systemName: "hammer.circle.fill")
  public static let circle = UIImage.create(systemName: "circle")
  public static let audioVisualizer = UIImage.create(systemName: "circle.dashed")
  public static let volumeMin = UIImage.create(systemName: "speaker.fill")
  public static let volumeMax = UIImage.create(systemName: "speaker.wave.3.fill")

  public static let miniPlayer = UIImage.create(systemName: "play.rectangle.on.rectangle")
  public static let listBullet = UIImage.create(systemName: "list.bullet")

  /// Asset symbol generation is enabled by default for both new and old projects but can be disabled by setting the build setting "Generate Asset Symbols" (ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS) to NO.
  #if false
    public static let gauge = UIImage
      .create("gauge") // SF-Symbols 5 Regular:  gauge.open.with.lines.needle.33percent.badge.arrow.down
    public static let gaugeDown = UIImage
      .create("gauge_down") // SF-Symbols 5 Regular:  gauge.open.with.lines.needle.33percent.badge.arrow.down
    public static let gaugeUp = UIImage
      .create("gauge_up") // SF-Symbols 5 Regular: gauge.open.with.lines.needle.33percent.badge.arrow.up
    public static let podcast = UIImage.create("podcast").withTintColor(.defaultBlue)
    public static let albumNewest = UIImage.create("album_newest")
    public static let albumRecent = UIImage.create("album_recent")
    public static let userQueueInsert = UIImage
      .create("user_queue_insert") // SF-Symbols 5 Regular: custom.text.line.first.and.arrowtriangle.forward.badge.person.crop
    public static let userQueueAppend = UIImage
      .create("user_queue_append") // SF-Symbols 5 Regular: custom.text.line.last.and.arrowtriangle.forward.badge.person.crop
    public static let contextQueueInsert = UIImage
      .create("context_queue_insert") // SF-Symbols 5 Regular: custom.text.line.first.and.arrowtriangle.forward
    public static let contextQueueAppend = UIImage
      .create("context_queue_append") // SF-Symbols 5 Regular: custom.text.line.last.and.arrowtriangle.forward
    public static let lyrics = UIImage
      .create(systemName: "book.pages") // SF-Symbols 5 Regular: book.pages (available in system catalog with iOS 17.0 and upwards)
  #endif
  public static let podcastEpisode: UIImage = podcast
  public static let podcastQueueInsert = contextQueueInsert
  public static let podcastQueueAppend = contextQueueAppend

  public static func getGeneratedArtwork(
    theme: ThemePreference,
    artworkType: ArtworkType
  )
    -> UIImage {
    var img = UIImage()
    switch theme {
    case .blue:
      switch artworkType {
      case .song:
        img = UIImage(imageLiteralResourceName: "BlueSong")
      case .album:
        img = UIImage(imageLiteralResourceName: "BlueAlbum")
      case .genre:
        img = UIImage(imageLiteralResourceName: "BlueGenre")
      case .artist:
        img = UIImage(imageLiteralResourceName: "BlueArtist")
      case .podcast:
        img = UIImage(imageLiteralResourceName: "BluePodcast")
      case .podcastEpisode:
        img = UIImage(imageLiteralResourceName: "BluePodcastEpisode")
      case .playlist:
        img = UIImage(imageLiteralResourceName: "BluePlaylist")
      case .folder:
        img = UIImage(imageLiteralResourceName: "BlueFolder")
      case .radio:
        img = UIImage(imageLiteralResourceName: "BlueRadio")
      }
    case .green:
      switch artworkType {
      case .song:
        img = UIImage(imageLiteralResourceName: "GreenSong")
      case .album:
        img = UIImage(imageLiteralResourceName: "GreenAlbum")
      case .genre:
        img = UIImage(imageLiteralResourceName: "GreenGenre")
      case .artist:
        img = UIImage(imageLiteralResourceName: "GreenArtist")
      case .podcast:
        img = UIImage(imageLiteralResourceName: "GreenPodcast")
      case .podcastEpisode:
        img = UIImage(imageLiteralResourceName: "GreenPodcastEpisode")
      case .playlist:
        img = UIImage(imageLiteralResourceName: "GreenPlaylist")
      case .folder:
        img = UIImage(imageLiteralResourceName: "GreenFolder")
      case .radio:
        img = UIImage(imageLiteralResourceName: "GreenRadio")
      }
    case .red:
      switch artworkType {
      case .song:
        img = UIImage(imageLiteralResourceName: "RedSong")
      case .album:
        img = UIImage(imageLiteralResourceName: "RedAlbum")
      case .genre:
        img = UIImage(imageLiteralResourceName: "RedGenre")
      case .artist:
        img = UIImage(imageLiteralResourceName: "RedArtist")
      case .podcast:
        img = UIImage(imageLiteralResourceName: "RedPodcast")
      case .podcastEpisode:
        img = UIImage(imageLiteralResourceName: "RedPodcastEpisode")
      case .playlist:
        img = UIImage(imageLiteralResourceName: "RedPlaylist")
      case .folder:
        img = UIImage(imageLiteralResourceName: "RedFolder")
      case .radio:
        img = UIImage(imageLiteralResourceName: "RedRadio")
      }
    case .yellow:
      switch artworkType {
      case .song:
        img = UIImage(imageLiteralResourceName: "YellowSong")
      case .album:
        img = UIImage(imageLiteralResourceName: "YellowAlbum")
      case .genre:
        img = UIImage(imageLiteralResourceName: "YellowGenre")
      case .artist:
        img = UIImage(imageLiteralResourceName: "YellowArtist")
      case .podcast:
        img = UIImage(imageLiteralResourceName: "YellowPodcast")
      case .podcastEpisode:
        img = UIImage(imageLiteralResourceName: "YellowPodcastEpisode")
      case .playlist:
        img = UIImage(imageLiteralResourceName: "YellowPlaylist")
      case .folder:
        img = UIImage(imageLiteralResourceName: "YellowFolder")
      case .radio:
        img = UIImage(imageLiteralResourceName: "YellowRadio")
      }
    case .orange:
      switch artworkType {
      case .song:
        img = UIImage(imageLiteralResourceName: "OrangeSong")
      case .album:
        img = UIImage(imageLiteralResourceName: "OrangeAlbum")
      case .genre:
        img = UIImage(imageLiteralResourceName: "OrangeGenre")
      case .artist:
        img = UIImage(imageLiteralResourceName: "OrangeArtist")
      case .podcast:
        img = UIImage(imageLiteralResourceName: "OrangePodcast")
      case .podcastEpisode:
        img = UIImage(imageLiteralResourceName: "OrangePodcastEpisode")
      case .playlist:
        img = UIImage(imageLiteralResourceName: "OrangePlaylist")
      case .folder:
        img = UIImage(imageLiteralResourceName: "OrangeFolder")
      case .radio:
        img = UIImage(imageLiteralResourceName: "OrangeRadio")
      }
    case .purple:
      switch artworkType {
      case .song:
        img = UIImage(imageLiteralResourceName: "PurpleSong")
      case .album:
        img = UIImage(imageLiteralResourceName: "PurpleAlbum")
      case .genre:
        img = UIImage(imageLiteralResourceName: "PurpleGenre")
      case .artist:
        img = UIImage(imageLiteralResourceName: "PurpleArtist")
      case .podcast:
        img = UIImage(imageLiteralResourceName: "PurplePodcast")
      case .podcastEpisode:
        img = UIImage(imageLiteralResourceName: "PurplePodcastEpisode")
      case .playlist:
        img = UIImage(imageLiteralResourceName: "PurplePlaylist")
      case .folder:
        img = UIImage(imageLiteralResourceName: "PurpleFolder")
      case .radio:
        img = UIImage(imageLiteralResourceName: "PurpleRadio")
      }
    case .pink:
      switch artworkType {
      case .song:
        img = UIImage(imageLiteralResourceName: "PinkSong")
      case .album:
        img = UIImage(imageLiteralResourceName: "PinkAlbum")
      case .genre:
        img = UIImage(imageLiteralResourceName: "PinkGenre")
      case .artist:
        img = UIImage(imageLiteralResourceName: "PinkArtist")
      case .podcast:
        img = UIImage(imageLiteralResourceName: "PinkPodcast")
      case .podcastEpisode:
        img = UIImage(imageLiteralResourceName: "PinkPodcastEpisode")
      case .playlist:
        img = UIImage(imageLiteralResourceName: "PinkPlaylist")
      case .folder:
        img = UIImage(imageLiteralResourceName: "PinkFolder")
      case .radio:
        img = UIImage(imageLiteralResourceName: "PinkRadio")
      }
    }

    return img
  }

  public static func generateArtwork(
    theme: ThemePreference,
    lightDarkMode: LightDarkModeType,
    artworkType: ArtworkType
  )
    -> UIImage {
    var generatedArtwork: UIImage?
    switch artworkType {
    case .song:
      generatedArtwork = UIImage.createArtwork(
        with: UIImage.musicalNotes,
        iconSizeType: .small,
        theme: theme,
        lightDarkMode: lightDarkMode
      )
    case .album:
      generatedArtwork = UIImage.createArtwork(
        with: UIImage.album,
        iconSizeType: .big,
        theme: theme,
        lightDarkMode: lightDarkMode
      )
    case .genre:
      generatedArtwork = UIImage.createArtwork(
        with: UIImage.genre,
        iconSizeType: .big,
        theme: theme,
        lightDarkMode: lightDarkMode
      )
    case .artist:
      generatedArtwork = UIImage.createArtwork(
        with: UIImage.artist,
        iconSizeType: .big,
        theme: theme,
        lightDarkMode: lightDarkMode
      )
    case .podcast:
      generatedArtwork = UIImage.createArtwork(
        with: UIImage.podcast,
        iconSizeType: .big,
        theme: theme,
        lightDarkMode: lightDarkMode
      )
    case .podcastEpisode:
      generatedArtwork = UIImage.createArtwork(
        with: UIImage.podcastEpisode,
        iconSizeType: .small,
        theme: theme,
        lightDarkMode: lightDarkMode
      )
    case .playlist:
      generatedArtwork = UIImage.createArtwork(
        with: UIImage.playlist,
        iconSizeType: .small,
        theme: theme,
        lightDarkMode: lightDarkMode,
        switchColors: true
      )
    case .folder:
      generatedArtwork = UIImage.createArtwork(
        with: UIImage.folder,
        iconSizeType: .big,
        theme: theme,
        lightDarkMode: lightDarkMode
      )
    case .radio:
      generatedArtwork = UIImage.createArtwork(
        with: UIImage.radio,
        iconSizeType: .big,
        theme: theme,
        lightDarkMode: lightDarkMode
      )
    }
    return generatedArtwork ?? UIImage()
  }

  private static func create(_ named: String) -> UIImage {
    UIImage(named: named) ?? UIImage()
  }

  private static func create(systemName: String) -> UIImage {
    UIImage(systemName: systemName) ?? UIImage()
  }

  public static func createArtwork(
    with image: UIImage,
    iconSizeType: ArtworkIconSizeType,
    theme: ThemePreference,
    lightDarkMode: LightDarkModeType,
    switchColors: Bool = false
  )
    -> UIImage {
    let frame = CGRect(
      x: 0,
      y: 0,
      width: ArtworkIconSizeType.defaultSize,
      height: ArtworkIconSizeType.defaultSize
    )
    let buildView = EntityImageView(frame: frame)
    let grayScale = lightDarkMode == .light ? 0.85 : 0.15
    let artworkBackgroundColor = UIColor(
      red: grayScale,
      green: grayScale,
      blue: grayScale,
      alpha: 1
    )
    let imageTintColor = !switchColors ? theme.asColor : artworkBackgroundColor
    let backgroundColor = switchColors ? theme.asColor : artworkBackgroundColor
    buildView.configureStyling(
      image: image,
      imageSizeType: iconSizeType,
      imageTintColor: imageTintColor,
      backgroundColor: backgroundColor
    )
    buildView.layoutIfNeeded()
    return buildView.screenshot ?? UIImage()
  }

  private static func createEmptyImage(with size: CGSize) -> UIImage? {
    UIGraphicsBeginImageContext(size)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
  }

  public static func numberToImage(number: Int) -> UIImage {
    let fontSize = 40.0
    let textFont = UIFont(name: "Helvetica Bold", size: fontSize)!

    let image = createEmptyImage(with: CGSize(width: 100.0, height: 100.0)) ?? UIImage()
    let scale = UIScreen.main.scale
    UIGraphicsBeginImageContextWithOptions(image.size, false, scale)

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let textFontAttributes = [
      NSAttributedString.Key.font: textFont,
      NSAttributedString.Key.paragraphStyle: paragraphStyle,
      NSAttributedString.Key.foregroundColor: UIColor.lightGray,
    ] as [NSAttributedString.Key: Any]
    image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))

    let textPoint = CGPoint(x: 0.0, y: 50.0 - (fontSize / 2))
    let rect = CGRect(origin: textPoint, size: image.size)
    number.description.draw(in: rect, withAttributes: textFontAttributes)

    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return newImage!
  }

  public func styleForNavigationBar(pointSize: CGFloat, tintColor: UIColor) -> UIImage {
    let navBarSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: pointSize)
    let img = applyingSymbolConfiguration(navBarSymbolConfiguration) ?? UIImage()
    return img.withTintColor(tintColor)
  }
}
