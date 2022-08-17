import Foundation
import UIKit

public enum ArtworkIconSizeType: CGFloat {
    // rawValue will be used as insets
    case small = 250.0
    case big = 100.0
    
    public static let defaultSize: CGFloat = 1000.0
}

extension UIImage {
    
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
    public static var cache: UIImage = { return UIImage.create("cache") }() // Font Awesome 6.1.1 Solid: cloud-arrow-down
    public static var forward: UIImage = { return UIImage.create("forward") }()  // SF-Symbols 3.2 Regular:  forward.filled
    public static var backward: UIImage = { return UIImage.create("backward") }()  // SF-Symbols 3.2 Regular:  backward.filled
    public static var skipForward30: UIImage = { return UIImage.create("skip_forward_30") }()  // SF-Symbols 3.2 Regular:  goforward.30
    public static var skipBackward15: UIImage = { return UIImage.create("skip_backward_15") }()  // SF-Symbols 3.2 Regular:  gobackward.30
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
    
}
