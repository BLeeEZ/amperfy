import UIKit

class ArtistTableCell: BasicTableCell {
    
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    private var artist: Artist!
    
    func display(artist: Artist) {
        self.artist = artist
        artistLabel.text = artist.name
        artworkImage.displayAndUpdate(entity: artist, via: appDelegate.artworkDownloadManager)
        var infoText = ""
        if artist.albumCount == 1 {
            infoText += "1 Album"
        } else {
            infoText += "\(artist.albumCount) Albums"
        }
        if artist.songCount == 1 {
            infoText += " \(CommonString.oneMiddleDot) 1 Song"
        } else if artist.songCount > 1 {
            infoText += " \(CommonString.oneMiddleDot) \(artist.songCount) Songs"
        }
        infoLabel.text = infoText
    }

}
