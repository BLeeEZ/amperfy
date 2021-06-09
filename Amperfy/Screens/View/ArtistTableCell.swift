import UIKit

class ArtistTableCell: BasicTableCell {
    
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    private var artist: Artist!
    
    func display(artist: Artist) {
        self.artist = artist
        artistLabel.text = artist.name
        if let artwork = artist.artwork {
            appDelegate.artworkDownloadManager.download(object: artwork, notifier: self)
        }
        artworkImage.image = artist.image
        var infoText = ""
        if artist.albumCount == 1 {
            infoText += "1 Album"
        } else {
            infoText += "\(artist.albumCount) Albums"
        }
        infoLabel.text = infoText
    }

}

extension ArtistTableCell: DownloadNotifiable {
    func finished(downloading: Downloadable, error: DownloadError?) {
        if error == nil {
            artworkImage.image = self.artist.image
        }
    }
}
