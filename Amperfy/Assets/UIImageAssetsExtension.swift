import Foundation
import UIKit

enum ArtworkIconSizeType: CGFloat {
    // rawValue will be used as insets
    case small = 25.0
    case big = 10.0
}

extension UIImage {
    
    static var amperfyMosaicArtwork: UIImage = { return UIImage(named: "song") ?? UIImage() }()
    static var appIcon: UIImage = { return UIImage(named: "Icon-1024") ?? UIImage() }()
    
    static var songArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.musicalNotes, iconSizeType: .small) }()
    static var genre: UIImage = { return UIImage(named: "genre") ?? UIImage() }()
    static var genreArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.genre, iconSizeType: .big) }()
    static var artist: UIImage = { return UIImage(named: "artist") ?? UIImage() }()
    static var artistArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.artist, iconSizeType: .big) }()
    static var album: UIImage = { return UIImage(named: "album") ?? UIImage() }()
    static var albumArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.album, iconSizeType: .big) }()
    static var podcast: UIImage = { return UIImage(named: "podcast") ?? UIImage() }()
    static var podcastArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.podcast, iconSizeType: .big) }()
    static var podcastCarplay: UIImage = { return UIImage(named: "podcast_carplay") ?? UIImage() }()
    static var podcastEpisode: UIImage = { return UIImage(named: "podcast") ?? UIImage() }()
    static var podcastEpisodeArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.podcastEpisode, iconSizeType: .small) }()
    static var playlist: UIImage = { return UIImage(named: "playlist_svg") ?? UIImage() }()
    static var playlistArtwork: UIImage = { return UIImage.createArtwork(with: UIImage.playlist, iconSizeType: .small, switchColors: true) }()
    static var playlistCarplay: UIImage = { return UIImage(named: "playlist_carplay") ?? UIImage() }()
    static var playlistBlack: UIImage = { return UIImage(named: "playlist") ?? UIImage() }()
    static var musicalNotes: UIImage = { return UIImage(named: "musical_notes_svg") ?? UIImage() }()
    static var musicalNotesCarplay: UIImage = { return UIImage(named: "musical_notes") ?? UIImage() }()
    
    static var userQueueInsert: UIImage = { return UIImage(named: "user_queue_insert") ?? UIImage() }()
    static var userQueueAppend: UIImage = { return UIImage(named: "user_queue_append") ?? UIImage() }()
    static var contextQueueInsert: UIImage = { return UIImage(named: "context_queue_insert") ?? UIImage() }()
    static var contextQueueAppend: UIImage = { return UIImage(named: "context_queue_append") ?? UIImage() }()
    static var download: UIImage = { return UIImage(named: "download") ?? UIImage() }()
    static var trash: UIImage = { return UIImage(named: "trash") ?? UIImage() }()
    static var play: UIImage = { return UIImage(named: "play") ?? UIImage() }()
    static var pause: UIImage = { return UIImage(named: "pause") ?? UIImage() }()
    static var shuffle: UIImage = { return UIImage(named: "shuffle") ?? UIImage() }()
    
    static func createArtwork(with image: UIImage, iconSizeType: ArtworkIconSizeType, switchColors: Bool = false) -> UIImage {
        let buildView = EntityImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let grade = 0.92
        let artworkBackgroundColor = UIColor(red: grade, green: grade, blue: grade, alpha: 1)
        let imageTintColor = !switchColors ? .defaultBlue : artworkBackgroundColor
        let backgroundColor = switchColors ? .defaultBlue : artworkBackgroundColor
        buildView.configureStyling(image: image, imageSizeType: iconSizeType, imageTintColor: imageTintColor, backgroundColor: backgroundColor)
        buildView.layoutIfNeeded()
        return buildView.screenshot ?? UIImage()
    }
    
}
