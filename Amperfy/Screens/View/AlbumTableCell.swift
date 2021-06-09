import UIKit

class AlbumTableCell: BasicTableCell {
    
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    private var album: Album!
    
    func display(album: Album) {
        self.album = album
        albumLabel.text = album.name
        artistLabel.text = album.artist?.name
        if let artwork = album.artwork {
            appDelegate.artworkDownloadManager.download(object: artwork, notifier: self)
        }
        artworkImage.image = album.image
        var infoText = ""
        if album.songCount == 1 {
            infoText += "1 Song"
        } else {
            infoText += "\(album.songCount) Songs"
        }
        infoLabel.text = infoText
    }

}

extension AlbumTableCell: DownloadNotifiable {
    func finished(downloading: Downloadable, error: DownloadError?) {
        if error == nil {
            artworkImage.image = album.image
        }
    }
}
