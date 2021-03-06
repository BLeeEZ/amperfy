import UIKit

class PlaylistTableCell: BasicTableCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var art1Image: UIImageView!
    @IBOutlet weak var art2Image: UIImageView!
    @IBOutlet weak var art3Image: UIImageView!
    @IBOutlet weak var art4Image: UIImageView!
    
    static let rowHeight: CGFloat = 80.0 + margin.bottom + margin.top
    
    func display(playlist: Playlist) {
        nameLabel.text = playlist.name
        var images = [UIImageView]()
        images.append(art1Image)
        images.append(art2Image)
        images.append(art3Image)
        images.append(art4Image)
        
        for artImage in images {
            artImage.image = Artwork.defaultImage
        }
        
        let customArtworkSongs = playlist.songs.filterCustomArt()
        for (index, artImage) in images.enumerated() {
            guard customArtworkSongs.count > index else { break }
            artImage.image = customArtworkSongs[index].image
        }
    }
    
}
