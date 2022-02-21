import Foundation
import UIKit

enum ArtworkIconSizeType: CGFloat {
    // rawValue will be used as insets
    case small = 250.0
    case big = 100.0
    
    static let defaultSize: CGFloat = 1000.0
}

extension UIImage {
    
    static var amperfyMosaicArtwork: UIImage = { return UIImage.create("song") }()
    static var appIcon: UIImage = { return UIImage.create("Icon-1024") }()
    
    static var songArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.musicalNotes, iconSizeType: .small) }()
    static var genre: UIImage = { return UIImage.create("genre") }()
    static var genreArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.genre, iconSizeType: .big) }()
    static var artist: UIImage = { return UIImage.create("artist") }()
    static var artistArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.artist, iconSizeType: .big) }()
    static var album: UIImage = { return UIImage.create("album") }()
    static var albumArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.album, iconSizeType: .big) }()
    static var albumCarplay: UIImage = { return UIImage.create("album_carplay") }()
    static var podcast: UIImage = { return UIImage.create("podcast") }()
    static var podcastArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.podcast, iconSizeType: .big) }()
    static var podcastCarplay: UIImage = { return UIImage.create("podcast_carplay") }()
    static var podcastEpisode: UIImage = { return UIImage.create("podcast") }()
    static var podcastEpisodeArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.podcastEpisode, iconSizeType: .small) }()
    static var playlist: UIImage = { return UIImage.create("playlist_svg") }()
    static var playlistArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.playlist, iconSizeType: .small, switchColors: true) }()
    static var playlistCarplay: UIImage = { return UIImage.create("playlist_carplay") }()
    static var playlistBlack: UIImage = { return UIImage.create("playlist") }()
    static var musicalNotes: UIImage = { return UIImage.create("musical_notes_svg") }()
    static var musicalNotesCarplay: UIImage = { return UIImage.create("musical_notes_carplay") }()
    
    static var userQueueInsert: UIImage = { return UIImage.create("user_queue_insert") }()
    static var userQueueAppend: UIImage = { return UIImage.create("user_queue_append") }()
    static var contextQueueInsert: UIImage = { return UIImage.create("context_queue_insert") }()
    static var contextQueueAppend: UIImage = { return UIImage.create("context_queue_append") }()
    static var download: UIImage = { return UIImage.create("download") }()
    static var trash: UIImage = { return UIImage.create("trash") }()
    static var play: UIImage = { return UIImage.create("play") }()
    static var pause: UIImage = { return UIImage.create("pause") }()
    static var shuffle: UIImage = { return UIImage.create("shuffle") }()
    
    private static func create(_ named: String) -> UIImage {
        return UIImage(named: named) ?? UIImage()
    }
    
    private static func createArtwork(with image: UIImage, iconSizeType: ArtworkIconSizeType, switchColors: Bool = false) -> UIImage {
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
