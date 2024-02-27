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

public enum ArtworkIconSizeType: CGFloat {
    // rawValue will be used as insets
    case small = 250.0
    case big = 100.0
    
    public static let defaultSize: CGFloat = 1000.0
}

extension UIImage {
    public static func symbolImageSize(scale: UIImage.SymbolScale) -> CGSize {
        let config = UIImage.SymbolConfiguration(scale: .large)
        let image = UIImage(systemName: "plus", withConfiguration: config)!
        return image.size
    }
    
    public static let appIcon = UIImage.create("Icon-1024")
    
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
    
    public static let ellipsis = UIImage.create(systemName: "ellipsis")
    public static let settings = UIImage.create(systemName: "gear")
    public static let search = UIImage.create(systemName: "magnifyingglass")
    public static let genre = UIImage.create(systemName: "guitars.fill")
    public static let artist = UIImage.create(systemName: "music.mic")
    public static let album = UIImage.create(systemName: "square.stack")
    public static let folder = UIImage.create(systemName: "folder.fill")
    public static let playlist = UIImage.create(systemName: "music.note.list")
    public static let musicLibrary = UIImage.create(systemName: "music.note.house")
    public static let musicalNotes = UIImage.create(systemName: "music.note")
    public static let download = UIImage.create(systemName: "arrow.down.circle")
    public static let trash = UIImage.create(systemName: "trash")
    public static let cloudX = UIImage.create(systemName: "xmark.icloud")
    public static let plus = UIImage.create(systemName: "plus")
    public static let play = UIImage.create(systemName: "play.fill")
    public static let pause = UIImage.create(systemName: "pause.fill")
    public static let sleep = UIImage.create(systemName: "moon.zzz")
    public static let sleepFill = UIImage.create(systemName: "moon.zzz.fill")
    public static let cache = download
    public static let forward = UIImage.create(systemName: "forward.filled")
    public static let backward = UIImage.create(systemName: "backward.filled")
    public static let skipForward30 = UIImage.create(systemName: "goforward.30")
    public static let skipBackward15 = UIImage.create(systemName: "gobackward.15")
    public static let repeatAll = UIImage.create(systemName: "repeat")
    public static let repeatOne = UIImage.create(systemName: "repeat.1")
    public static let repeatOff = UIImage.create(systemName: "repeat")
    public static let shuffle = UIImage.create(systemName: "shuffle")
    public static let airplayaudio = UIImage.create(systemName: "airplayaudio")
    public static let sort = UIImage.create(systemName: "arrow.up.arrow.down")
    public static let filter = UIImage.create(systemName: "line.3.horizontal.decrease.circle")
    public static let filterActive = UIImage.create(systemName: "line.3.horizontal.decrease.circle.fill")
    public static let heartFill = UIImage.create(systemName: "heart.fill")
    public static let heartEmpty = UIImage.create(systemName: "heart")
    public static let heartSlash = UIImage.create(systemName: "heart.slash")
    public static let clock = UIImage.create(systemName: "clock")
    public static let refresh = UIImage.create(systemName: "arrow.triangle.2.circlepath")
    public static let exclamation = UIImage.create(systemName: "exclamationmark")
    public static let bell = UIImage.create(systemName: "bell.fill")

    public static let gauge = UIImage.create("gauge") // SF-Symbols 5 Regular:  gauge.open.with.lines.needle.33percent.badge.arrow.down
    public static let gaugeDown = UIImage.create("gauge_down") // SF-Symbols 5 Regular:  gauge.open.with.lines.needle.33percent.badge.arrow.down
    public static let gaugeUp = UIImage.create("gauge_up") // SF-Symbols 5 Regular: gauge.open.with.lines.needle.33percent.badge.arrow.up
    public static let podcast = UIImage.create("podcast").withTintColor(.defaultBlue)
    public static let podcastEpisode: UIImage = podcast
    public static let albumNewest = UIImage.create("album_newest")
    public static let albumRecent = UIImage.create("album_recent")
    public static let userQueueInsert = UIImage.create("user_queue_insert") // SF-Symbols 5 Regular: custom.text.line.first.and.arrowtriangle.forward.badge.person.crop
    public static let userQueueAppend = UIImage.create("user_queue_append") // SF-Symbols 5 Regular: custom.text.line.last.and.arrowtriangle.forward.badge.person.crop
    public static let contextQueueInsert = UIImage.create("context_queue_insert") // SF-Symbols 5 Regular: custom.text.line.first.and.arrowtriangle.forward
    public static let contextQueueAppend = UIImage.create("context_queue_append") // SF-Symbols 5 Regular: custom.text.line.last.and.arrowtriangle.forward
    public static let podcastQueueInsert = contextQueueInsert
    public static let podcastQueueAppend = contextQueueAppend
    
    public static let songArtwork = UIImage.createArtwork(with: UIImage.musicalNotes, iconSizeType: .small)
    public static let albumArtwork = UIImage.createArtwork(with: UIImage.album, iconSizeType: .big)
    public static let genreArtwork = UIImage.createArtwork(with: UIImage.genre, iconSizeType: .big)
    public static let artistArtwork = UIImage.createArtwork(with: UIImage.artist, iconSizeType: .big)
    public static let podcastArtwork = UIImage.createArtwork(with: UIImage.podcast, iconSizeType: .big)
    public static let podcastEpisodeArtwork = UIImage.createArtwork(with: UIImage.podcastEpisode, iconSizeType: .small)
    public static let playlistArtwork = UIImage.createArtwork(with: UIImage.playlist, iconSizeType: .small, switchColors: true)
    public static let folderArtwork = UIImage.createArtwork(with: UIImage.folder, iconSizeType: .big)
    
    private static func create(_ named: String) -> UIImage {
        return UIImage(named: named) ?? UIImage()
    }
    private static func create(systemName: String) -> UIImage {
        return UIImage(systemName: systemName) ?? UIImage()
    }
    
    public static func createArtwork(with image: UIImage, iconSizeType: ArtworkIconSizeType, switchColors: Bool = false) -> UIImage {
        let frame = CGRect(x: 0, y: 0, width: ArtworkIconSizeType.defaultSize, height: ArtworkIconSizeType.defaultSize)
        let buildView = EntityImageView(frame: frame)
        let grayScale = 0.92
        let artworkBackgroundColor = UIColor(red: grayScale, green: grayScale, blue: grayScale, alpha: 1)
        let imageTintColor = !switchColors ? .defaultBlue : artworkBackgroundColor
        let backgroundColor = switchColors ? .defaultBlue : artworkBackgroundColor
        buildView.configureStyling(image: image, imageSizeType: iconSizeType, imageTintColor: imageTintColor, backgroundColor: backgroundColor)
        buildView.layoutIfNeeded()
        return buildView.screenshot ?? UIImage()
    }
    
    private static func createEmptyImage(with size: CGSize) -> UIImage?
    {
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
        ] as [NSAttributedString.Key : Any]
        image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))

        let textPoint = CGPoint(x: 0.0, y: 50.0-(fontSize/2))
        let rect = CGRect(origin: textPoint, size: image.size)
        number.description.draw(in: rect, withAttributes: textFontAttributes)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
}
