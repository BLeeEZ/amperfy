import UIKit

class AlbumTableCell: BasicTableCell {
    
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    private var album: Album!
    
    func display(album: Album) {
        self.album = album
        albumLabel.text = album.name
        artistLabel.text = album.artist?.name
        artworkImage.displayAndUpdate(entity: album, via: appDelegate.artworkDownloadManager)
        var infoText = ""
        if album.songCount == 1 {
            infoText += "1 Song"
        } else {
            infoText += "\(album.songCount) Songs"
        }
        infoLabel.text = infoText
    }

}
