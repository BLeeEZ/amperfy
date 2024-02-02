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
    public static let systemPlus = UIImage(systemName: "plus") ?? UIImage()
    public static let check = UIImage(systemName: "checkmark") ?? UIImage()
    public static let backwardFill = UIImage(systemName: "backward.fill") ?? UIImage()
    public static let forwardFill = UIImage(systemName: "forward.fill") ?? UIImage()
    public static let goBackward15 = UIImage(systemName: "gobackward.15") ?? UIImage()
    public static let goForward30 = UIImage(systemName: "goforward.30") ?? UIImage()
    public static let redo = UIImage(systemName: "gobackward") ?? UIImage()
    public static let clear = UIImage(systemName: "clear") ?? UIImage()
    public static let cancleDownloads = UIImage(systemName: "xmark.icloud") ?? UIImage()
    public static let startDownload = UIImage(systemName: "arrow.down.circle") ?? UIImage()
    public static let systemTrash = UIImage(systemName: "trash") ?? UIImage()
    
    public static var amperfyMosaicArtwork: UIImage = { return UIImage.create("song") }()
    public static var appIcon: UIImage = { return UIImage.create("Icon-1024") }()
    
    public static var ellipsis: UIImage = { return UIImage.create("ellipsis") }() // SF-Symbols 3.2 Regular: ellipsis
    public static var playerStyleCompact: UIImage = { return UIImage.create("player_style_compact") }() // SF-Symbols 3.2 Regular: rectangle.portrait.inset.filled
    public static var playerStyleLarge: UIImage = { return UIImage.create("player_style_large") }() // SF-Symbols 3.2 Regular:  rectangle.portrait.topthird.inset.filled
    
    public static var songArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.musicalNotes, iconSizeType: .small) }()
    public static var genre: UIImage = { return UIImage.create("genre") }()  // SF-Symbols 3.2 Regular:  guitars.fill
    public static var genreArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.genre, iconSizeType: .big) }()
    public static var artist: UIImage = { return UIImage.create("artist") }()
    public static var artistArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.artist, iconSizeType: .big) }()
    public static var album: UIImage = { return UIImage.create("album") }()
    public static var albumArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.album, iconSizeType: .big) }()
    public static var albumCarplay: UIImage = { return UIImage.create("album_carplay") }()
    public static var podcast: UIImage = { return UIImage.create("podcast") }()
    public static var podcastArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.podcast, iconSizeType: .big) }()
    public static var podcastCarplay: UIImage = { return UIImage.create("podcast_carplay") }()
    public static var podcastEpisode: UIImage = { return UIImage.create("podcast") }()
    public static var podcastEpisodeArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.podcastEpisode, iconSizeType: .small) }()
    public static var folder: UIImage = { return UIImage.create("folder") }() // SF-Symbols 3.2 Regular:  foldes.fill
    public static var playlist: UIImage = { return UIImage.create("playlist_svg") }()
    public static var playlistArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.playlist, iconSizeType: .small, switchColors: true) }()
    public static var playlistCarplay: UIImage = { return UIImage.create("playlist_carplay") }()
    public static var playlistBlack: UIImage = { return UIImage.create("playlist") }()
    public static var musicLibrary: UIImage = { return UIImage.create("music_library") }()
    public static var musicalNotes: UIImage = { return UIImage.create("musical_notes_svg") }()
    public static var musicalNotesCarplay: UIImage = { return UIImage.create("musical_notes_carplay") }()
    
    public static var userQueueInsert: UIImage = { return UIImage.create("user_queue_insert") }()
    public static var userQueueAppend: UIImage = { return UIImage.create("user_queue_append") }()
    public static var contextQueueInsert: UIImage = { return UIImage.create("context_queue_insert") }()
    public static var contextQueueAppend: UIImage = { return UIImage.create("context_queue_append") }()
    public static var podcastQueueInsert: UIImage = { return UIImage.create("podcast_queue_insert") }()
    public static var podcastQueueAppend: UIImage = { return UIImage.create("podcast_queue_append") }()
    public static var download: UIImage = { return UIImage.create("download") }()
    public static var trash: UIImage = { return UIImage.create("trash") }()
    public static var plus: UIImage = { return UIImage.create("plus") }()  // SF-Symbols 3.2 Regular:  plus

    public static var play: UIImage = { return UIImage.create("play") }()
    public static var pause: UIImage = { return UIImage.create("pause") }()
    public static var gauge: UIImage = { return UIImage.create("gauge") }() // SF-Symbols 5 Regular: gauge.open.with.lines.needle.33percent
    public static var gaugeDown: UIImage = { return UIImage.create("gauge_down") }() // SF-Symbols 5 Regular:  gauge.open.with.lines.needle.33percent.badge.arrow.down
    public static var gaugeUp: UIImage = { return UIImage.create("gauge_up") }() // SF-Symbols 5 Regular: gauge.open.with.lines.needle.33percent.badge.arrow.up
    public static var sleep: UIImage = { return UIImage(systemName: "moon.zzz") ?? clock }()
    public static var sleepFill: UIImage = { return UIImage(systemName: "moon.zzz.fill") ?? clock }()
    public static var cache: UIImage = { return UIImage.create("cache") }() // Font Awesome 6.1.1 Solid: cloud-arrow-down
    public static var forward: UIImage = { return UIImage.create("forward") }()  // SF-Symbols 3.2 Regular:  forward.filled
    public static var backward: UIImage = { return UIImage.create("backward") }()  // SF-Symbols 3.2 Regular:  backward.filled
    public static var skipForward30: UIImage = { return UIImage.create("skip_forward_30") }()  // SF-Symbols 3.2 Regular:  goforward.30
    public static var skipBackward15: UIImage = { return UIImage.create("skip_backward_15") }()  // SF-Symbols 3.2 Regular:  gobackward.15
    public static var shuffle: UIImage = { return UIImage.create("shuffle") }()
    public static var shuffleOff: UIImage = { return UIImage.create("shuffle_off") }() // custom mix of shuffle
    public static var sort: UIImage = { return UIImage.create("sort") }()  // SF-Symbols 3.2 Regular:  arrow.up.arrow.down
    public static var filter: UIImage = { return UIImage.create("filter") }()  // SF-Symbols 3.2 Regular:  line.3.horizontal.decrease.circle
    public static var filterActive: UIImage = { return UIImage.create("filter_active") }()  // SF-Symbols 3.2 Regular:  line.3.horizontal.decrease.circle.fill
    public static var heartFill: UIImage = { return UIImage.create("heart_fill") }()  // SF-Symbols 3.2 Regular:  heart.fill
    public static var heartEmpty: UIImage = { return UIImage.create("heart_empty") }()  // SF-Symbols 3.2 Regular:  heart
    public static var clock: UIImage = { return UIImage.create("clock") }()  // SF-Symbols 3.2 Regular:  clock
    
    private static func create(_ named: String) -> UIImage {
        return UIImage(named: named) ?? UIImage()
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
